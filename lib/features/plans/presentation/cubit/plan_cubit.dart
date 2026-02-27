import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/plan_repository.dart';
import '../../domain/models/plan_model.dart';
import 'plan_state.dart';

class PlanCubit extends Cubit<PlanState> {
  final PlanRepository _planRepository;

  PlanCubit(this._planRepository) : super(const PlanInitial());

  // obtiene catalogo
  Future<void> loadPlans() async {
    try {
      emit(const PlanLoading());
      final plans = await _planRepository.getActivePlans();
      if (isClosed) return;
      emit(PlanLoaded(plans));
    } catch (e) {
      if (isClosed) return;
      emit(PlanError('Error al cargar planes: $e'));
    }
  }

  // registra plan
  Future<void> createPlan(PlanModel plan) async {
    try {
      emit(const PlanLoading());

      await _planRepository.createPlan(plan);
      if (isClosed) return;

      await loadPlans();
    } catch (e) {
      if (isClosed) return;
      final cleanMessage = e.toString().replaceAll('Exception: ', '');
      emit(PlanError(cleanMessage));
    }
  }

  // modifica plan
  Future<void> updatePlan(PlanModel plan) async {
    try {
      if (plan.id.isEmpty) {
        throw Exception('No se puede actualizar un plan sin ID');
      }

      emit(const PlanLoading());

      await _planRepository.updatePlan(plan);
      if (isClosed) return;

      await loadPlans();
    } catch (e) {
      if (isClosed) return;
      final cleanMessage = e.toString().replaceAll('Exception: ', '');
      emit(PlanError(cleanMessage));
    }
  }

  // elimina plan
  Future<void> deletePlan(String planId) async {
    try {
      emit(const PlanLoading());
      await _planRepository.deletePlan(planId);
      if (isClosed) return;
      await loadPlans();
    } catch (e) {
      if (isClosed) return;
      emit(PlanError('Error al eliminar: $e'));
      await loadPlans();
    }
  }
}
