import '../../../../core/constants/enums.dart';

class ClassModel {
  final String classId;
  final ClassCategory category;
  final DateTime startTime;
  final DateTime endTime;
  final String classTypeId;
  final String classType;
  final String coachId;
  final String coachName;
  final int maxCapacity;
  final List<String> attendees;
  final List<String> waitlist;
  final bool isCancelled;
  final String? recurrenceId;

  ClassModel({
    required this.classId,
    required this.category,
    required this.startTime,
    required this.endTime,
    required this.classTypeId,
    required this.classType,
    required this.coachId,
    required this.coachName,
    required this.maxCapacity,
    required List<String> attendees,
    required List<String> waitlist,
    this.isCancelled = false,
    this.recurrenceId,
  }) : 
    attendees = List.unmodifiable(attendees),
    waitlist = List.unmodifiable(waitlist) {
    
    if (endTime.isBefore(startTime)) {
      throw ArgumentError('Error: La clase termina antes de empezar.');
    }
    
    if (maxCapacity <= 0) {
      throw ArgumentError('Error: La capacidad debe ser mayor a 0.');
    }
  }

  bool get isFull => attendees.length >= maxCapacity;
  int get availableSpots => maxCapacity - attendees.length;

  ClassModel copyWith({
    String? classId,
    ClassCategory? category, 
    DateTime? startTime,
    DateTime? endTime,
    String? classTypeId,
    String? classType,
    String? coachId,
    String? coachName,
    int? maxCapacity,
    List<String>? attendees,
    List<String>? waitlist,
    bool? isCancelled,
    String? recurrenceId,
    bool clearRecurrenceId = false,
  }) {
    return ClassModel(
      classId: classId ?? this.classId,
      category: category ?? this.category,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      classTypeId: classTypeId ?? this.classTypeId,
      classType: classType ?? this.classType,
      coachId: coachId ?? this.coachId,
      coachName: coachName ?? this.coachName,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      attendees: attendees != null ? List<String>.from(attendees) : this.attendees,
      waitlist: waitlist != null ? List<String>.from(waitlist) : this.waitlist,
      isCancelled: isCancelled ?? this.isCancelled,
      recurrenceId: clearRecurrenceId ? null : (recurrenceId ?? this.recurrenceId),
    );
  }
}