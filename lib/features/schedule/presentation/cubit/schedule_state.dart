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
  
  final String? processingId; 

  ScheduleLoaded({
    required List<ScheduleItem> items,
    required this.selectedDate,
    this.processingId,
  }) : items = List.unmodifiable(items);

  ScheduleLoaded copyWith({
    List<ScheduleItem>? items,
    DateTime? selectedDate,
    String? processingId,
    bool clearProcessingId = false,
  }) {
    return ScheduleLoaded(
      items: items ?? this.items,
      selectedDate: selectedDate ?? this.selectedDate,
      processingId: clearProcessingId ? null : (processingId ?? this.processingId),
    );
  }

  @override
  List<Object?> get props => [items, selectedDate, processingId];
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