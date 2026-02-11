import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/enums.dart';
import '../../domain/models/notification_model.dart';
import '../cubit/admin_notification_cubit.dart';

class AdminNotificationsScreen extends StatelessWidget {
  const AdminNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // obtiene notificaciones al iniciar
    return Scaffold(
      appBar: AppBar(title: const Text('centro de notificaciones')),
      body: BlocBuilder<AdminNotificationCubit, AdminNotificationState>(
        builder: (context, state) {
          if (state is AdminNotificationLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is AdminNotificationError) {
            return Center(child: Text(state.message));
          }
          if (state is AdminNotificationLoaded) {
            final list = state.notifications;
            if (list.isEmpty) {
              return const Center(
                child: Text('no hay notificaciones pendientes'),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _NotificationCard(notification: list[i]),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;

  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    final isPending = notification.status == NotificationStatus.pending;
    final dateStr = DateFormat('dd/MM HH:mm').format(notification.createdAt);

    return Card(
      elevation: 2,
      color: notification.isRead ? Colors.white : Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // tipo notificacion
                Chip(
                  label: Text(
                    _getLabel(notification.type),
                    style: const TextStyle(fontSize: 10),
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                Text(
                  dateStr,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // titulo y descripcion
            Text(
              'de: ${notification.fromUserName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(_getDescription(notification)),
            const SizedBox(height: 12),
            // btn si esta pendiente
            if (isPending)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _reject(context),
                    child: const Text(
                      'rechazar',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _approve(context),
                    child: const Text('aprobar'),
                  ),
                ],
              )
            else
              // estado final
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  notification.status.toString().split('.').last.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getLabel(NotificationType type) {
    switch (type) {
      case NotificationType.planRequest:
        return 'solicitud plan';
      case NotificationType.paymentDue:
        return 'pago vencido';
      case NotificationType.systemInfo:
        return 'sistema';
    }
  }

  String _getDescription(NotificationModel n) {
    if (n.type == NotificationType.planRequest) {
      final planName = n.payload['plan_name'] ?? 'plan desconocido';
      final price = n.payload['plan_price'] ?? 0;
      return 'solicita activar: $planName (\$$price)';
    }
    return 'sin detalles adicionales';
  }

  void _approve(BuildContext context) {
    context.read<AdminNotificationCubit>().approveRequest(notification);
  }

  void _reject(BuildContext context) {
    context.read<AdminNotificationCubit>().rejectRequest(notification.id);
  }
}
