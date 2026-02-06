import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../../core/constants/enums.dart';

class UserSubscriptionsTab extends StatelessWidget {
  final List<UserPlan> activePlans;
  final VoidCallback onAssignNewPlan;
  final Function(UserPlan) onResumePlan;
  final Function(UserPlan) onPausePlan;
  final Function(UserPlan) onCancelPlan;

  const UserSubscriptionsTab({
    super.key,
    required this.activePlans,
    required this.onAssignNewPlan,
    required this.onResumePlan,
    required this.onPausePlan,
    required this.onCancelPlan,
  });

  @override
  Widget build(BuildContext context) {
    if (activePlans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.sentiment_dissatisfied,
              size: 60,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              "El usuario no tiene planes activos.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAssignNewPlan,
              icon: const Icon(Icons.add),
              label: const Text("Asignar Plan"),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...activePlans.map(
          (plan) => _PlanCard(
            plan: plan,
            onResume: () => onResumePlan(plan),
            onPause: () => onPausePlan(plan),
            onCancel: () => onCancelPlan(plan),
          ),
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onAssignNewPlan,
            icon: const Icon(Icons.add),
            label: const Text("AGREGAR OTRO PLAN"),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: Theme.of(context).primaryColor),
            ),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final UserPlan plan;
  final VoidCallback onResume;
  final VoidCallback onPause;
  final VoidCallback onCancel;

  const _PlanCard({
    required this.plan,
    required this.onResume,
    required this.onPause,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final bool isPaused = plan.isPaused(now);
    final bool isExpired = plan.endDate.isBefore(now);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isExpired) {
      statusColor = Colors.red;
      statusText = "VENCIDO";
      statusIcon = Icons.cancel;
    } else if (isPaused) {
      statusColor = Colors.orange;
      statusText = "PAUSADO";
      statusIcon = Icons.pause_circle;
    } else {
      statusColor = Colors.green;
      statusText = "ACTIVO";
      statusIcon = Icons.check_circle;
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // cabecera de la tarjeta
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                if (plan.consumptionType == PlanConsumptionType.limitedDaily)
                  Chip(
                    label: Text("Límite: ${plan.dailyLimit}/día"),
                    backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                    labelStyle: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )
                else
                  Chip(
                    label: const Text("Ilimitado"),
                    backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                    labelStyle: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // nombre del plan
                Text(
                  plan.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),

                // fechas
                _buildInfoRow(
                  Icons.calendar_today,
                  "Inicio:",
                  DateFormat('dd/MM/yyyy').format(plan.startDate),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.event_busy,
                  "Vence:",
                  DateFormat('dd/MM/yyyy').format(plan.effectiveEndDate),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.attach_money,
                  "Precio:",
                  "\$${NumberFormat('#,###').format(plan.price)}",
                ),

                if (plan.pauses.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    "Historial de Pausas:",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  ...plan.pauses.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(top: 4, left: 8),
                      child: Text(
                        "- ${DateFormat('dd/MM').format(p.startDate)} al ${DateFormat('dd/MM').format(p.endDate)} (${p.createdBy})",
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!isExpired)
                      if (isPaused)
                        FilledButton.icon(
                          onPressed: onResume,
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text("Reanudar"),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: onPause,
                          icon: const Icon(Icons.pause, size: 18),
                          label: const Text("Pausar"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange[800],
                            side: BorderSide(color: Colors.orange[800]!),
                          ),
                        ),

                    const SizedBox(width: 10),

                    if (!isExpired)
                      TextButton(
                        onPressed: onCancel,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text("Cancelar"),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
