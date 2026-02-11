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
                    color: Theme.of(
                      context,
                    ).colorScheme.primary,
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
                onPressed: () => _showRequestConfirmation(context),
                icon: const Icon(Icons.touch_app),
                label: const Text("SOLICITAR PLAN"),
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
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: Colors.grey[800])),
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

  void _showRequestConfirmation(BuildContext parentContext) {
    final userState = parentContext.read<AuthCubit>().state;
    if (userState is! AuthAuthenticated) return;

    final user = userState.user;

    showDialog(
      context: parentContext,
      builder: (ctx) => AlertDialog(
        title: Text("Solicitar ${plan.name}"),
        content: const Text(
          "¿Deseas adquirir este plan?\n\n"
          "Una vez aprobada la solicitud, se asignará el plan.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
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
                    SnackBar(
                      content: Text("Error: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text("Confirmar Solicitud"),
          ),
        ],
      ),
    );
  }
}
