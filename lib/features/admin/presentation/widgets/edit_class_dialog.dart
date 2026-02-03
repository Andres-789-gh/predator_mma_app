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
  bool _isSaving = false;

  String? _selectedTypeId;
  ClassEditMode _selectedMode = ClassEditMode.single;
  late bool _isCancelled;

  @override
  void initState() {
    super.initState();
    try {
      _selectedCoach = widget.instructors.firstWhere(
        (u) => u.userId == widget.classModel.coachId,
      );
    } catch (_) {
      _selectedCoach = widget.instructors.first;
    }
    _capacityController = TextEditingController(
      text: widget.classModel.maxCapacity.toString(),
    );
    _startTime = TimeOfDay.fromDateTime(widget.classModel.startTime);
    final totalMinutes = widget.classModel.endTime
        .difference(widget.classModel.startTime)
        .inMinutes;
    final hrs = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;

    _hoursController = TextEditingController(text: hrs.toString());
    _minutesController = TextEditingController(
      text: mins.toString().padLeft(2, '0'),
    );

    _selectedTypeId = widget.classModel.classTypeId;
    _isCancelled = widget.classModel.isCancelled;
  }

  @override
  void dispose() {
    _capacityController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  ClassModel? _buildUpdatedModel() {
    final cap = int.tryParse(_capacityController.text);
    if (cap == null || cap <= 0) return null;

    final hrs = int.tryParse(_hoursController.text) ?? 0;
    final mins = int.tryParse(_minutesController.text) ?? 0;
    final totalDuration = (hrs * 60) + mins;
    if (totalDuration <= 0) return null;

    String typeName = widget.classModel.classType;
    final state = context.read<AdminCubit>().state;

    if (_selectedTypeId != null &&
        _selectedTypeId != widget.classModel.classTypeId) {
      List<ClassTypeModel> types = [];
      if (state is AdminLoadedData) {
        types = state.classTypes;
      } else if (state is AdminConflictDetected) {
        types = state.originalData.classTypes;
      }

      if (types.isNotEmpty) {
        try {
          typeName = types.firstWhere((t) => t.id == _selectedTypeId).name;
        } catch (_) {}
      }
    }

    final currentDay = widget.classModel.startTime;
    final newStart = DateTime(
      currentDay.year,
      currentDay.month,
      currentDay.day,
      _startTime.hour,
      _startTime.minute,
    );
    final newEnd = newStart.add(Duration(minutes: totalDuration));

    return widget.classModel.copyWith(
      coachId: _selectedCoach.userId,
      coachName: "${_selectedCoach.firstName} ${_selectedCoach.lastName}",
      maxCapacity: cap,
      classTypeId: _selectedTypeId,
      classType: typeName,
      startTime: newStart,
      endTime: newEnd,
      isCancelled: _isCancelled,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AdminCubit>().state;
    List<ClassTypeModel> classTypes = [];

    if (state is AdminLoadedData) {
      classTypes = state.classTypes;
    } else if (state is AdminConflictDetected) {
      classTypes = state.originalData.classTypes;
    } else if (state is! AdminLoading && state is! AdminInitial) {
      try {
        classTypes = (state as dynamic).classTypes ?? [];
      } catch (_) {}
    }

    if (classTypes.isNotEmpty && _selectedTypeId != null) {
      if (!classTypes.any((t) => t.id == _selectedTypeId)) {
        _selectedTypeId = null;
      }
    }

    final hrs = int.tryParse(_hoursController.text) ?? 0;
    final mins = int.tryParse(_minutesController.text) ?? 0;
    final durationMin = (hrs * 60) + mins;

    final startDt = DateTime(2024, 1, 1, _startTime.hour, _startTime.minute);
    final endDt = startDt.add(Duration(minutes: durationMin));
    final timeStr =
        "${DateFormat('h:mm a').format(startDt)} - ${DateFormat('h:mm a').format(endDt)}";
    final isHistory = widget.classModel.endTime.isBefore(DateTime.now());

    final bool timeLocked = isHistory || _selectedMode == ClassEditMode.allType;

    return BlocListener<AdminCubit, AdminState>(
      listener: (context, state) {
        if (state is AdminOperationSuccess) {
          Navigator.pop(context);
        } else if (state is AdminError) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        } else if (state is AdminConflictDetected) {
          setState(() => _isSaving = false);
          _showConflictDialog(context, state);
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AlertDialog(
              scrollable: true,
              title: _buildTitle(context, timeStr, isHistory),
              content: _buildForm(context, classTypes, isHistory, timeLocked),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              actions: [
                if (isHistory)
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cerrar"),
                    ),
                  )
                else
                  Column(
                    children: [
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (_selectedMode == ClassEditMode.single) ...[
                            TextButton(
                              onPressed: () => _handleCancelOrEnable(context),
                              child: Text(
                                _isCancelled ? "Habilitar" : "Cancelar Clase",
                                style: TextStyle(
                                  color: _isCancelled
                                      ? Colors.blue
                                      : Colors.red,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          TextButton(
                            onPressed: _confirmDelete,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text("Eliminar"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                            ),
                            child: const Text("Cancelar"),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _isSaving ? null : _submitEdit,
                            child: const Text("Guardar"),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),

            if (_isSaving)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: const AbsorbPointer(
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context, String timeStr, bool isHistory) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Editar Clase: ${widget.classModel.classType}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            timeStr,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
            ),
          ),
        ),
        if (isHistory)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              "HISTORIAL - SOLO LECTURA",
              style: TextStyle(
                fontSize: 10,
                color: Colors.amber,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildForm(
    BuildContext context,
    List<ClassTypeModel> classTypes,
    bool isHistory,
    bool timeLocked,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (classTypes.isNotEmpty)
          InputDecorator(
            decoration: InputDecoration(
              labelText: "Clase",
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              enabled: !isHistory,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedTypeId,
                isExpanded: true,
                hint: const Text("Seleccionar clase"),
                items: classTypes
                    .map(
                      (t) => DropdownMenuItem(value: t.id, child: Text(t.name)),
                    )
                    .toList(),
                onChanged: isHistory
                    ? null
                    : (v) => setState(() => _selectedTypeId = v),
              ),
            ),
          ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: InkWell(
                onTap: timeLocked ? null : _pickTime,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: "Inicio",
                    border: const OutlineInputBorder(),
                    enabled: !timeLocked,
                  ),
                  child: Text(
                    _startTime.format(context),
                    style: TextStyle(color: timeLocked ? Colors.grey : null),
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
                decoration: const InputDecoration(
                  labelText: "Hrs",
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                enabled: !timeLocked,
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _minutesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Min",
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                enabled: !timeLocked,
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: "Profesor",
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  enabled: !isHistory,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<UserModel>(
                    value: _selectedCoach,
                    isExpanded: true,
                    items: widget.instructors
                        .map(
                          (u) => DropdownMenuItem(
                            value: u,
                            child: Text(
                              "${u.firstName} ${u.lastName}",
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: isHistory
                        ? null
                        : (val) {
                            if (val != null)
                              setState(() => _selectedCoach = val);
                          },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Cupo",
                  border: OutlineInputBorder(),
                ),
                enabled: !isHistory,
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
        if (!isHistory) ...[
          const Divider(),
          const Text("Alcance:", style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              _buildScopeOption(ClassEditMode.single, "Solo esta", Icons.event),
              const SizedBox(width: 8),
              _buildScopeOption(ClassEditMode.similar, "Similares", Icons.copy),
            ],
          ),
        ] else ...[
          const Padding(
            padding: EdgeInsets.only(top: 10, bottom: 8),
            child: Text(
              "Clase finalizada (No editable)",
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildScopeOption(ClassEditMode mode, String label, IconData icon) {
    final isSelected = _selectedMode == mode;
    final color = Colors.blue;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMode = mode),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.1)
                : Colors.transparent,
            border: Border.all(
              color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
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
                  color: isSelected ? color : Colors.grey[700],
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
    final bool isBulk = _selectedMode != ClassEditMode.single;
    final String title = isBulk ? "Eliminación Masiva" : "¿Eliminar Clase?";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 16),
            children: [
              const TextSpan(text: "Estás a punto de eliminar "),
              if (isBulk) ...[
                const TextSpan(
                  text: "MÚLTIPLES",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: " clases.\n\n"),
              ] else
                const TextSpan(text: "esta clase.\n\n"),
                
              const TextSpan(text: "Esta acción no se puede deshacer."),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Volver"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _executeDelete();
            },
            child: const Text("Sí, Eliminar"),
          ),
        ],
      ),
    );
  }

  void _executeDelete() {
    setState(() => _isSaving = true);
    context.read<AdminCubit>().deleteClass(
      classModel: widget.classModel,
      mode: _selectedMode,
    );
  }

  void _submitEdit() {
    if (_isSaving) return;

    FocusManager.instance.primaryFocus?.unfocus();

    final updated = _buildUpdatedModel();
    if (updated == null) return;

    final bool isBulk = _selectedMode != ClassEditMode.single;
    
    final String titleText = isBulk ? "Cambio Masivo" : "¿Guardar Cambios?";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: isBulk 
            ? Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange),
                  const SizedBox(width: 10),
                  Text(titleText),
                ],
              )
            : Text(titleText), 
            
        content: isBulk 
            ? Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 16),
                  children: const [
                    TextSpan(text: "Estás a punto de modificar "),
                    TextSpan(
                      text: "MÚLTIPLES", 
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: " clases.\n\n¿Confirmar cambios?"),
                  ],
                ),
              )
            : const Text("¿Estás seguro de guardar los cambios en esta clase?"),
            
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Volver"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _executeSave(updated);
            },
            child: const Text("Confirmar"),
          ),
        ],
      ),
    );
  }

  void _executeSave(ClassModel updated) {
    setState(() => _isSaving = true);
    context.read<AdminCubit>().editClass(
      originalClass: widget.classModel,
      updatedClass: updated,
      mode: _selectedMode,
    );
  }

  void _handleCancelOrEnable(BuildContext ctx) {
    final bool newStatus = !_isCancelled;
    final String action = newStatus ? "Cancelar" : "Habilitar";

    showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        title: Text("¿$action esta clase?"),
        content: Text(
          newStatus
              ? "No se podrá reservar esta clase mientras esté cancelada."
              : "La clase volverá a estar disponible para reservas.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Volver"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: newStatus ? Colors.red : Colors.blue,
            ),
            onPressed: () {
              Navigator.pop(c);
              final updated = widget.classModel.copyWith(
                isCancelled: newStatus,
              );
              _executeSave(updated);
            },
            child: Text("Sí, $action"),
          ),
        ],
      ),
    );
  }

  void _showConflictDialog(BuildContext context, AdminConflictDetected state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Conflicto de Horario"),
        content: Text("Choque con:\n${state.conflictMessage}\n\n¿Reemplazar?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isSaving = false);
              context.read<AdminCubit>().loadFormData(silent: true);
            },
            child: const Text("Cancelar"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              Navigator.pop(ctx);
              final updated = _buildUpdatedModel();
              if (updated != null) {
                setState(() => _isSaving = true);
                context.read<AdminCubit>().editClass(
                  originalClass: widget.classModel,
                  updatedClass: updated,
                  mode: _selectedMode,
                  force: true,
                );
              }
            },
            child: const Text("Reemplazar"),
          ),
        ],
      ),
    );
  }
}
