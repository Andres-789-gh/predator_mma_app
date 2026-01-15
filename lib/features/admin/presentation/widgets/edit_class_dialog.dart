import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../../core/constants/enums.dart';
import '../../../schedule/domain/models/class_model.dart';
import '../../../schedule/domain/models/class_type_model.dart';
import '../cubit/admin_cubit.dart';
import '../cubit/admin_state.dart';

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
  late TextEditingController _capacityController;
  late TimeOfDay _startTime;
  late TextEditingController _hoursController;
  late TextEditingController _minutesController;
  
  String? _selectedTypeId;
  ClassEditMode _selectedMode = ClassEditMode.single;

  @override
  void initState() {
    super.initState();
    try {
      _selectedCoach = widget.instructors.firstWhere((u) => u.userId == widget.classModel.coachId);
    } catch (_) {
      _selectedCoach = widget.instructors.first; 
    }
    _capacityController = TextEditingController(text: widget.classModel.maxCapacity.toString());
    _startTime = TimeOfDay.fromDateTime(widget.classModel.startTime);
    final totalMinutes = widget.classModel.endTime.difference(widget.classModel.startTime).inMinutes;
    final hrs = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    
    _hoursController = TextEditingController(text: hrs.toString());
    _minutesController = TextEditingController(text: mins.toString().padLeft(2, '0'));

    _selectedTypeId = widget.classModel.classTypeId;
  }

  @override
  void dispose() {
    _capacityController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AdminCubit>().state;
    List<ClassTypeModel> classTypes = [];
    
    if (state is AdminLoadedData) {
       classTypes = state.classTypes;
    } else if (state is! AdminLoading && state is! AdminInitial) {
       try {
         classTypes = (state as dynamic).classTypes ?? [];
       } catch (_) {}
    }

    if (classTypes.isNotEmpty) {
      final exists = classTypes.any((t) => t.id == _selectedTypeId);
      if (!exists) {
        _selectedTypeId = null;
      }
    }

    final hrs = int.tryParse(_hoursController.text) ?? 0;
    final mins = int.tryParse(_minutesController.text) ?? 0;
    final durationMin = (hrs * 60) + mins;

    final startDt = DateTime(2024, 1, 1, _startTime.hour, _startTime.minute);
    final endDt = startDt.add(Duration(minutes: durationMin));
    final timeStr = "${DateFormat('h:mm a').format(startDt)} - ${DateFormat('h:mm a').format(endDt)}";

    return AlertDialog(
      scrollable: true,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Editar Clase: ${widget.classModel.classType}", style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
            child: Text(timeStr, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selector de clase
          if (classTypes.isNotEmpty)
            DropdownButtonFormField<String>(
              value: _selectedTypeId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: "Clase", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
              items: classTypes.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
              onChanged: (v) => setState(() => _selectedTypeId = v),
              hint: const Text("Seleccionar clase"),
            ),
          const SizedBox(height: 15),

          // Hora Inicio y Duración
          Row(
            children: [
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: _pickTime,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: "Inicio", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                    child: Text(_startTime.format(context), style: const TextStyle(fontSize: 15)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _hoursController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: "Hrs", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 12)),
                  onChanged: (_) => setState((){}),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _minutesController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: "Min", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 12)),
                  onChanged: (_) => setState((){}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Profesor y Cupo
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<UserModel>(
                  value: _selectedCoach,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: "Profesor", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                  items: widget.instructors.map((u) => DropdownMenuItem(value: u, child: Text("${u.firstName} ${u.lastName}", overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCoach = val);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _capacityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Cupo", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 25),
          const Divider(),
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text("Alcance de la acción:", style: TextStyle(fontWeight: FontWeight.bold)),
          ),

          // Selector de Alcance
          Row(
            children: [
              _buildScopeOption(ClassEditMode.single, "Solo esta", Icons.event),
              const SizedBox(width: 8),
              _buildScopeOption(ClassEditMode.similar, "Similares", Icons.copy), 
              const SizedBox(width: 8),
              _buildScopeOption(ClassEditMode.allType, "Todas", Icons.all_inclusive, isWarning: true),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(),
          Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
              ),
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text("Eliminar Clase"),
            ),
          ),
        ],
      ),
      actions: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            FilledButton(
              onPressed: _submitEdit,
              child: const Text("Guardar"),
            ),
          ],
        )
      ],
      actionsAlignment: MainAxisAlignment.end,
    );
  }

  Widget _buildScopeOption(ClassEditMode mode, String label, IconData icon, {bool isWarning = false}) {
    final isSelected = _selectedMode == mode;
    final color = isWarning ? Colors.red : Colors.blue;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMode = mode),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
            border: Border.all(
              color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey, size: 20),
              const SizedBox(height: 4),
              Text(
                label, 
                style: TextStyle(
                  fontSize: 11, 
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : Colors.grey[700]
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _startTime);
    if (t != null) setState(() => _startTime = t);
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
             Icon(Icons.warning_amber_rounded, color: Colors.orange),
             SizedBox(width: 10),
             Text("¿Eliminar Clase?"),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style.copyWith(fontSize: 16),
            children: [
              const TextSpan(text: "Estás a punto de eliminar "),
              if (_selectedMode != ClassEditMode.single)
                 const TextSpan(text: "MÚLTIPLES", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              if (_selectedMode != ClassEditMode.single)
                 const TextSpan(text: " clases según tu selección.\n\n"),
              if (_selectedMode == ClassEditMode.single)
                 const TextSpan(text: "solo esta clase.\n\n"),
              const TextSpan(text: "Esta acción no se puede deshacer."),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx); 
              Navigator.pop(context); 
              context.read<AdminCubit>().deleteClass(
                classModel: widget.classModel,
                mode: _selectedMode,
              );
            }, 
            child: const Text("Sí, Eliminar"),
          ),
        ],
      ),
    );
  }

  void _submitEdit() {
    final cap = int.tryParse(_capacityController.text);
    if (cap == null || cap <= 0) return;

    final hrs = int.tryParse(_hoursController.text) ?? 0;
    final mins = int.tryParse(_minutesController.text) ?? 0;
    final totalDuration = (hrs * 60) + mins;
    if (totalDuration <= 0) return;

    String typeName = widget.classModel.classType;
    if (_selectedTypeId != null && _selectedTypeId != widget.classModel.classTypeId) {
       final state = context.read<AdminCubit>().state;
       if (state is AdminLoadedData) {
          try {
            final type = state.classTypes.firstWhere((t) => t.id == _selectedTypeId);
            typeName = type.name;
          } catch (_) {}
       } else if (state is dynamic) {
          try {
            final list = (state as dynamic).classTypes as List<ClassTypeModel>;
            final type = list.firstWhere((t) => t.id == _selectedTypeId);
            typeName = type.name;
          } catch (_) {}
       }
    }

    final currentDay = widget.classModel.startTime;
    final newStart = DateTime(currentDay.year, currentDay.month, currentDay.day, _startTime.hour, _startTime.minute);
    final newEnd = newStart.add(Duration(minutes: totalDuration));

    final updated = widget.classModel.copyWith(
      coachId: _selectedCoach.userId,
      coachName: "${_selectedCoach.firstName} ${_selectedCoach.lastName}",
      maxCapacity: cap,
      classTypeId: _selectedTypeId,
      classType: typeName,
      startTime: newStart,
      endTime: newEnd,
    );

    if (_selectedMode != ClassEditMode.single) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
               Icon(Icons.warning_amber_rounded, color: Colors.orange),
               SizedBox(width: 10),
               Text("Cambio Masivo"),
            ],
          ),
          content: RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style.copyWith(fontSize: 16),
              children: const [
                TextSpan(text: "Estás a punto de modificar "),
                TextSpan(text: "MÚLTIPLES", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                TextSpan(text: " clases.\n\n¿Confirmar cambios?"),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Revisar")),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx); 
                Navigator.pop(context); 
                context.read<AdminCubit>().editClass(
                  originalClass: widget.classModel,
                  updatedClass: updated,
                  mode: _selectedMode,
                );
              }, 
              child: const Text("Confirmar"),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
      context.read<AdminCubit>().editClass(
        originalClass: widget.classModel,
        updatedClass: updated,
        mode: _selectedMode,
      );
    }
  }
}