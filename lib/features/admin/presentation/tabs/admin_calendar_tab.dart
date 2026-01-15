import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/horizontal_calendar.dart';
import '../../../schedule/data/schedule_repository.dart';
import '../../../schedule/domain/models/class_model.dart';
import '../cubit/admin_cubit.dart';
import '../cubit/admin_state.dart';
import '../widgets/admin_class_card.dart';
import '../widgets/edit_class_dialog.dart';

class AdminCalendarTab extends StatefulWidget {
  const AdminCalendarTab({super.key});

  @override
  State<AdminCalendarTab> createState() => _AdminCalendarTabState();
}

class _AdminCalendarTabState extends State<AdminCalendarTab> {
  DateTime _selectedDate = DateTime.now();
  List<ClassModel> _dayClasses = [];
  bool _isLoadingClasses = false;

  @override
  void initState() {
    super.initState();
    _fetchClassesForDate(_selectedDate);
  }

  // carga clases manualmente desde el repositorio
  Future<void> _fetchClassesForDate(DateTime date) async {
    setState(() => _isLoadingClasses = true);
    try {
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
      
      final classes = await context.read<ScheduleRepository>().getClasses(fromDate: start, toDate: end);
      
      if (mounted) {
        setState(() {
          _dayClasses = classes;
          _isLoadingClasses = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingClasses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // escucha cambios del cubit pa refrescar despues de editar
    return BlocListener<AdminCubit, AdminState>(
      listener: (context, state) {
        if (state is AdminOperationSuccess) {
           _fetchClassesForDate(_selectedDate);
        }
      },
      child: Column(
        children: [
          HorizontalCalendar(
            selectedDate: _selectedDate,
            daysCount: 15,
            onDateSelected: (date) {
              setState(() => _selectedDate = date);
              _fetchClassesForDate(date);
            },
          ),
          
          const SizedBox(height: 10),
          
          // lista de clases del dia
          Expanded(
            child: _isLoadingClasses 
                ? const Center(child: CircularProgressIndicator(color: Colors.red))
                : _dayClasses.isEmpty 
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: _dayClasses.length,
                        padding: const EdgeInsets.only(bottom: 80),
                        itemBuilder: (context, index) {
                          final cls = _dayClasses[index];
                          return AdminClassCard(
                            classModel: cls,
                            onTap: () => _showEditDialog(cls),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 50, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 10),
          Text(
            "No hay clases programadas",
            style: TextStyle(color: Colors.grey.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }

  // abre dialogo de edicion
  void _showEditDialog(ClassModel cls) {
    final state = context.read<AdminCubit>().state;
    if (state is AdminLoadedData) {
      showDialog(
        context: context,
        builder: (_) => BlocProvider.value(
          value: context.read<AdminCubit>(),
          child: EditClassDialog(
            classModel: cls,
            instructors: state.instructors,
          ),
        ),
      );
    }
  }
}