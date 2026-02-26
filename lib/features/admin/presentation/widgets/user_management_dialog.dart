import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../plans/domain/models/plan_model.dart';

class UserManagementDialog extends StatefulWidget {
  final UserModel user;
  final List<PlanModel> availablePlans;
  final Function(UserModel) onSave;

  const UserManagementDialog({
    super.key,
    required this.user,
    required this.availablePlans,
    required this.onSave,
  });

  @override
  State<UserManagementDialog> createState() => _UserManagementDialogState();
}

class _UserManagementDialogState extends State<UserManagementDialog> {
  late bool _isLegacyUser;
  PlanModel? _selectedNewPlan;

  // asignar plan nuevo
  final DateTime _startDate = DateTime.now();
  int _monthsDuration = 1;

  @override
  void initState() {
    super.initState();
    _isLegacyUser = widget.user.isLegacyUser;
  }

  @override
  Widget build(BuildContext context) {
    final activePlans = widget.user.currentPlans;
    final hasActivePlans = activePlans.isNotEmpty;

    return AlertDialog(
      scrollable: true,
      title: Text("Gestión: ${widget.user.firstName}"),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text("Usuario Antiguo (Legacy)"),
            subtitle: const Text("Tiene ingresos diarios ilimitados."),
            value: _isLegacyUser,
            onChanged: (v) => setState(() => _isLegacyUser = v),
          ),
          const Divider(),

          // Lista de planes activos
          if (hasActivePlans) ...[
            const Text(
              "Planes Activos:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // tarjeta x plan activo
            ...activePlans.map(
              (plan) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Plan: ${plan.name}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Vence: ${DateFormat('dd/MM/yyyy').format(plan.effectiveEndDate)}",
                    ),
                    if (plan.dailyLimit != null)
                      Text("Límite Diario: ${plan.dailyLimit} clases"),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.pause),
                        label: const Text("Pausar este Plan"),
                        onPressed: () => _showPauseDialog(plan),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Divider(),
            const Text(
              "Agregar Plan:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ] else ...[
            const Text(
              "El usuario no tiene planes activos.",
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 10),
            const Text(
              "Asignar Nuevo Plan:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],

          const SizedBox(height: 10),

          // Selector nuevo plan
          DropdownButtonFormField<PlanModel>(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: "Seleccionar Plan del Catálogo",
            ),
            items: widget.availablePlans.map((p) {
              return DropdownMenuItem(
                value: p,
                child: Text("${p.name} (\$${p.price.toInt()})"),
              );
            }).toList(),
            onChanged: (p) => setState(() => _selectedNewPlan = p),
          ),

          if (_selectedNewPlan != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Text("Duración: "),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => setState(
                    () => _monthsDuration = (_monthsDuration > 1)
                        ? _monthsDuration - 1
                        : 1,
                  ),
                ),
                Text("$_monthsDuration Mes(es)"),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => _monthsDuration++),
                ),
              ],
            ),
            Text("Inicia: ${DateFormat('dd/MM/yyyy').format(_startDate)}"),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
        FilledButton(
          onPressed: _saveChanges,
          child: const Text("Guardar Cambios"),
        ),
      ],
    );
  }

  void _saveChanges() {
    UserModel updatedUser = widget.user.copyWith(isLegacyUser: _isLegacyUser);

    if (_selectedNewPlan != null) {
      final endDate = DateTime(
        _startDate.year,
        _startDate.month + _monthsDuration,
        _startDate.day,
      );

      final String uniqueId = const Uuid().v4();
      final newUserPlan = UserPlan(
        subscriptionId: uniqueId,
        planId: _selectedNewPlan!.id,
        name: _selectedNewPlan!.name,
        price: _selectedNewPlan!.price,
        consumptionType: _selectedNewPlan!.consumptionType,
        scheduleRules: _selectedNewPlan!.scheduleRules,
        startDate: _startDate,
        endDate: endDate,
        dailyLimit: _selectedNewPlan!.dailyLimit,
        remainingClasses: _selectedNewPlan!.packClassesQuantity,
        pauses: [],
      );

      final updatedPlans = List<UserPlan>.from(updatedUser.currentPlans)
        ..add(newUserPlan);

      updatedUser = updatedUser.copyWith(currentPlans: updatedPlans);
    }

    widget.onSave(updatedUser);
    Navigator.pop(context);
  }

  void _showPauseDialog(UserPlan targetPlan) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: targetPlan.effectiveEndDate,
      helpText: "Selecciona el rango de la pausa para '${targetPlan.name}'",
    );

    if (picked != null) {
      final newPause = PlanPause(
        startDate: picked.start,
        endDate: picked.end,
        createdBy: 'Admin Manual',
      );

      final updatedPauses = List<PlanPause>.from(targetPlan.pauses)
        ..add(newPause);
      final updatedPlan = targetPlan.copyWith(pauses: updatedPauses);
      final updatedList = widget.user.currentPlans.map((p) {
        return p.subscriptionId == targetPlan.subscriptionId ? updatedPlan : p;
      }).toList();

      final userWithPause = widget.user.copyWith(currentPlans: updatedList);

      widget.onSave(userWithPause);
      if (mounted) Navigator.pop(context);
    }
  }
}
