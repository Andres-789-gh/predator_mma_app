import 'package:equatable/equatable.dart';
import '../../../../core/constants/enums.dart';
import '../../domain/models/class_model.dart';

class ScheduleItem extends Equatable {
  final ClassModel classModel;
  final ClassStatus status;

  const ScheduleItem({
    required this.classModel,
    required this.status,
  });

  @override
  List<Object?> get props => [classModel, status];
}