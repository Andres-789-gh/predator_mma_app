import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../../core/constants/enums.dart';
import '../../../schedule/domain/models/class_model.dart';
import '../cubit/admin_cubit.dart';

class EditClassDialog extends StatefulWidget {
  final ClassModel classModel;
  final List<UserModel> instructors;

  const EditClassDialog({
    super.key,
    required this.classModel,
    required this.instructors,
  });

  @override
  State<EditClassDialog> createState() => _EditClassDialogState();
}

class _EditClassDialogState extends State<EditClassDialog> {
  late UserModel _selectedCoach;
  late TextEditingController _capacityCtrl;
  ClassEditMode _selectedMode = ClassEditMode.single;
  
  // variables visuales
  late String _dayName;
  late String _timeStr;

  @override
  void initState() {
    super.initState();
    // inicializa instructor buscando el actual en la lista
    try {
      _selectedCoach = widget.instructors.firstWhere((u) => u.userId == widget.classModel.coachId);
    } catch (_) {
      // usa el primero si no encuentra coincidencia
      _selectedCoach = widget.instructors.first; 
    }
    
    _capacityCtrl = TextEditingController(text: widget.classModel.maxCapacity.toString());
    
    // formatea fecha para mostrar
    _dayName = DateFormat('EEEE', 'es').format(widget.classModel.startTime);
    _dayName = _dayName[0].toUpperCase() + _dayName.substring(1);
    _timeStr = DateFormat('h:mm a').format(widget.classModel.startTime);
  }

  @override
  void dispose() {
    _capacityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Editar Clase: ${widget.classModel.classType}"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // muestra informacion inmutable de fecha
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text("$_dayName - $_timeStr", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // selecciona instructor
            DropdownButtonFormField<UserModel>(
              value: _selectedCoach,
              decoration: const InputDecoration(labelText: "Profesor", border: OutlineInputBorder()),
              items: widget.instructors.map((u) {
                return DropdownMenuItem(
                  value: u,
                  child: Text("${u.firstName} ${u.lastName}"),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCoach = val);
              },
            ),
            const SizedBox(height: 15),

            // ingresa cupo maximo
            TextField(
              controller: _capacityCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Cupo Máximo", border: OutlineInputBorder()),
            ),
            
            const SizedBox(height: 25),
            const Divider(),
            const Text("Alcance de la edición:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // selecciona modo de edicion
            _buildRadioOption(
              value: ClassEditMode.single,
              title: "Solo esta clase",
              subtitle: "Cambios solo para el $_dayName $_timeStr específico.",
            ),
            _buildRadioOption(
              value: ClassEditMode.similar,
              title: "Todas las similares",
              subtitle: "Todas las de este horario (mismo día y hora).",
            ),
            _buildRadioOption(
              value: ClassEditMode.allType,
              title: "Todas las de tipo '${widget.classModel.classType}'",
              subtitle: "Cambio masivo global (Cupo/Profesor).",
              isWarning: true,
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
          child: const Text("Guardar Cambios"),
        ),
      ],
    );
  }

  // construye opcion de radio button
  Widget _buildRadioOption({
    required ClassEditMode value, 
    required String title, 
    required String subtitle,
    bool isWarning = false,
  }) {
    return RadioListTile<ClassEditMode>(
      value: value,
      groupValue: _selectedMode,
      onChanged: (v) => setState(() => _selectedMode = v!),
      title: Text(title, style: TextStyle(color: isWarning ? Colors.red : null, fontWeight: isWarning ? FontWeight.bold : null)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      contentPadding: EdgeInsets.zero,
      activeColor: isWarning ? Colors.red : Colors.blue,
    );
  }

  // valida y confirma accion
  void _submit() {
    final cap = int.tryParse(_capacityCtrl.text);
    if (cap == null || cap <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cupo inválido")));
      return;
    }

    // solicita confirmacion extra si es masivo
    if (_selectedMode == ClassEditMode.similar || _selectedMode == ClassEditMode.allType) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("⚠️ Confirmación Requerida"),
          content: Text("Estás a punto de modificar MÚLTIPLES clases.\n\n¿Estás seguro?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Revisar")),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(ctx); 
                Navigator.pop(context); 
                _executeEdit(cap);
              }, 
              child: const Text("Confirmar"),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
      _executeEdit(cap);
    }
  }

  // ejecuta la edicion llamando al cubit
  void _executeEdit(int newCapacity) {
    final updated = widget.classModel.copyWith(
      coachId: _selectedCoach.userId,
      coachName: "${_selectedCoach.firstName} ${_selectedCoach.lastName}",
      maxCapacity: newCapacity,
    );

    context.read<AdminCubit>().editClass(
      originalClass: widget.classModel,
      updatedClass: updated,
      mode: _selectedMode,
    );
  }
}