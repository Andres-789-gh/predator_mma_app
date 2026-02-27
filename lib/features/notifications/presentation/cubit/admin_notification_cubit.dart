import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/constants/enums.dart';
import '../../domain/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';
import '../../domain/usecases/resolve_plan_request_usecase.dart';

abstract class AdminNotificationState extends Equatable {
  const AdminNotificationState();
  @override
  List<Object?> get props => [];
}

class AdminNotificationInitial extends AdminNotificationState {}

class AdminNotificationLoading extends AdminNotificationState {}

class AdminNotificationLoaded extends AdminNotificationState {
  final List<NotificationModel> notifications;
  int get pendingCount => notifications
      .where((n) => !n.isRead && n.status == NotificationStatus.pending)
      .length;

  const AdminNotificationLoaded(this.notifications);

  @override
  List<Object?> get props => [notifications];
}

class AdminNotificationError extends AdminNotificationState {
  final String message;
  const AdminNotificationError(this.message);
  @override
  List<Object?> get props => [message];
}

class AdminNotificationCubit extends Cubit<AdminNotificationState> {
  final NotificationRepository _notificationRepository;
  final ResolvePlanRequestUseCase _resolveUseCase;
  StreamSubscription? _subscription;

  AdminNotificationCubit({
    required NotificationRepository notificationRepository,
    required ResolvePlanRequestUseCase resolveUseCase,
  }) : _notificationRepository = notificationRepository,
       _resolveUseCase = resolveUseCase,
       super(AdminNotificationInitial()) {
    _subscribeToNotifications();
  }

  // escucha flujo bd
  void _subscribeToNotifications() {
    emit(AdminNotificationLoading());
    _subscription = _notificationRepository
        .getNotificationsStream('admin')
        .listen(
          (notifications) {
            if (isClosed) return;
            emit(AdminNotificationLoaded(notifications));
          },
          onError: (e) {
            if (isClosed) return;
            emit(AdminNotificationError("error cargando notificaciones: $e"));
          },
        );
  }

  // registra lectura visual
  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationRepository.markAsRead(notificationId);
    } catch (_) {}
  }

  // aprueba solicitud
  Future<void> approveRequest({
    required NotificationModel notification,
    required double finalPrice,
    required DateTime startDate,
    required DateTime endDate,
    required String paymentMethod,
    String? note,
  }) async {
    try {
      await _resolveUseCase.executeApprove(
        notification: notification,
        finalPrice: finalPrice,
        startDate: startDate,
        endDate: endDate,
        paymentMethod: paymentMethod,
        adminNote: note,
      );
    } catch (e) {
      if (isClosed) return;
      emit(AdminNotificationError(e.toString()));
      _subscribeToNotifications();
    }
  }

  // rechaza solicitud
  Future<void> rejectRequest(
    NotificationModel notification,
    String reason,
  ) async {
    try {
      await _resolveUseCase.executeReject(
        notification: notification,
        reason: reason,
      );
      if (isClosed) return;
      _subscribeToNotifications();
    } catch (e) {
      if (isClosed) return;
      emit(AdminNotificationError("error al rechazar: $e"));
    }
  }

  // archiva registro
  Future<void> archiveNotification(String notificationId) async {
    try {
      await _resolveUseCase.executeArchive(notificationId);
    } catch (e) {
      if (isClosed) return;
      emit(AdminNotificationError("error al borrar: $e"));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
