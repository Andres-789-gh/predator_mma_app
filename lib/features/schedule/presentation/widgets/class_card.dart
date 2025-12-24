import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/enums.dart';
import '../../domain/models/class_model.dart';

class ClassCard extends StatelessWidget {
  final ClassModel classModel;
  final ClassStatus status;
  final bool isLoading;
  final VoidCallback? onActionPressed;

  const ClassCard({
    super.key,
    required this.classModel,
    required this.status,
    this.isLoading = false,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: config.color.withValues(alpha: 0.5), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${DateFormat('h:mm a').format(classModel.startTime)} - ${classModel.classType}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                _buildStatusBadge(config),
              ],
            ),
            const SizedBox(height: 8),
            
            // Info
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(classModel.coachName),
                const Spacer(),
                const Icon(Icons.group, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('${classModel.attendees.length} / ${classModel.maxCapacity}'),
              ],
            ),
            const SizedBox(height: 12),

            // Btn accion
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: config.color,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                ),
                onPressed: isLoading ? null : onActionPressed,
                child: isLoading
                    ? const SizedBox(
                        height: 20, width: 20, 
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                      )
                    : Text(config.buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Configuración de colores
  _StatusConfig _getStatusConfig(BuildContext context) {
    switch (status) {
      case ClassStatus.reserved:
        return _StatusConfig(Colors.green, 'Cancelar Reserva', Icons.check_circle);
      case ClassStatus.available:
        return _StatusConfig(Colors.blue, 'Reservar Clase', Icons.event_available);
      case ClassStatus.availableWithTicket:
        return _StatusConfig(Colors.amber[800]!, 'Usar Ticket Extra', Icons.local_activity);
      case ClassStatus.full:
        return _StatusConfig(Colors.orange, 'Unirse a Lista de Espera', Icons.hourglass_empty);
      case ClassStatus.blockedByPlan:
        return _StatusConfig(Colors.grey, 'No Disponible', Icons.lock);
    }
  }

  // Construcción del Badge pequeño
  Widget _buildStatusBadge(_StatusConfig config) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 14, color: config.color),
          if (status == ClassStatus.availableWithTicket) ...[
            const SizedBox(width: 4),
            Text(
              'Ticket', 
              style: TextStyle(color: config.color, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ]
        ],
      ),
    );
  }
}

// Clase auxiliar para pasar configuración
class _StatusConfig {
  final Color color;
  final String buttonText;
  final IconData icon;

  _StatusConfig(this.color, this.buttonText, this.icon);
}