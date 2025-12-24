import 'package:equatable/equatable.dart';
import '../models/schedule_item.dart';

abstract class ScheduleState extends Equatable {
  const ScheduleState();

  @override
  List<Object?> get props => [];
}

class ScheduleInitial extends ScheduleState {}

class ScheduleLoading extends ScheduleState {}

class ScheduleLoaded extends ScheduleState {
  final List<ScheduleItem> items;
  final DateTime selectedDate;
  final bool isOperationLoading;

  ScheduleLoaded({
    required List<ScheduleItem> items,
    required this.selectedDate,
    this.isOperationLoading = false,
  }) : items = List.unmodifiable(items);

  ScheduleLoaded copyWith({
    List<ScheduleItem>? items,
    DateTime? selectedDate,
    bool? isOperationLoading,
  }) {
    return ScheduleLoaded(
      items: items ?? this.items,
      selectedDate: selectedDate ?? this.selectedDate,
      isOperationLoading: isOperationLoading ?? this.isOperationLoading,
    );
  }

  @override
  List<Object?> get props => [items, selectedDate, isOperationLoading];
}

class ScheduleOperationSuccess extends ScheduleState {
  final String message;
  final List<ScheduleItem> items;

  ScheduleOperationSuccess({
    required this.message,
    required List<ScheduleItem> items,
  }) : items = List.unmodifiable(items);

  @override
  List<Object?> get props => [message, items];
}

class ScheduleError extends ScheduleState {
  final String message;

  const ScheduleError(this.message);

  @override
  List<Object?> get props => [message];
}