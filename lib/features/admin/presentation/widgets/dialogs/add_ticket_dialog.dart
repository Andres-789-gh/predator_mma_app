import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../plans/domain/models/plan_model.dart';
import '../../../../../core/utils/currency_formatter.dart';

class AddTicketDialog extends StatefulWidget {
  final List<PlanModel> availablePlans;
  final String currentAdminName;
  final Function(
    int quantity,
    double price,
    String paymentMethod,
    String note,
    List<ScheduleRule> rules,
    String planName,
  )
  onTicketAdded;

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

  String selectedPaymentMethod = 'Efectivo';
  final List<String> paymentMethods = [
    'Efectivo',
    'Tarjeta',
    'Transferencia',
    'Otro',
  ];
  final _priceController = TextEditingController();

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isValid = selectedPlan != null;

    return AlertDialog(
      title: const Text("Vender Ingreso Extra"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<PlanModel>(
              isExpanded: true,
              value: selectedPlan,
              decoration: const InputDecoration(
                labelText: "Plan Base (Obligatorio)",
                border: OutlineInputBorder(),
                helperText: "Define los horarios de acceso",
              ),
              items: widget.availablePlans
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  selectedPlan = val;
                  price = val?.price ?? 0;
                  _priceController.text = price.toStringAsFixed(0);
                });
              },
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
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      "$quantity",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() {
                        quantity++;
                      }),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 15),

            // Precio
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: "Precio Total",
                prefixText: "\$ ",
                border: OutlineInputBorder(),
                hintText: "0",
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CurrencyInputFormatter(),
              ],
              onChanged: (v) {
                final clean = v.replaceAll(RegExp(r'[^0-9]'), '');
                price = double.tryParse(clean) ?? 0;
              },
            ),
            const SizedBox(height: 15),

            // Método de Pago
            DropdownButtonFormField<String>(
              value: selectedPaymentMethod,
              decoration: const InputDecoration(
                labelText: "Método de Pago",
                border: OutlineInputBorder(),
              ),
              items: paymentMethods.map((m) {
                return DropdownMenuItem(value: m, child: Text(m));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => selectedPaymentMethod = val);
              },
            ),
            const SizedBox(height: 15),

            // Motivo
            TextField(
              decoration: const InputDecoration(
                labelText: "Observación (Opcional)",
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => reason = v,
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
          onPressed: isValid ? _confirmAdd : null,
          child: const Text("Confirmar Venta"),
        ),
      ],
    );
  }

  void _confirmAdd() {
    if (selectedPlan == null) return;

    final note = reason.trim().isEmpty
        ? "Venta Ingreso: ${selectedPlan!.name}"
        : reason.trim();

    widget.onTicketAdded(
      quantity,
      price,
      selectedPaymentMethod,
      note,
      selectedPlan!.scheduleRules,
      selectedPlan!.name,
    );
    Navigator.pop(context);
  }
}
