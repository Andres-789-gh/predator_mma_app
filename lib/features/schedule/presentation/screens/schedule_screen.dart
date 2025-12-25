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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);

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
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Horarios', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: bgColor, 
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // selector de fechas
          _buildTimelineCalendar(isDark),

          // lista de clases
          Expanded(
            child: BlocConsumer<ScheduleCubit, ScheduleState>(
              listener: (context, state) {
                if (state is ScheduleOperationSuccess) {
                  context.read<AuthCubit>().checkAuthStatus(); 

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              state.message, 
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
                if (state is ScheduleError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              state.message, 
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)
                            )
                          ),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state is ScheduleLoading) {
                  return const Center(child: CircularProgressIndicator(color: Colors.red));
                }

                if (state is ScheduleLoaded || state is ScheduleOperationSuccess) {
                  final items = (state is ScheduleLoaded) 
                      ? state.items 
                      : (state as ScheduleOperationSuccess).items;
                  
                  final processingId = (state is ScheduleLoaded) ? state.processingId : null;
                  final isGlobalProcessing = processingId != null;

                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, size: 60, color: Colors.grey.withValues(alpha: 0.5)),
                          const SizedBox(height: 10),
                          Text(
                            'No hay clases para este día.',
                            style: TextStyle(color: Colors.grey.withValues(alpha: 0.8), fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 10, bottom: 20),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isCardLoading = processingId == item.classModel.classId;
                      final canInteract = !isGlobalProcessing;

                      return ClassCard(
                        classModel: item.classModel,
                        status: item.status,
                        isLoading: isCardLoading,
                        onActionPressed: canInteract 
                            ? _getActionCallback(
                                context, item.status, item.classModel.classId, user
                              )
                            : null,
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
    UserModel user
  ) {
    if (status == ClassStatus.blockedByPlan) return null;

    final start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final end = start.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));

    if (status == ClassStatus.reserved || status == ClassStatus.waitlist) {
      return () {
        _showConfirmationDialog(
          context, 
          title: '¿Cancelar Reserva?', 
          content: 'Si cancelas, liberarás tu cupo.',
          isDestructive: true,
          onConfirm: () {
             context.read<ScheduleCubit>().cancelClass(
              classId: classId, 
              user: user, 
              currentFromDate: start, 
              currentToDate: end
            );
          }
        );
      };
    } 
    else {
      return () {
        if (!user.isWaiverSigned) {
          _showWaiverDialog(context);
          return;
        }

        _showConfirmationDialog(
          context,
          title: 'Confirmar Reserva',
          content: status == ClassStatus.availableWithTicket 
              ? '¿Usar ingreso extra para reservar esta clase?' 
              : '¿Deseas reservar tu cupo para esta clase?',
          isDestructive: false,
          onConfirm: () {
            context.read<ScheduleCubit>().reserveClass(
              classId: classId, 
              user: user, 
              currentFromDate: start, 
              currentToDate: end
            );
          }
        );
      };
    }
  }

  void _showConfirmationDialog(BuildContext context, {
    required String title, 
    required String content, 
    required VoidCallback onConfirm,
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        content: Text(content, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Volver', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: Text(isDestructive ? 'Sí, Cancelar' : 'Confirmar'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCalendar(bool isDark) {
    final selectedColor = Colors.red;
    final unselectedTextColor = isDark ? Colors.white70 : Colors.black54;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    final monthFormat = DateFormat('MMMM yyyy', 'es'); 

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: Text(
              toBeginningOfSentenceCase(monthFormat.format(_selectedDate)) ?? '',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87
              ),
            ),
          ),
          const SizedBox(height: 10),
          
          SizedBox(
            height: 85, 
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: 8,
              itemBuilder: (context, index) {
                final date = DateTime.now().add(Duration(days: index));
                
                final isSelected = date.day == _selectedDate.day && 
                                   date.month == _selectedDate.month &&
                                   date.year == _selectedDate.year;
                
                final dayName = DateFormat('E', 'es').format(date).toUpperCase().replaceAll('.', ''); 
                final dayNumber = date.day.toString();

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                    });
                    _loadClassesForDate(date);
                  },
                  child: Container(
                    width: 60,
                    margin: EdgeInsets.only(
                      left: index == 0 ? 20 : 5, 
                      right: index == 7 ? 20 : 5,
                      top: 5, bottom: 5
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? selectedColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected ? null : Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayName,
                          style: TextStyle(
                            color: isSelected ? Colors.white : unselectedTextColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dayNumber,
                          style: TextStyle(
                            color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (index == 0 && !isSelected) ...[
                           const SizedBox(height: 4),
                           CircleAvatar(radius: 2, backgroundColor: selectedColor),
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showWaiverDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('Acción Requerida'),
          ],
        ),
        content: const Text(
          'No puedes reservar clases sin haber firmado la exoneración de responsabilidad legal.\n\nPor favor, ve al Inicio y fírmala.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Firmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}