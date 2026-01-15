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

    // Detector de clases pasadas
    final isHistory = widget.classModel.endTime.isBefore(DateTime.now());

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
          // Etiqueta visual de clase pasada
          if (isHistory)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
              child: const Text("HISTORIAL - SOLO LECTURA", style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold)),
            )
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selector de clase (Deshabilitado si es pasada)
          if (classTypes.isNotEmpty)
            DropdownButtonFormField<String>(
              value: _selectedTypeId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: "Clase", 
                border: const OutlineInputBorder(), 
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                enabled: !isHistory
              ),
              items: classTypes.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
              onChanged: isHistory ? null : (v) => setState(() => _selectedTypeId = v),
              hint: const Text("Seleccionar clase"),
            ),
          const SizedBox(height: 15),

          // Hora Inicio y Duración
          Row(
            children: [
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: isHistory ? null : _pickTime,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: "Inicio", 
                      border: const OutlineInputBorder(), 
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      enabled: !isHistory
                    ),
                    child: Text(
                      _startTime.format(context), 
                      style: TextStyle(
                        fontSize: 15,
                        color: isHistory ? Colors.grey : null 
                      )
                    ),
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
                  decoration: InputDecoration(labelText: "Hrs", border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 12), enabled: !isHistory),
                  onChanged: (_) => setState((){}),
                  enabled: !isHistory,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _minutesController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(labelText: "Min", border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 12), enabled: !isHistory),
                  onChanged: (_) => setState((){}),
                  enabled: !isHistory,
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
                  decoration: InputDecoration(labelText: "Profesor", border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), enabled: !isHistory),
                  items: widget.instructors.map((u) => DropdownMenuItem(value: u, child: Text("${u.firstName} ${u.lastName}", overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: isHistory ? null : (val) {
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
                  decoration: InputDecoration(labelText: "Cupo", border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), enabled: !isHistory),
                  enabled: !isHistory,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 25),
          const Divider(),
          
          if (!isHistory) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text("Alcance de la acción:", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
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
          ],

          // Btn eliminar / mensaje pasada
          if (!isHistory)
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
            )
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 10, bottom: 8),
                child: Text(
                  "Clase finalizada (No editable)",
                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                ),
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
              child: Text(isHistory ? "Volver" : "Cancelar"),
            ),
            if (!isHistory)
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
    FocusManager.instance.primaryFocus?.unfocus();

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
        content: Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 16),
            children: [
              const TextSpan(text: "Estás a punto de eliminar "),
              
              if (_selectedMode != ClassEditMode.single)
                 const TextSpan(
                   text: "MÚLTIPLES", 
                   style: TextStyle(fontWeight: FontWeight.bold)
                 ),
                 
              if (_selectedMode != ClassEditMode.single)
                 const TextSpan(text: " sesiones según tu selección.\n\n"),
                 
              if (_selectedMode == ClassEditMode.single)
                 const TextSpan(text: "solo esta sesión.\n\n"),
                 
              const TextSpan(text: "Esta acción no se puede deshacer."),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Volver")),
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
    FocusManager.instance.primaryFocus?.unfocus();

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
       } else if (state is! AdminLoading && state is! AdminInitial) {
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

    // Edición masiva
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
          content: const Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 16),
              children: [
                TextSpan(text: "Estás a punto de modificar "),
                TextSpan(text: "MÚLTIPLES", style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: " clases.\n\n¿Confirmar cambios?"),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Volver")),
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
    } 
    // 2. Caso Solo Esta (Limpio y sin negritas forzadas)
    else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Confirmar Edición", style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
            "Se modificarán los datos de esta única sesión.\n\n¿Deseas guardar?",
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Volver")),
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
              child: const Text("Guardar"),
            ),
          ],
        ),
      );
    }
  }
}