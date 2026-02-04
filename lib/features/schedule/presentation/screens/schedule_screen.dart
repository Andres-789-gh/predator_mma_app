import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/enums.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../auth/domain/models/user_model.dart';
import '../cubit/schedule_cubit.dart';
import '../cubit/schedule_state.dart';
import '../widgets/class_card.dart';
import '../../../../core/widgets/horizontal_calendar.dart';

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
      final end = start
          .add(const Duration(days: 1))
          .subtract(const Duration(seconds: 1));

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
        body: Center(
          child: Text('Error: Usuario no identificado o sesión cerrada'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          'Horarios',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: bgColor,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, authState) {
          if (authState is AuthAuthenticated) {
            final start = DateTime(
              _selectedDate.year,
              _selectedDate.month,
              _selectedDate.day,
            );
            final end = start
                .add(const Duration(days: 1))
                .subtract(const Duration(seconds: 1));

            context.read<ScheduleCubit>().loadSchedule(
              start,
              end,
              authState.user,
            );
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // widget fechas
            HorizontalCalendar(
              selectedDate: _selectedDate,
              onDateSelected: (date) {
                setState(() {
                  _selectedDate = date;
                });
                _loadClassesForDate(date);
              },
            ),

            // lista de clases
            Expanded(
              child: BlocConsumer<ScheduleCubit, ScheduleState>(
                listener: (context, state) {
                  if (state is ScheduleOperationSuccess) {
                    context.read<AuthCubit>().refreshUser();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                state.message,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                  if (state is ScheduleError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                state.message,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                },
                builder: (context, state) {
                  if (state is ScheduleLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.red),
                    );
                  }

                  if (state is ScheduleLoaded ||
                      state is ScheduleOperationSuccess) {
                    final items = (state is ScheduleLoaded)
                        ? state.items
                        : (state as ScheduleOperationSuccess).items;

                    final processingId = (state is ScheduleLoaded)
                        ? state.processingId
                        : null;
                    final isGlobalProcessing = processingId != null;

                    if (items.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_busy,
                              size: 60,
                              color: Colors.grey.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No hay clases para este día.',
                              style: TextStyle(
                                color: Colors.grey.withValues(alpha: 0.8),
                                fontSize: 16,
                              ),
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
                        final isCardLoading =
                            processingId == item.classModel.classId;
                        final canInteract = !isGlobalProcessing;

                        return ClassCard(
                          classModel: item.classModel,
                          status: item.status,
                          isLoading: isCardLoading,
                          onActionPressed: canInteract
                              ? _getActionCallback(
                                  context,
                                  item.status,
                                  item.classModel.classId,
                                  user,
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
      ),
    );
  }

  VoidCallback? _getActionCallback(
    BuildContext context,
    ClassStatus status,
    String classId,
    UserModel user,
  ) {
    if (status == ClassStatus.blockedByPlan) return null;

    final start = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final end = start
        .add(const Duration(days: 1))
        .subtract(const Duration(seconds: 1));

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
              currentToDate: end,
            );
          },
        );
      };
    } else {
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
              currentToDate: end,
            );
          },
        );
      };
    }
  }

  void _showConfirmationDialog(
    BuildContext context, {
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
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          content,
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
        ),
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
            child: const Text(
              'Entendido',
              style: TextStyle(color: Colors.grey),
            ),
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
