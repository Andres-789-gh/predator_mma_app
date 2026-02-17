import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';

abstract class ClientNotificationState extends Equatable {
  const ClientNotificationState();
  @override
  List<Object?> get props => [];
}

class ClientNotificationInitial extends ClientNotificationState {}

class ClientNotificationLoading extends ClientNotificationState {}

class ClientNotificationLoaded extends ClientNotificationState {
  final List<NotificationModel> notifications;
  int get unreadCount => notifications.where((n) => !n.isRead).length;

  const ClientNotificationLoaded(this.notifications);
  @override
  List<Object?> get props => [notifications];
}

class ClientNotificationError extends ClientNotificationState {
  final String message;
  const ClientNotificationError(this.message);
  @override
  List<Object?> get props => [message];
}

class ClientNotificationCubit extends Cubit<ClientNotificationState> {
  final NotificationRepository _repository;
  final String _userId;
  StreamSubscription? _subscription;

  ClientNotificationCubit({
    required NotificationRepository repository,
    required String userId,
  }) : _repository = repository,
       _userId = userId,
       super(ClientNotificationInitial()) {
    _subscribe();
  }

  void _subscribe() {
    emit(ClientNotificationLoading());
    _subscription = _repository
        .getNotificationsStream('client', userId: _userId)
        .listen((notifications) {
          final visibleNotifications = notifications
              .where((n) => !n.hiddenFor.contains(_userId))
              .toList();
          emit(ClientNotificationLoaded(visibleNotifications));
        }, onError: (e) => emit(ClientNotificationError(e.toString())));
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _repository.markAsRead(notificationId);
    } catch (_) {}
  }

  Future<void> markAllAsRead(List<NotificationModel> notifications) async {
    final unreadIds = notifications
        .where((n) => !n.isRead)
        .map((n) => n.id)
        .toList();

    if (unreadIds.isEmpty) return;

    try {
      await _repository.markBatchAsRead(unreadIds);
    } catch (_) {}
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _repository.hideNotification(notificationId, _userId);
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
