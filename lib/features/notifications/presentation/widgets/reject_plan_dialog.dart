import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/models/notification_model.dart';

class RejectPlanDialog extends StatefulWidget {
  final NotificationModel notification;
  final Function(String reason) onReject;

  const RejectPlanDialog({
    super.key,
    required this.notification,
    required this.onReject,
  });

  @override
  State<RejectPlanDialog> createState() => _RejectPlanDialogState();
}

class _RejectPlanDialogState extends State<RejectPlanDialog> {
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payload = widget.notification.payload;
    final price = (payload['plan_price'] as num?)?.toDouble() ?? 0.0;
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    return AlertDialog(
      title: const Text("Rechazar Solicitud"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _readOnlyRow("Cliente", widget.notification.fromUserName),
                  const SizedBox(height: 5),
                  _readOnlyRow("Plan", payload['plan_name'] ?? '-'),
                  const SizedBox(height: 5),
                  _readOnlyRow("Valor", currencyFormat.format(price)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text("Motivo de rechazo (Opcional):"),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "Escribe una observación para el usuario...",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            widget.onReject(_reasonCtrl.text.trim());
            Navigator.pop(context);
          },
          child: const Text("Rechazar"),
        ),
      ],
    );
  }

  Widget _readOnlyRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).disabledColor,
          ),
        ),
      ],
    );
  }
}
