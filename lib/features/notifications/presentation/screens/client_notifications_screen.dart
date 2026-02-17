import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../cubit/client_notification_cubit.dart';
import '../../domain/models/notification_model.dart';
import '../../../../core/constants/enums.dart';

class ClientNotificationsScreen extends StatelessWidget {
  const ClientNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mis Notificaciones")),
      body: BlocListener<ClientNotificationCubit, ClientNotificationState>(
        listener: (context, state) {
          if (state is ClientNotificationLoaded && state.unreadCount > 0) {
            context.read<ClientNotificationCubit>().markAllAsRead(
              state.notifications,
            );
          }
        },
        child: BlocBuilder<ClientNotificationCubit, ClientNotificationState>(
          builder: (context, state) {
            if (state is ClientNotificationLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is ClientNotificationLoaded) {
              final list = state.notifications;
              if (list.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 60,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 10),
                      Text("No tienes notificaciones nuevas"),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(15),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) =>
                    _ClientNotificationCard(notification: list[i]),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _ClientNotificationCard extends StatelessWidget {
  final NotificationModel notification;

  const _ClientNotificationCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cubit = context.read<ClientNotificationCubit>();

    Color bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    if (!notification.isRead) {
      bgColor = isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue[50]!;
    }

    return Card(
      color: bgColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => cubit.markAsRead(notification.id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 40, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIcon(notification.type),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getTitle(notification.type),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _getMessage(notification),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        _buildAdminNote(context),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              DateFormat(
                                'dd/MM HH:mm',
                              ).format(notification.createdAt),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                            ),
                            if (!notification.isRead) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: Colors.grey[400],
              ),
              tooltip: 'Eliminar notificación',
              onPressed: () => _showDeleteConfirmation(context, cubit),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    ClientNotificationCubit cubit,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("¿Eliminar notificación?"),
        content: const Text(
          "Esta acción ocultará la notificación de tu lista permanentemente.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              cubit.deleteNotification(notification.id);
            },
            child: const Text(
              "Eliminar",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminNote(BuildContext context) {
    final note = notification.payload['resolution_note'];

    if (note == null ||
        note is! String ||
        note.trim().isEmpty ||
        note == 'null') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Observación adjunta:",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              note,
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(NotificationType type) {
    IconData icon;
    Color color;

    switch (type) {
      case NotificationType.planRequest:
        icon = Icons.assignment_turned_in;
        color = Colors.green;
        break;
      case NotificationType.paymentDue:
        icon = Icons.warning_amber;
        color = Colors.orange;
        break;
      case NotificationType.systemInfo:
        icon = Icons.info_outline;
        color = Colors.blue;
        break;
    }

    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.1),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _getTitle(NotificationType type) {
    return "Actualización";
  }

  String _getMessage(NotificationModel n) {
    final status = n.status;
    final planName = n.payload['plan_name'] ?? 'Plan';

    if (status == NotificationStatus.approved) {
      return "¡Tu solicitud para '$planName' ha sido APROBADA! Ya puedes reservar.";
    } else if (status == NotificationStatus.rejected) {
      return "Tu solicitud para '$planName' fue rechazada.";
    } else if (status == NotificationStatus.pending) {
      return "Tu solicitud para '$planName' está en revisión.";
    }

    return "Tienes una nueva notificación del sistema.";
  }
}
