import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/models/notification_model.dart';

class ApprovePlanDialog extends StatefulWidget {
  final NotificationModel notification;
  // devuelve: precio, inicio, fin, metodo pago, nota
  final Function(double, DateTime, DateTime, String, String?) onApprove;

  const ApprovePlanDialog({
    super.key,
    required this.notification,
    required this.onApprove,
  });

  @override
  State<ApprovePlanDialog> createState() => _ApprovePlanDialogState();
}

class _ApprovePlanDialogState extends State<ApprovePlanDialog> {
  late TextEditingController _priceCtrl;
  late TextEditingController _noteCtrl;
  late DateTime _startDate;
  late DateTime _endDate;
  late double _basePrice;
  
  // estado para metodo de pago
  String _selectedPaymentMethod = 'Efectivo';
  final List<String> _paymentMethods = [
    'Efectivo',
    'Tarjeta',
    'Transferencia',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    final payload = widget.notification.payload;
    _basePrice = (payload['plan_price'] as num).toDouble();
    
    final currencyFormat = NumberFormat('#,###', 'es_CO');
    _priceCtrl = TextEditingController(text: currencyFormat.format(_basePrice));
    _noteCtrl = TextEditingController();

    _startDate = DateTime.now();
    _calculateInitialEndDate(payload);
  }

  void _calculateInitialEndDate(Map<String, dynamic> payload) {
    final typeStr = payload['consumption_type'] ?? '';
    if (typeStr.contains('pack')) {
      _endDate = _startDate.add(const Duration(days: 30));
    } else {
      _endDate = AppDateUtils.calculateGymEndDate(_startDate, 1);
    }
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Aprobar Solicitud"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow("Cliente:", widget.notification.fromUserName),
            const SizedBox(height: 5),
            _buildInfoRow("Plan:", widget.notification.payload['plan_name'] ?? 'N/A'),
            const Divider(height: 20),
            
            const Text(
              "Detalles de la Venta",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 15),

            // metodo de pago (obligatorio para reportes)
            DropdownButtonFormField<String>(
              value: _selectedPaymentMethod,
              decoration: const InputDecoration(
                labelText: "Método de Pago",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payment, size: 20),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              items: _paymentMethods.map((m) {
                return DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 14)));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedPaymentMethod = val);
              },
            ),
            const SizedBox(height: 15),

            // precio
            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CurrencyInputFormatter(),
              ],
              decoration: const InputDecoration(
                labelText: "Precio Final",
                prefixText: "\$ ",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),

            // fechas
            Row(
              children: [
                Expanded(
                  child: _buildDatePicker(
                    context,
                    label: "Inicia",
                    date: _startDate,
                    onPick: (d) => setState(() => _startDate = d),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildDatePicker(
                    context,
                    label: "Vence",
                    date: _endDate,
                    onPick: (d) => setState(() => _endDate = d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // nota
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: "Nota (Opcional)",
                border: OutlineInputBorder(),
                isDense: true,
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
          onPressed: _submit,
          child: const Text("Aprobar"),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDatePicker(
    BuildContext context, {
    required String label,
    required DateTime date,
    required Function(DateTime) onPick,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2024),
          lastDate: DateTime(2030),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        ),
        child: Text(
          DateFormat('dd/MM/yyyy').format(date),
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  void _submit() {
    final rawPrice = _priceCtrl.text.replaceAll('.', '').replaceAll(',', '');
    final finalPrice = double.tryParse(rawPrice) ?? 0.0;

    // enviamos todos los datos incluido el metodo de pago
    widget.onApprove(finalPrice, _startDate, _endDate, _selectedPaymentMethod, _noteCtrl.text);
    Navigator.pop(context);
  }
}