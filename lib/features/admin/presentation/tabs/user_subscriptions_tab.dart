import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../auth/domain/models/user_model.dart';

class UserSubscriptionsTab extends StatelessWidget {
  final UserPlan? activePlan;
  final VoidCallback onAssignNewPlan;
  final VoidCallback onResumePlan;
  final VoidCallback onPausePlan;
  final VoidCallback onCancelPlan;

  const UserSubscriptionsTab({
    super.key,
    required this.activePlan,
    required this.onAssignNewPlan,
    required this.onResumePlan,
    required this.onPausePlan,
    required this.onCancelPlan,
  });

  @override
  Widget build(BuildContext context) {
    final hasPlanObject = activePlan != null;

    bool isPausedNow = false;
    bool isExpired = false;

    if (hasPlanObject) {
      final now = DateTime.now();

      if (now.isAfter(activePlan!.effectiveEndDate)) {
        isExpired = true;
      } else {
        isPausedNow = activePlan!.pauses.any(
          (p) =>
              now.isAfter(p.startDate.subtract(const Duration(seconds: 1))) &&
              now.isBefore(p.endDate.add(const Duration(seconds: 1))),
        );
      }
    }

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isExpired) {
      statusColor = Colors.red;
      statusText = "VENCIDO";
      statusIcon = Icons.warning_amber_rounded;
    } else if (isPausedNow) {
      statusColor = Colors.orange;
      statusText = "PAUSADO";
      statusIcon = Icons.pause_circle;
    } else {
      statusColor = Colors.green;
      statusText = "ACTIVO";
      statusIcon = Icons.check_circle;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sin plan
          if (!hasPlanObject)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.add_circle_outline,
                    size: 40,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 10),
                  const Text("No tiene plan asignado"),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: onAssignNewPlan,
                    child: const Text("Asignar Nuevo Plan"),
                  ),
                ],
              ),
            )
          // Con plan
          else ...[
            const Text(
              "Suscripción",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              color: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header de la tarjeta
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            activePlan!.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isExpired ? Colors.grey : null,
                              decoration: isExpired
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(statusIcon, size: 14, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 25),

                    // Fechas
                    _infoRow(
                      Icons.calendar_today,
                      "Inicio:",
                      DateFormat('dd/MM/yyyy').format(activePlan!.startDate),
                    ),
                    _infoRow(
                      Icons.event_busy,
                      isExpired ? "Venció:" : "Vence:",
                      DateFormat(
                        'dd/MM/yyyy',
                      ).format(activePlan!.effectiveEndDate),
                    ),

                    // Historial de pausas
                    if (!isExpired && activePlan!.pauses.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.history,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 5),
                            Text(
                              "${activePlan!.pauses.length} pausa(s) en historial",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Acciones
                    if (isExpired)
                      // Btn si está vencido
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.autorenew),
                          label: const Text("RENOVAR / ASIGNAR NUEVO"),
                          onPressed: onAssignNewPlan,
                        ),
                      )
                    else
                      // Btns: Activo/Pausado y Cancelar
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: Icon(
                                isPausedNow ? Icons.play_arrow : Icons.pause,
                                color: isPausedNow ? Colors.green : null,
                              ),
                              label: Text(
                                isPausedNow ? "Reanudar" : "Pausar",
                                style: TextStyle(
                                  color: isPausedNow ? Colors.green : null,
                                ),
                              ),
                              onPressed: isPausedNow
                                  ? onResumePlan
                                  : onPausePlan,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                Icons.delete_forever,
                                color: Colors.red,
                              ),
                              label: const Text(
                                "Cancelar",
                                style: TextStyle(color: Colors.red),
                              ),
                              onPressed: onCancelPlan,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Helper privado
  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text("$label ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}
