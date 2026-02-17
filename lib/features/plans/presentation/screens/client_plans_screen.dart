import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../domain/models/plan_model.dart';
import '../../presentation/cubit/plan_cubit.dart';
import '../../presentation/cubit/plan_state.dart';
import '../../../notifications/domain/usecases/request_plan_usecase.dart';
import '../../../../core/constants/enums.dart';

class ClientPlansScreen extends StatelessWidget {
  const ClientPlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<PlanCubit>()..loadPlans(),
      child: Scaffold(
        appBar: AppBar(title: const Text("Planes Disponibles")),
        body: BlocBuilder<PlanCubit, PlanState>(
          builder: (context, state) {
            if (state is PlanLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is PlanLoaded) {
              final activePlans = state.plans.where((p) => p.isActive).toList();
              if (activePlans.isEmpty) {
                return const Center(
                  child: Text("No hay planes disponibles por ahora."),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: activePlans.length,
                itemBuilder: (ctx, i) => _ClientPlanCard(plan: activePlans[i]),
              );
            } else if (state is PlanError) {
              return Center(child: Text(state.message));
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _ClientPlanCard extends StatelessWidget {
  final PlanModel plan;

  const _ClientPlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  currencyFormat.format(plan.price),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildPlanDetailRow(Icons.info_outline, _getConsumptionText()),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _showPlanDetails(context),
                icon: const Icon(Icons.info_outline),
                label: const Text("VER INFORMACIÓN"),
                style: FilledButton.styleFrom(backgroundColor: Colors.blueGrey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ),
      ],
    );
  }

  String _getConsumptionText() {
    if (plan.consumptionType == PlanConsumptionType.pack) {
      return "Tiquetera de ${plan.packClassesQuantity ?? 0} clases";
    }

    if (plan.consumptionType == PlanConsumptionType.unlimited) {
      return "Acceso Ilimitado";
    }

    // limitedDaily
    final limit = plan.dailyLimit ?? 1;
    return "$limit ${limit == 1 ? 'Clase Diaria' : 'Clases Diarias'}";
  }

  // Diálogo Detalles
  void _showPlanDetails(BuildContext parentContext) {
    showDialog(
      context: parentContext,
      builder: (ctx) {
        return AlertDialog(
          title: Text(plan.name, textAlign: TextAlign.center),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Detalles y Horarios:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                if (plan.scheduleRules.isEmpty)
                  const Text(
                    "Este plan no tiene restricciones horarias específicas.",
                  )
                else
                  ...plan.scheduleRules.map((rule) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Días
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _daysToString(rule.allowedDays),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Horas
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "${_timeToString(rule.startMinute)} - ${_timeToString(rule.endMinute)}",
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Categorías
                          if (rule.allowedCategories.isNotEmpty)
                            Row(
                              children: [
                                const Icon(
                                  Icons.sports_mma_outlined,
                                  size: 14,
                                  color: Colors.redAccent,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    rule.allowedCategories
                                        .map((c) => c.label)
                                        .join(", "),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                const SizedBox(height: 15),
                const Divider(),
                const SizedBox(height: 10),
                const Text(
                  "Al solicitar este plan, un administrador recibirá tu petición para activarlo.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cerrar"),
            ),
            FilledButton.icon(
              onPressed: () => _processRequest(parentContext, ctx),
              label: const Text("SOLICITAR PLAN"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _processRequest(
    BuildContext parentContext,
    BuildContext dialogContext,
  ) async {
    final userState = parentContext.read<AuthCubit>().state;
    if (userState is! AuthAuthenticated) return;

    final user = userState.user;

    Navigator.pop(dialogContext);

    try {
      await sl<RequestPlanUseCase>().execute(user: user, plan: plan);

      if (parentContext.mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          const SnackBar(
            content: Text("¡Solicitud enviada!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (parentContext.mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _daysToString(List<int> days) {
    const weekDays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final sortedDays = List<int>.from(days)..sort();

    if (sortedDays.length == 7) return 'Todos los días';

    return sortedDays.map((d) => weekDays[d - 1]).join(', ');
  }

  String _timeToString(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final period = h < 12 ? 'AM' : 'PM';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour:${m.toString().padLeft(2, '0')} $period';
  }
}
