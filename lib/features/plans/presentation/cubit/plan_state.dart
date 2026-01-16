import 'package:equatable/equatable.dart';
import '../../domain/models/plan_model.dart';

abstract class PlanState extends Equatable {
  const PlanState();

  @override
  List<Object?> get props => [];
}

// Estado inicial
class PlanInitial extends PlanState {
  const PlanInitial();
}

// Spinner
class PlanLoading extends PlanState {
  const PlanLoading();
}

// Lista cargada exitosamente
class PlanLoaded extends PlanState {
  final List<PlanModel> plans;
  const PlanLoaded(this.plans);

  @override
  List<Object?> get props => [plans];
}

// Error
class PlanError extends PlanState {
  final String message;
  const PlanError(this.message);

  @override
  List<Object?> get props => [message];
}