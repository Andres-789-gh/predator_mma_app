import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/plan_repository.dart';
import '../../domain/models/plan_model.dart';
import 'plan_state.dart';

class PlanCubit extends Cubit<PlanState> {
  final PlanRepository _planRepository;

  PlanCubit(this._planRepository) : super(const PlanInitial());

  // Cargar lista de planes
  Future<void> loadPlans() async {
    try {
      emit(const PlanLoading());
      final plans = await _planRepository.getActivePlans();
      emit(PlanLoaded(plans));
    } catch (e) {
      emit(PlanError('Error al cargar planes: $e'));
    }
  }

  Future<void> createPlan(PlanModel plan) async {
    try {
      emit(const PlanLoading());
      
      await _planRepository.createPlan(plan);
      
      await loadPlans(); 
    } catch (e) {
      final cleanMessage = e.toString().replaceAll('Exception: ', '');
      emit(PlanError(cleanMessage));
    }
  }

  Future<void> updatePlan(PlanModel plan) async {
    try {
      if (plan.id.isEmpty) {
        throw Exception('No se puede actualizar un plan sin ID');
      }

      emit(const PlanLoading());
      
      await _planRepository.updatePlan(plan);
      
      await loadPlans(); 
    } catch (e) {
      final cleanMessage = e.toString().replaceAll('Exception: ', '');
      emit(PlanError(cleanMessage));
    }
  }

  Future<void> deletePlan(String planId) async {
    try {
      emit(const PlanLoading());
      await _planRepository.deletePlan(planId);
      await loadPlans(); 
    } catch (e) {
      emit(PlanError('Error al eliminar: $e'));
      loadPlans();
    }
  }
}