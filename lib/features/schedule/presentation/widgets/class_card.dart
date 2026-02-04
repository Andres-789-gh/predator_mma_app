import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/enums.dart';
import '../../domain/models/class_model.dart';
import '../../domain/class_logic.dart';

class ClassCard extends StatelessWidget {
  final ClassModel classModel;
  final ClassStatus status;
  final bool isLoading;
  final VoidCallback? onActionPressed;

  const ClassCard({
    super.key,
    required this.classModel,
    required this.status,
    required this.isLoading,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isExpired = classModel.hasFinished;

    // verifica permiso
    bool isButtonEnabled = true;

    // color y texto
    Color statusColor;
    String buttonText;
    IconData statusIcon;
    bool isDestructive = false;

    // determina estado visual
    if (classModel.isCancelled) {
      statusColor = Colors.red;
      buttonText = 'CANCELADA';
      statusIcon = Icons.cancel_outlined;
      isButtonEnabled = false;

      if (isExpired) {
        statusColor = Colors.grey;
        buttonText = 'CANCELADA (FIN)';
      }
    } else if (isExpired) {
      statusColor = isDark ? Colors.grey[700]! : Colors.grey;
      buttonText = 'FINALIZADA';
      statusIcon = Icons.history;
      isButtonEnabled = false;
    } else {
      switch (status) {
        case ClassStatus.available:
        case ClassStatus.availableWithTicket:
          // logica para reservar
          if (!classModel.canReserveNow) {
            statusColor = Colors.grey;
            buttonText = 'RESERVA CERRADA';
            statusIcon = Icons.timer_off;
            isButtonEnabled = false;
          } else {
            // estado disponible
            statusColor = status == ClassStatus.availableWithTicket
                ? Colors.amber
                : const Color(0xFF4CAF50);
            buttonText = status == ClassStatus.availableWithTicket
                ? 'USAR INGRESO EXTRA'
                : 'RESERVAR';
            statusIcon = status == ClassStatus.availableWithTicket
                ? Icons.confirmation_number_outlined
                : Icons.add_circle_outline;
          }
          break;

        case ClassStatus.reserved:
          // logica para cancelar
          if (!classModel.canCancelNow) {
            statusColor = const Color(0xFF2196F3);
            buttonText = 'NO CANCELABLE';
            statusIcon = Icons.lock_clock;
            isButtonEnabled = false;
          } else {
            // estado cancelable
            statusColor = const Color(0xFF2196F3);
            buttonText = 'CANCELAR RESERVA';
            statusIcon = Icons.check_circle;
            isDestructive = true;
          }
          break;

        case ClassStatus.waitlist:
          statusColor = Colors.orange;
          buttonText = 'SALIR DE LISTA';
          statusIcon = Icons.hourglass_empty;
          isDestructive = true;
          break;

        case ClassStatus.full:
          statusColor = Colors.grey;
          buttonText = 'CLASE LLENA';
          statusIcon = Icons.block;
          isButtonEnabled = false;
          break;

        case ClassStatus.blockedByPlan:
          statusColor = Colors.red.withValues(alpha: 0.5);
          buttonText = 'NO DISPONIBLE';
          statusIcon = Icons.lock;
          isButtonEnabled = false;
          break;
      }
    }

    final timeFormat = DateFormat('h:mm a');
    final startTime = timeFormat.format(classModel.startTime);
    final endTime = timeFormat.format(classModel.endTime);
    final textDecoration = classModel.isCancelled
        ? TextDecoration.lineThrough
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: status == ClassStatus.reserved
            ? Border.all(color: statusColor.withValues(alpha: 0.5), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Column(
                  children: [
                    Text(
                      startTime,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                        decoration: textDecoration,
                      ),
                    ),
                    Text(
                      endTime,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey : Colors.grey[600],
                        decoration: textDecoration,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Container(
                  height: 40,
                  width: 2,
                  color: statusColor.withValues(alpha: 0.3),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classModel.classType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          color: isDark ? Colors.white : Colors.black87,
                          decoration: textDecoration,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 14,
                            color: isDark ? Colors.grey : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            classModel.coachName,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isDark
                                    ? Colors.white24
                                    : Colors.grey[300]!,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'MÁX. ${classModel.maxCapacity}',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.grey : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          if (status == ClassStatus.full) ...[
                            const SizedBox(width: 8),
                            const Text(
                              'SIN CUPOS',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
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

          // btn de accion inteligente
          GestureDetector(
            onTap: (isLoading || !isButtonEnabled) ? null : onActionPressed,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: !isButtonEnabled
                    ? (isDark ? Colors.white10 : Colors.grey[200])
                    : (isDestructive
                          ? Colors.red.withValues(alpha: 0.1)
                          : statusColor.withValues(alpha: 0.1)),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Center(
                child: isLoading
                    ? SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: statusColor,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            statusIcon,
                            size: 16,
                            color: !isButtonEnabled
                                ? Colors.grey
                                : (isDestructive ? Colors.red : statusColor),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            buttonText,
                            style: TextStyle(
                              color: !isButtonEnabled
                                  ? Colors.grey
                                  : (isDestructive ? Colors.red : statusColor),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
