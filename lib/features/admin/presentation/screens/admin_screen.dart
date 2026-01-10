import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../schedule/data/schedule_repository.dart';
import '../cubit/admin_cubit.dart';
import '../cubit/admin_state.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AdminCubit(
        authRepository: context.read<AuthRepository>(),
        scheduleRepository: context.read<ScheduleRepository>(),
      )..loadFormData(),
      child: const _AdminView(),
    );
  }
}

class _AdminView extends StatefulWidget {
  const _AdminView();

  @override
  State<_AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<_AdminView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _typeNameController = TextEditingController();
  final _typeDescController = TextEditingController();
  String? _selectedClassTypeId;
  String? _selectedInstructorId;
  final _capacityController = TextEditingController(); 
  final List<int> _selectedWeekDays = []; 
  final List<TimeSlot> _timeSlots = []; 
  TimeOfDay? _tempStartTime;
  final _tempHoursCtrl = TextEditingController(text: "1");
  final _tempMinCtrl = TextEditingController(text: "00");

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _typeNameController.dispose();
    _typeDescController.dispose();
    _capacityController.dispose();
    _tempHoursCtrl.dispose();
    _tempMinCtrl.dispose();
    super.dispose();
  }

  void _clearForms() {
    _typeNameController.clear();
    _typeDescController.clear();
    setState(() {
      _selectedClassTypeId = null;
      _selectedInstructorId = null;
      _capacityController.clear();
      _selectedWeekDays.clear();
      _timeSlots.clear();
      _tempStartTime = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Administración"), 
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.red,
          labelColor: Colors.red,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "Programar Horario"),
            Tab(text: "Nueva Clase"), 
          ],
        ),
      ),
      body: BlocConsumer<AdminCubit, AdminState>(
        listener: (context, state) {
          if (state is AdminOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.green));
            _clearForms();
          }
          if (state is AdminError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          }
          if (state is AdminConflictDetected) {
            _showConflictDialog(context, state);
          }
        },
        builder: (context, state) {
          if (state is AdminLoading) return const Center(child: CircularProgressIndicator(color: Colors.red));
          
          if (state is AdminLoadedData) {
            return GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(), 
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildScheduleTab(context, state),
                  _buildCreateTypeTab(context),
                ],
              ),
            );
          }
          return const Center(child: Text("Cargando..."));
        },
      ),
    );
  }

  Widget _buildScheduleTab(BuildContext context, AdminLoadedData state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Información General", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          
          DropdownButtonFormField<String>(
            value: _selectedClassTypeId,
            decoration: const InputDecoration(labelText: "Clase", border: OutlineInputBorder()),
            items: state.classTypes.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
            onChanged: (v) => setState(() => _selectedClassTypeId = v),
          ),
          const SizedBox(height: 10),
          
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _selectedInstructorId,
                  decoration: const InputDecoration(labelText: "Profesor", border: OutlineInputBorder()),
                  items: state.instructors.map((u) => DropdownMenuItem(value: u.userId, child: Text("${u.firstName} ${u.lastName}"))).toList(),
                  onChanged: (v) => setState(() => _selectedInstructorId = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _capacityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Cupo", hintText: "Ej: 20", border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 25),
          const Divider(),
          const SizedBox(height: 10),

          const Text("Días de clase", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: [
              _buildDayChip("L", 1),
              _buildDayChip("M", 2),
              _buildDayChip("M", 3),
              _buildDayChip("J", 4),
              _buildDayChip("V", 5),
              _buildDayChip("S", 6),
              _buildDayChip("D", 7),
            ],
          ),

          const SizedBox(height: 25),
          const Divider(),
          const SizedBox(height: 10),

          const Text("Horarios", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),

          if (_timeSlots.isNotEmpty)
            Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: _timeSlots.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final slot = entry.value;
                  
                  final dt = DateTime(2024, 1, 1, slot.time.hour, slot.time.minute);
                  final endDt = dt.add(Duration(minutes: slot.durationMinutes));
                  final startStr = DateFormat('h:mm a').format(dt);
                  final endStr = DateFormat('h:mm a').format(endDt);

                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.access_time, color: Colors.red),
                    title: Text("$startStr - $endStr", style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _timeSlots.removeAt(idx)),
                    ),
                  );
                }).toList(),
              ),
            ),
          
          const SizedBox(height: 20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: () async {
                    FocusManager.instance.primaryFocus?.unfocus();
                    
                    final t = await showTimePicker(
                      context: context, 
                      initialTime: const TimeOfDay(hour: 7, minute: 0)
                    );
                    await Future.delayed(const Duration(milliseconds: 100));
                    
                    if (context.mounted) {
                      FocusManager.instance.primaryFocus?.unfocus();
                    }

                    if (t != null) setState(() => _tempStartTime = t);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: "Inicio", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 15)),
                    child: Text(
                      _tempStartTime == null ? "--:--" : _tempStartTime!.format(context),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _tempHoursCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: "Hrs", border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: TextField(
                  controller: _tempMinCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: "Min", border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(backgroundColor: Colors.red),
                onPressed: _addTimeSlot,
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text("Define hora inicio y duración para agregar a la lista.", style: TextStyle(color: Colors.grey, fontSize: 12)),

          const SizedBox(height: 25),
          const Divider(),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Este horario se guardará como 'Recurrente'. El sistema generará automáticamente el calendario.",
                    style: TextStyle(fontSize: 13, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => _submit(state),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[800],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("GUARDAR HORARIO", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildCreateTypeTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Crear Nueva Clase", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          TextField(
            controller: _typeNameController, 
            decoration: const InputDecoration(labelText: "Nombre (Ej: Combate)", border: OutlineInputBorder())
          ),
          
          const SizedBox(height: 15),
          
          TextField(
            controller: _typeDescController, 
            maxLines: 2, 
            decoration: const InputDecoration(labelText: "Descripción (Opcional)", border: OutlineInputBorder())
          ),
          
          const SizedBox(height: 20),
          
          ElevatedButton(
            onPressed: () {
              if (_typeNameController.text.isEmpty) return;
              context.read<AdminCubit>().createClassType(_typeNameController.text.trim(), _typeDescController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
            child: const Text("GUARDAR"),
          )
        ],
      ),
    );
  }

  void _addTimeSlot() {
    if (_tempStartTime == null) return;
    
    FocusScope.of(context).unfocus(); 

    final hrs = int.tryParse(_tempHoursCtrl.text) ?? 0;
    final mins = int.tryParse(_tempMinCtrl.text) ?? 0;
    
    if (hrs == 0 && mins == 0) return; 

    final totalMinutes = (hrs * 60) + mins;

    setState(() {
      _timeSlots.add(TimeSlot(_tempStartTime!, totalMinutes));
      
      _timeSlots.sort((a, b) {
        final minA = a.time.hour * 60 + a.time.minute;
        final minB = b.time.hour * 60 + b.time.minute;
        return minA.compareTo(minB);
      });

      _tempStartTime = null; 
    });
  }

  Widget _buildDayChip(String label, int dayIndex) {
    final isSelected = _selectedWeekDays.contains(dayIndex);
    return FilterChip(
      label: Text(
        label, 
        style: TextStyle(
          color: isSelected ? Colors.red[900] : null, 
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
        )
      ),
      selected: isSelected,
      showCheckmark: false,
      onSelected: (bool selected) {
        setState(() {
          if (selected) {
            _selectedWeekDays.add(dayIndex);
          } else {
            _selectedWeekDays.remove(dayIndex);
          }
        });
      },
      selectedColor: Colors.red.withValues(alpha: 0.2),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      side: isSelected ? const BorderSide(color: Colors.red) : null,
    );
  }

  void _submit(AdminLoadedData state) {
    if (_selectedClassTypeId == null || _selectedInstructorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Falta Clase o Profesor")));
      return;
    }
    if (_selectedWeekDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Elige al menos un día")));
      return;
    }
    if (_timeSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Agrega al menos un horario (+)")));
      return;
    }

    final capacity = int.tryParse(_capacityController.text);
    if (capacity == null || capacity <= 0) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ingresa un cupo válido (mayor a 0)")));
       return;
    }

    final selectedType = state.classTypes.firstWhere((t) => t.id == _selectedClassTypeId);
    final selectedInstructor = state.instructors.firstWhere((u) => u.userId == _selectedInstructorId);
    
    context.read<AdminCubit>().projectSchedule(
      classType: selectedType,
      coach: selectedInstructor,
      capacity: capacity, 
      weekDays: _selectedWeekDays,
      timeSlots: _timeSlots,
      startDate: DateTime.now(),
    );
  }

  // Dialogo de conflicto
  void _showConflictDialog(BuildContext context, AdminConflictDetected state) {
    final timeFormat = DateFormat('h:mm a');
    final oldStart = timeFormat.format(state.conflictingClass.startTime);
    final oldEnd = timeFormat.format(state.conflictingClass.endTime);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Text("Choque de Horario"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Ya existe una clase en este horario:"),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Clase: ${state.conflictingClass.classType}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text("Profe: ${state.conflictingClass.coachName}"),
                  Text("Hora: $oldStart - $oldEnd"),
                ],
              ),
            ),
            const SizedBox(height: 15),
            const Text("¿Deseas eliminar la clase antigua y reemplazarla con la nueva?"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("No, cancelar"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx); 
              context.read<AdminCubit>().replaceConflictingClass(
                state.conflictingClass.classId, 
                state.newClass
              );
            },
            child: const Text("Sí, Reemplazar"),
          ),
        ],
      ),
    );
  }
}