import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../plans/domain/models/plan_model.dart';
import '../../../../core/constants/enums.dart';

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
  
  // Para asignar plan nuevo
  DateTime _startDate = DateTime.now();
  int _monthsDuration = 1;

  @override
  void initState() {
    super.initState();
    _isLegacyUser = widget.user.isLegacyUser;
  }

  @override
  Widget build(BuildContext context) {
    final activePlan = widget.user.activePlan;
    final hasActivePlan = activePlan != null && activePlan.isActive(DateTime.now());

    return AlertDialog(
      scrollable: true,
      title: Text("Gestión: ${widget.user.firstName}"),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. SWITCH USUARIO ANTIGUO [cite: 123]
          SwitchListTile(
            title: const Text("Usuario Antiguo (Legacy)"),
            subtitle: const Text("Puede entrar a múltiples clases sin plan Unlimited."),
            value: _isLegacyUser,
            onChanged: (v) => setState(() => _isLegacyUser = v),
          ),
          const Divider(),

          // 2. PLAN ACTUAL Y PAUSA INDIVIDUAL [cite: 184]
          if (hasActivePlan) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Plan Actual: ${activePlan!.name}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text("Vence: ${DateFormat('dd/MM/yyyy').format(activePlan.effectiveEndDate)}"),
                  if (activePlan.dailyLimit != null)
                    Text("Límite Diario: ${activePlan.dailyLimit} clases"),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.pause),
                      label: const Text("Pausar este Plan"),
                      onPressed: _showPauseDialog,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text("O asignar uno nuevo (Reemplazar):", style: TextStyle(fontWeight: FontWeight.bold)),
          ] else ...[
            const Text("El usuario no tiene plan activo.", style: TextStyle(color: Colors.red)),
            const SizedBox(height: 10),
            const Text("Asignar Nuevo Plan:", style: TextStyle(fontWeight: FontWeight.bold)),
          ],

          // 3. ASIGNACIÓN DE PLAN (MANUAL) [cite: 23]
          const SizedBox(height: 10),
          DropdownButtonFormField<PlanModel>(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: "Seleccionar Plan",
            ),
            items: widget.availablePlans.map((p) {
              return DropdownMenuItem(value: p, child: Text("${p.name} (\$${p.price.toInt()})"));
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
                  onPressed: () => setState(() => _monthsDuration = (_monthsDuration > 1) ? _monthsDuration - 1 : 1),
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
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
      // Crear el UserPlan a partir del PlanModel seleccionado
      final endDate = DateTime(
        _startDate.year,
        _startDate.month + _monthsDuration,
        _startDate.day,
      );

      final newUserPlan = UserPlan(
        planId: _selectedNewPlan!.id,
        name: _selectedNewPlan!.name,
        consumptionType: _selectedNewPlan!.consumptionType,
        scheduleRules: _selectedNewPlan!.scheduleRules,
        startDate: _startDate,
        endDate: endDate,
        dailyLimit: _selectedNewPlan!.dailyLimit, // IMPORTANTE: Se copia el límite aquí
        remainingClasses: _selectedNewPlan!.packClassesQuantity,
        pauses: [],
      );

      updatedUser = updatedUser.copyWith(activePlan: newUserPlan);
    }

    widget.onSave(updatedUser);
    Navigator.pop(context);
  }

  void _showPauseDialog() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: widget.user.activePlan!.effectiveEndDate,
      helpText: "Selecciona el rango de la pausa",
    );

    if (picked != null) {
      // Aplicar pausa inmediatamente al objeto local y guardar
      final newPause = PlanPause(
        startDate: picked.start,
        endDate: picked.end,
        createdBy: 'Admin Manual',
      );
      
      final currentPlan = widget.user.activePlan!;
      final updatedPauses = List<PlanPause>.from(currentPlan.pauses)..add(newPause);
      final updatedPlan = currentPlan.copyWith(pauses: updatedPauses);
      
      final userWithPause = widget.user.copyWith(activePlan: updatedPlan);
      
      // Guardar directamente y cerrar dialogos
      widget.onSave(userWithPause);
      if (mounted) Navigator.pop(context); // Cerrar dialogo principal
    }
  }
}