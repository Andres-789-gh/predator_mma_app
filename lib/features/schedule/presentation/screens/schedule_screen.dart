import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart'; 
import '../../../../core/constants/enums.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart'; 
import '../../../auth/domain/models/user_model.dart';
import '../cubit/schedule_cubit.dart';
import '../cubit/schedule_state.dart';
import '../widgets/class_card.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClassesForDate(_selectedDate);
    });
  }

  void _loadClassesForDate(DateTime date) {
    final authState = context.read<AuthCubit>().state;
    if (authState is AuthAuthenticated) {
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
      
      context.read<ScheduleCubit>().loadSchedule(start, end, authState.user);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit cubit) {
      final state = cubit.state;
      return (state is AuthAuthenticated) ? state.user : null;
    });

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Error: Usuario no identificado o sesión cerrada')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Horarios')),
      body: Column(
        children: [
          _buildDateSelector(),
          Expanded(
            child: BlocConsumer<ScheduleCubit, ScheduleState>(
              listener: (context, state) {
                if (state is ScheduleOperationSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.message), backgroundColor: Colors.green),
                  );
                }
                if (state is ScheduleError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.message), backgroundColor: Colors.red),
                  );
                }
              },
              builder: (context, state) {
                if (state is ScheduleLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is ScheduleLoaded || state is ScheduleOperationSuccess) {
                  final items = (state is ScheduleLoaded) 
                      ? state.items 
                      : (state as ScheduleOperationSuccess).items;
                  
                  final isOpLoading = (state is ScheduleLoaded) ? state.isOperationLoading : false;

                  if (items.isEmpty) {
                    return const Center(child: Text('No hay clases programadas para hoy.'));
                  }

                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      
                      return ClassCard(
                        classModel: item.classModel,
                        status: item.status,
                        isLoading: isOpLoading,
                        onActionPressed: _getActionCallback(
                          context, item.status, item.classModel.classId, user, isOpLoading
                        ),
                      );
                    },
                  );
                }

                return const Center(child: Text('Selecciona una fecha'));
              },
            ),
          ),
        ],
      ),
    );
  }

  VoidCallback? _getActionCallback(
    BuildContext context, 
    ClassStatus status, 
    String classId, 
    UserModel user, 
    bool isLoading
  ) {
    if (isLoading) return null;
    if (status == ClassStatus.blockedByPlan) return null;

    final start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final end = start.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));

    if (status == ClassStatus.reserved) {
      return () => context.read<ScheduleCubit>().cancelClass(
        classId: classId, 
        user: user, 
        currentFromDate: start, 
        currentToDate: end
      );
    } else {
      return () => context.read<ScheduleCubit>().reserveClass(
        classId: classId, 
        user: user, 
        currentFromDate: start, 
        currentToDate: end
      );
    }
  }

  Widget _buildDateSelector() {
    return Container(
      height: 90,
      color: Colors.grey[100],
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7, 
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          final isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = date;
              });
              _loadClassesForDate(date);
            },
            child: Container(
              width: 60,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: isSelected ? null : Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}