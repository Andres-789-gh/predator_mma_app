import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/constants/enums.dart';
import '../../domain/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';
import '../../domain/usecases/resolve_plan_request_usecase.dart';

// --- ESTADOS ---
abstract class AdminNotificationState extends Equatable {
  const AdminNotificationState();
  @override
  List<Object?> get props => [];
}

class AdminNotificationInitial extends AdminNotificationState {}

class AdminNotificationLoading extends AdminNotificationState {}

class AdminNotificationLoaded extends AdminNotificationState {
  final List<NotificationModel> notifications;
  // Getter util para saber si hay pendientes (para el puntito rojo del UI)
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

// --- CUBIT ---
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

  void _subscribeToNotifications() {
    emit(AdminNotificationLoading());
    // Escucha en tiempo real solo las del Admin
    _subscription = _notificationRepository
        .getNotificationsStream('admin')
        .listen(
          (notifications) {
            emit(AdminNotificationLoaded(notifications));
          },
          onError: (e) {
            emit(AdminNotificationError("Error cargando notificaciones: $e"));
          },
        );
  }

  // Cuando el admin abre la bandeja
  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationRepository.markAsRead(notificationId);
    } catch (_) {
      // Silencioso, no bloqueamos al usuario por esto
    }
  }

  // ACCION PRINCIPAL: Aprobar Solicitud
  Future<void> approveRequest(NotificationModel notification) async {
    try {
      // Nota: No emitimos Loading global para no redibujar toda la lista,
      // idealmente se maneja un estado local o un toast de "Procesando..."
      await _resolveUseCase.executeApprove(notification);
      // El stream actualizará la lista automáticamente a "Approved"
    } catch (e) {
      emit(AdminNotificationError(e.toString()));
      // Re-suscribirse si el error rompió el estado (opcional)
      _subscribeToNotifications();
    }
  }

  Future<void> rejectRequest(String notificationId) async {
    try {
      await _resolveUseCase.executeReject(notificationId);
    } catch (e) {
      emit(AdminNotificationError("Error al rechazar: $e"));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
