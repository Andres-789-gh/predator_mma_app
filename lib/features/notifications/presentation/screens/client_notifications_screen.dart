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
      body: BlocBuilder<ClientNotificationCubit, ClientNotificationState>(
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

    if (!notification.isRead) {}

    Color bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    if (!notification.isRead) {
      bgColor = isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue[50]!;
    }

    return GestureDetector(
      onTap: () => cubit.markAsRead(notification.id),
      child: Card(
        color: bgColor,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                    if (notification.payload['resolution_note'] != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Nota Admin: ${notification.payload['resolution_note']}",
                          style: const TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('dd/MM HH:mm').format(notification.createdAt),
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              if (!notification.isRead)
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
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
