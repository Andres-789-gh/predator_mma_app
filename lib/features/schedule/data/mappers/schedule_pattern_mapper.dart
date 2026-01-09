import '../../domain/models/schedule_pattern_model.dart';

class SchedulePatternMapper {
  
  // de firebase a modelo
  static SchedulePatternModel fromMap(Map<String, dynamic> map, String docId) {
    return SchedulePatternModel(
      id: docId,
      classTypeId: map['class_type_id'] ?? '',
      coachId: map['coach_id'] ?? '',
      capacity: map['capacity'] ?? 20,
      weekDays: List<int>.from(map['week_days'] ?? []),
      timeSlots: (map['time_slots'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e))
          .toList() ?? [],
      active: map['active'] ?? true,
    );
  }

  // de modelo a firebase
  static Map<String, dynamic> toMap(SchedulePatternModel model) {
    return {
      'class_type_id': model.classTypeId,
      'coach_id': model.coachId,
      'capacity': model.capacity,
      'week_days': model.weekDays,
      'time_slots': model.timeSlots,
      'active': model.active,
    };
  }
}