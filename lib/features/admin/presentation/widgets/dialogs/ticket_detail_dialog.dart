import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../auth/domain/models/access_exception_model.dart';

class TicketDetailDialog extends StatelessWidget {
  final AccessExceptionModel ticket;

  const TicketDetailDialog({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Row(
        children: [
          Icon(Icons.receipt_long, color: Colors.blueGrey),
          SizedBox(width: 10),
          Text("Detalle del Ticket"),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(
            "Plan Base:",
            ticket.originalPlanName.isEmpty
                ? "Ingreso Extra"
                : ticket.originalPlanName,
          ),
          _buildDetailRow("Cantidad:", "${ticket.quantity}"),
          _buildDetailRow("Motivo:", ticket.reason ?? "Sin motivo registrado"),
          _buildDetailRow(
            "Vencimiento:",
            ticket.validUntil != null
                ? DateFormat('dd/MM/yyyy').format(ticket.validUntil!)
                : "Sin vencimiento (Indefinido)",
          ),

          const Divider(height: 20),
          _buildDetailRow("Otorgado por:", ticket.grantedBy),
          _buildDetailRow(
            "Fecha:",
            DateFormat('dd/MM/yyyy HH:mm').format(ticket.grantedAt),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cerrar"),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}
