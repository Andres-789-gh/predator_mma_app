import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../plans/domain/models/plan_model.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/date_utils.dart';

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
    DateTime validUntil,
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
  late DateTime validUntil;

  String selectedPaymentMethod = 'Efectivo';
  final List<String> paymentMethods = [
    'Efectivo',
    'Tarjeta',
    'Transferencia',
    'Otro',
  ];
  final _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    validUntil = AppDateUtils.calculateGymEndDate(DateTime.now(), 1);
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _updatePrice() {
    if (selectedPlan != null) {
      price = selectedPlan!.price * quantity;
      _priceController.text = price.toStringAsFixed(0);
    }
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
              initialValue: selectedPlan,
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
                  quantity = 1;
                  _updatePrice();
                });
              },
            ),
            const SizedBox(height: 15),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Cantidad:"),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => setState(() {
                        if (quantity > 1) {
                          quantity--;
                          _updatePrice();
                        }
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
                        _updatePrice();
                      }),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 15),

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

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Fecha de Vencimiento"),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(validUntil)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: validUntil,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 1000)),
                );
                if (picked != null) {
                  setState(() => validUntil = picked);
                }
              },
            ),
            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              initialValue: selectedPaymentMethod,
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

            TextField(
              decoration: const InputDecoration(
                labelText: "Observaciones (Opcional)",
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

    final note = reason.trim().isEmpty ? "Sin observaciones" : reason.trim();

    widget.onTicketAdded(
      quantity,
      price,
      selectedPaymentMethod,
      note,
      selectedPlan!.scheduleRules,
      selectedPlan!.name,
      validUntil,
    );
    Navigator.pop(context);
  }
}
