import 'package:equatable/equatable.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../schedule/domain/models/class_type_model.dart';
import '../../../schedule/domain/models/class_model.dart';
import '../../../plans/domain/models/plan_model.dart';

abstract class AdminState extends Equatable {
  const AdminState();

  @override
  List<Object?> get props => [];
}

class AdminInitial extends AdminState {}

class AdminLoading extends AdminState {}

class AdminLoadedData extends AdminState {
  final List<UserModel> instructors;
  final List<ClassTypeModel> classTypes;

  const AdminLoadedData({required this.instructors, required this.classTypes});

  @override
  List<Object> get props => [instructors, classTypes];
}

class AdminOperationSuccess extends AdminState {
  final String message;
  const AdminOperationSuccess(this.message);

  @override
  List<Object> get props => [message];
}

class AdminError extends AdminState {
  final String message;
  const AdminError(this.message);

  @override
  List<Object> get props => [message];
}

class AdminConflictDetected extends AdminState {
  final ClassModel newClass;
  final List<ClassModel> conflictingClasses;
  final AdminLoadedData originalData;
  final String conflictMessage;

  const AdminConflictDetected({
    required this.newClass,
    required this.conflictingClasses,
    required this.originalData,
    required this.conflictMessage,
  });

  @override
  List<Object> get props => [
    newClass,
    conflictingClasses,
    originalData,
    conflictMessage,
  ];
}

class AdminUsersLoaded extends AdminState {
  final List<UserModel> users;
  final List<PlanModel> availablePlans;

  const AdminUsersLoaded({required this.users, required this.availablePlans});

  @override
  List<Object?> get props => [users, availablePlans];
}
