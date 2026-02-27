import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/enums.dart';
import '../../domain/models/notification_model.dart';
import '../cubit/admin_notification_cubit.dart';
import '../widgets/approve_plan_dialog.dart';
import '../widgets/reject_plan_dialog.dart';

class AdminNotificationsScreen extends StatelessWidget {
  const AdminNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: BlocBuilder<AdminNotificationCubit, AdminNotificationState>(
        builder: (context, state) {
          if (state is AdminNotificationLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is AdminNotificationError) {
            return Center(child: Text(state.message));
          }
          if (state is AdminNotificationLoaded) {
            final list = state.notifications
                .where((n) => n.status != NotificationStatus.archived)
                .toList();

            if (list.isEmpty) {
              return const Center(child: Text('No tienes notificaciones'));
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isPending = notification.status == NotificationStatus.pending;

    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final pendingColor = isDark
        ? Colors.blue.withValues(alpha: 0.1)
        : Colors.blue.shade50;

    final dateStr = DateFormat('dd/MM HH:mm').format(notification.createdAt);

    return Card(
      elevation: 2,
      color: notification.isRead ? cardColor : pendingColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(
                    _getLabel(notification.type),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  backgroundColor: _getChipColor(notification.type, theme),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                Row(
                  children: [
                    Text(
                      dateStr,
                      style: TextStyle(fontSize: 12, color: theme.hintColor),
                    ),
                    if (!isPending)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.grey,
                        ),
                        tooltip: "Eliminar del historial",
                        onPressed: () => _confirmDelete(context),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              notification.title.isNotEmpty
                  ? notification.title
                  : 'De: ${notification.fromUserName}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            _buildDetailText(context),
            const SizedBox(height: 12),

            if (isPending && notification.type == NotificationType.planRequest)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _showRejectDialog(context),
                    child: const Text(
                      'Rechazar',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _showApproveDialog(context),
                    child: const Text('Revisar'),
                  ),
                ],
              )
            else if (notification.type == NotificationType.planRequest)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _translateStatus(notification.status),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(notification.status),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailText(BuildContext context) {
    if (notification.type == NotificationType.planRequest) {
      final payload = notification.payload;
      final planName = payload['plan_name'] ?? 'Desconocido';
      final price = (payload['plan_price'] as num?)?.toDouble() ?? 0.0;

      final currency = NumberFormat.currency(
        locale: 'es_CO',
        symbol: '\$',
        decimalDigits: 0,
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Solicita: $planName"),
          Text(
            "Valor: ${currency.format(price)}",
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    return Text(
      notification.body.isNotEmpty
          ? notification.body
          : 'Sin detalles adicionales',
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }

  String _getLabel(NotificationType type) {
    switch (type) {
      case NotificationType.planRequest:
        return 'SOLICITUD';
      case NotificationType.paymentDue:
        return 'PAGO VENCIDO';
      case NotificationType.systemInfo:
        return 'SISTEMA';
      case NotificationType.planExpiring:
        return 'VENCIMIENTO';
      case NotificationType.classClosed:
        return 'CLASE CERRADA';
    }
  }

  Color _getChipColor(NotificationType type, ThemeData theme) {
    switch (type) {
      case NotificationType.planExpiring:
        return Colors.orange.withValues(alpha: 0.3);
      case NotificationType.classClosed:
        return Colors.green.withValues(alpha: 0.3);
      default:
        return theme.highlightColor;
    }
  }

  String _translateStatus(NotificationStatus status) {
    switch (status) {
      case NotificationStatus.pending:
        return 'PENDIENTE';
      case NotificationStatus.approved:
        return 'APROBADO';
      case NotificationStatus.rejected:
        return 'RECHAZADO';
      case NotificationStatus.archived:
        return 'ELIMINADO';
    }
  }

  Color _getStatusColor(NotificationStatus status) {
    switch (status) {
      case NotificationStatus.approved:
        return Colors.green;
      case NotificationStatus.rejected:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // aprobacion
  void _showApproveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => ApprovePlanDialog(
        notification: notification,
        onApprove: (price, start, end, paymentMethod, note) {
          context.read<AdminNotificationCubit>().approveRequest(
            notification: notification,
            finalPrice: price,
            startDate: start,
            endDate: end,
            paymentMethod: paymentMethod,
            note: note,
          );
        },
      ),
    );
  }

  // rechazo
  void _showRejectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => RejectPlanDialog(
        notification: notification,
        onReject: (reason) {
          context.read<AdminNotificationCubit>().rejectRequest(
            notification,
            reason,
          );
        },
      ),
    );
  }

  // borrado
  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Borrar notificación?"),
        content: const Text("Desaparecerá de la bandeja de notificaciones."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () {
              context.read<AdminNotificationCubit>().archiveNotification(
                notification.id,
              );
              Navigator.pop(ctx);
            },
            child: const Text("Borrar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
