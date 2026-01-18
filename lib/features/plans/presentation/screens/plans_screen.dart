import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/plan_repository.dart';
import '../cubit/plan_cubit.dart';
import '../cubit/plan_state.dart';
import 'plan_form_screen.dart';
import '../../../../core/constants/enums.dart';
import 'package:intl/intl.dart';
import '../../domain/models/plan_model.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PlanCubit(PlanRepository())..loadPlans(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administrar Planes'),
        ),
        
        // Construye UI según el estado
        body: BlocBuilder<PlanCubit, PlanState>(
          builder: (context, state) {
            
            if (state is PlanLoading) {
              return const Center(child: CircularProgressIndicator());
            } 
            
            else if (state is PlanError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 10),
                    Text('Ocurrió un error:\n${state.message}', textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => context.read<PlanCubit>().loadPlans(),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            } 
            
            else if (state is PlanLoaded) {
              final plans = List<PlanModel>.from(state.plans);
              
              plans.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

              if (plans.isEmpty) {
                return const Center(
                  child: Text(
                    'No hay planes activos.\nCrea un plan usando el botón "+"',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              // Lista de Planes
              return ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: plans.length,
                itemBuilder: (context, index) {
                  final plan = plans[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(plan.name.substring(0, 1).toUpperCase()),
                      ),
                      title: Text(plan.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Builder(
                        builder: (context) {
                          final formatter = NumberFormat("#,###", "es_CO");
                          final priceStr = formatter.format(plan.price).replaceAll(',', '.');

                          final typeStr = plan.consumptionType == PlanConsumptionType.limitedDaily
                              ? 'Ingreso Diario'
                              : 'Ingreso Ilimitado';

                          return Text(
                            '$typeStr • \$ $priceStr', 
                            style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                          );
                        },
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('¿Eliminar Plan?'),
                              content: Text('Se eliminará el plan "${plan.name}".'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    context.read<PlanCubit>().deletePlan(plan.id);
                                  },
                                  child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      onTap: () {
                         debugPrint("Editar plan: ${plan.name}");
                      },
                    ),
                  );
                },
              );
            }
            
            return const SizedBox(); 
          },
        ),

        floatingActionButton: Builder(
          builder: (context) {
            return FloatingActionButton(
              child: const Icon(Icons.add),
              onPressed: () {
                 final planCubit = context.read<PlanCubit>();

                 Navigator.push(
                   context, 
                   MaterialPageRoute(
                     builder: (_) => BlocProvider.value(
                       value: planCubit, 
                       child: const PlanFormScreen(),
                     ),
                   ),
                 ).then((_) {
                   planCubit.loadPlans();
                 });
              },
            );
          },
        ),
      ),
    );
  }
}