import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../auth/domain/models/access_exception_model.dart';
import '../../../../plans/domain/models/plan_model.dart';
import '../../../../../core/utils/currency_formatter.dart';

class AddTicketDialog extends StatefulWidget {
  final List<PlanModel> availablePlans;
  final String currentAdminName;
  final Function(AccessExceptionModel) onTicketAdded;

  const AddTicketDialog({
    super.key,
    required this.availablePlans,
    required this.currentAdminName,
    required this.onTicketAdded,
  });

  @override
  State<AddTicketDialog> createState() => _AddTicketDialogState();
}

class _AddTicketDialogState extends State<AddTicketDialog> {
  int quantity = 1;
  PlanModel? selectedPlan;
  String reason = "";
  double price = 0;
  DateTime? validUntil;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Agregar Ingreso Extra"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Selección del plan base
            DropdownButtonFormField<PlanModel>(
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: "Plan Base",
                border: OutlineInputBorder(),
              ),
              items: widget.availablePlans
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                  .toList(),
              onChanged: (val) => setState(() => selectedPlan = val),
            ),
            const SizedBox(height: 10),

            // Precio
            TextField(
              decoration: const InputDecoration(
                labelText: "Precio (Opcional)",
                prefixText: "\$ ",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CurrencyInputFormatter(),
              ],
              onChanged: (v) =>
                  price = double.tryParse(v.replaceAll('.', '')) ?? 0,
            ),
            const SizedBox(height: 10),

            // Motivo
            TextField(
              decoration: const InputDecoration(
                labelText: "Motivo (Opcional)",
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => reason = v,
            ),
            const SizedBox(height: 10),

            // Vencimiento
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => validUntil = picked);
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: "Vencimiento (Opcional)",
                  border: const OutlineInputBorder(),
                  suffixIcon: validUntil != null
                      ? IconButton(
                          icon: const Icon(
                            Icons.delete_rounded,
                            color: Colors.red,
                          ),
                          onPressed: () => setState(() => validUntil = null),
                        )
                      : const Icon(Icons.calendar_today),
                ),
                child: Text(
                  validUntil != null
                      ? DateFormat('dd/MM/yyyy').format(validUntil!)
                      : "Sin vencimiento (Indefinido)",
                  style: TextStyle(
                    color: validUntil == null ? Colors.grey : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Cantidad
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Cantidad:"),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => setState(() {
                        if (quantity > 1) quantity--;
                      }),
                      icon: const Icon(Icons.remove),
                    ),
                    Text(
                      "$quantity",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => setState(() {
                        quantity++;
                      }),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
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
          onPressed: selectedPlan == null ? null : _confirmAdd,
          child: const Text("Agregar"),
        ),
      ],
    );
  }

  void _confirmAdd() {
    final newTicket = AccessExceptionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      originalPlanName: selectedPlan!.name,
      quantity: quantity,
      price: price,
      scheduleRules: selectedPlan!.scheduleRules,
      validUntil: validUntil,
      grantedAt: DateTime.now(),
      grantedBy: widget.currentAdminName,
      reason: reason.trim().isEmpty ? null : reason.trim(),
    );

    widget.onTicketAdded(newTicket);
    Navigator.pop(context);
  }
}
