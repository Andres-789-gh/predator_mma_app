import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/class_model.dart';
import '../../../../core/constants/enums.dart';

class ClassMapper {
  static ClassModel fromMap(Map<String, dynamic> map, String docId) {
    final startTs = map['start_time'];
    final endTs = map['end_time'];

    if (startTs == null || endTs == null) {
      throw Exception(
        'error critico: la clase $docId no tiene horarios definidos',
      );
    }

    if (startTs is! Timestamp || endTs is! Timestamp) {
      throw Exception(
        'error critico: formato de fecha invalido en clase $docId',
      );
    }

    final rawAttendees = map['attendees'];
    final safeAttendees = rawAttendees is List
        ? rawAttendees.whereType<String>().toList()
        : <String>[];

    final rawWaitlist = map['waitlist'];
    final safeWaitlist = rawWaitlist is List
        ? rawWaitlist.whereType<String>().toList()
        : <String>[];

    return ClassModel(
      classId: docId,
      startTime: startTs.toDate(),
      endTime: endTs.toDate(),
      classTypeId: map['class_type_id'] ?? '',
      classType: map['type'] ?? 'General',
      category: ClassCategory.values.firstWhere(
        (e) =>
            e.name.toLowerCase() ==
            (map['category'] ?? '').toString().trim().toLowerCase(),
        orElse: () => ClassCategory.combat,
      ),
      coachId: map['coach_id'] ?? '',
      coachName: map['coach_name'] ?? 'Instructor',
      maxCapacity: (map['max_capacity'] ?? 12).clamp(1, 100),
      attendees: safeAttendees,
      waitlist: safeWaitlist,
      isCancelled: map['is_cancelled'] ?? false,
      recurrenceId: map['recurrence_id'],
    );
  }

  static Map<String, dynamic> toMap(ClassModel model) {
    return {
      'start_time': Timestamp.fromDate(model.startTime),
      'end_time': Timestamp.fromDate(model.endTime),
      'class_type_id': model.classTypeId,
      'type': model.classType,
      'category': model.category.name,
      'coach_id': model.coachId,
      'coach_name': model.coachName,
      'max_capacity': model.maxCapacity,
      'attendees': model.attendees,
      'waitlist': model.waitlist,
      'is_cancelled': model.isCancelled,
      'recurrence_id': model.recurrenceId,
    };
  }
}
