import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../plans/domain/models/plan_model.dart';
import '../../../../auth/domain/models/user_model.dart';
import '../../../../../core/constants/enums.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/date_utils.dart';

class AssignPlanDialog extends StatefulWidget {
  final List<PlanModel> availablePlans;
  final Function(UserPlan) onPlanAssigned;

  const AssignPlanDialog({
    super.key,
    required this.availablePlans,
    required this.onPlanAssigned,
  });

  @override
  State<AssignPlanDialog> createState() => _AssignPlanDialogState();
}

class _AssignPlanDialogState extends State<AssignPlanDialog> {
  PlanModel? selectedPlan;
  int durationMonths = 1;
  DateTime startDate = DateTime.now();
  final priceCtrl = TextEditingController();
  DateTime newEndDate = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    priceCtrl.dispose();
    super.dispose();
  }

  void recalculateValues() {
    if (selectedPlan != null) {
      if (selectedPlan!.consumptionType == PlanConsumptionType.pack) {
        // tiquetera
        newEndDate = startDate.add(const Duration(days: 30));
      } else {
        // mensualidad
        newEndDate = AppDateUtils.calculateGymEndDate(
          startDate,
          durationMonths,
        );
      }

      // Calculo precio
      priceCtrl.text = (selectedPlan!.price * durationMonths).toStringAsFixed(
        0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Asignar / Renovar Plan"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Select plan
            DropdownButtonFormField<PlanModel>(
              value: selectedPlan,
              decoration: const InputDecoration(
                labelText: "Selecciona el Plan",
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              items: widget.availablePlans.map((p) {
                return DropdownMenuItem(value: p, child: Text(p.name));
              }).toList(),
              onChanged: (val) {
                setState(() {
                  selectedPlan = val;
                  recalculateValues();
                });
              },
            ),
            const SizedBox(height: 15),

            // Duracion
            DropdownButtonFormField<int>(
              value: durationMonths,
              decoration: const InputDecoration(
                labelText: "Duración",
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              items: [1, 2, 3, 6, 12].map((m) {
                return DropdownMenuItem(value: m, child: Text("$m Mes(es)"));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    durationMonths = val;
                    recalculateValues();
                  });
                }
              },
            ),
            const SizedBox(height: 15),

            // Fechas
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() {
                          startDate = picked;
                          recalculateValues();
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Inicia el",
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today, size: 16),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      child: Text(
                        DateFormat('dd/MM/yyyy').format(startDate),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: "Vence el",
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Color(0xFFF5F5F5),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      DateFormat('dd/MM/yyyy').format(newEndDate),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // Precio
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CurrencyInputFormatter(),
              ],
              decoration: const InputDecoration(
                labelText: "Precio del Plan",
                prefixText: "\$ ",
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
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
          onPressed: selectedPlan == null ? null : _confirmAssignment,
          child: const Text("Continuar"),
        ),
      ],
    );
  }

  Future<void> _confirmAssignment() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (alertCtx) => AlertDialog(
        title: const Text("¿Confirmar Asignación?"),
        content: Text(
          "Se asignará '${selectedPlan!.name}' por $durationMonths mes(es).\n\n"
          "Vence: ${DateFormat('dd/MM/yyyy').format(newEndDate)}\n"
          "Valor: \$${priceCtrl.text}",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(alertCtx, false),
            child: const Text("Revisar"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(alertCtx, true),
            child: const Text("Asignar"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;

      final newAssignedPlan = UserPlan(
        planId: selectedPlan!.id,
        name: selectedPlan!.name,
        consumptionType: selectedPlan!.consumptionType,
        scheduleRules: selectedPlan!.scheduleRules,
        startDate: startDate,
        endDate: newEndDate,
        dailyLimit: selectedPlan!.dailyLimit,
        pauses: const [],
        remainingClasses:
            selectedPlan!.consumptionType == PlanConsumptionType.pack
            ? (selectedPlan!.packClassesQuantity ?? 0)
            : null,
      );

      widget.onPlanAssigned(newAssignedPlan);
      Navigator.pop(context);
    }
  }
}
