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
  final Map<String, String> attendeePlans;
  final Map<String, String> waitlistPlans;

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
    this.attendeePlans = const {},
    this.waitlistPlans = const {},
  }) : attendees = List.unmodifiable(attendees),
       waitlist = List.unmodifiable(waitlist) {
    if (endTime.isBefore(startTime)) {
      throw ArgumentError('Error: La clase termina antes de empezar.');
    }
    if (maxCapacity <= 0) {
      throw ArgumentError('Error: La capacidad debe ser mayor a 0.');
    }
  }

  // reglas negocio
  bool get isFull => attendees.length >= maxCapacity;
  int get availableSlots => maxCapacity - attendees.length;
  bool get hasFinished => DateTime.now().isAfter(endTime);
  bool get hasValidDuration => endTime.isAfter(startTime);
  bool get canBeModified => DateTime.now().isBefore(endTime);

  bool isUserConfirmed(String userId) => attendees.contains(userId);
  bool isUserOnWaitlist(String userId) => waitlist.contains(userId);

  BookingStatus getUserBookingStatus(String userId) {
    if (isUserConfirmed(userId)) return BookingStatus.confirmed;
    if (isUserOnWaitlist(userId)) return BookingStatus.waitlist;
    return BookingStatus.none;
  }

  bool get canReserveNow {
    final now = DateTime.now();
    if (isCancelled || now.isAfter(startTime)) return false;

    final today = DateTime(now.year, now.month, now.day);
    final classDate = DateTime(startTime.year, startTime.month, startTime.day);
    final daysDifference = classDate.difference(today).inDays;

    if (daysDifference > 1) return false;

    final isSpecial =
        classType.toLowerCase().contains('virtual') ||
        classType.toLowerCase().contains('personalizada');

    if (isSpecial && daysDifference == 0) return false;

    final isMorningClass = startTime.hour < 12;
    DateTime deadline;

    if (isSpecial || isMorningClass) {
      final dayBefore = startTime.subtract(const Duration(days: 1));
      deadline = DateTime(
        dayBefore.year,
        dayBefore.month,
        dayBefore.day,
        23,
        59,
        59,
      );
    } else {
      deadline = DateTime(
        startTime.year,
        startTime.month,
        startTime.day,
        12,
        0,
        0,
      );
    }

    return now.isBefore(deadline);
  }

  bool get canCancelNow => DateTime.now().isBefore(startTime);

  String? getPlanUsedByUser(String userId) {
    if (attendeePlans.containsKey(userId)) return attendeePlans[userId];
    if (waitlistPlans.containsKey(userId)) return waitlistPlans[userId];
    return null;
  }

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
    Map<String, String>? attendeePlans,
    Map<String, String>? waitlistPlans,
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
      attendees: attendees != null
          ? List<String>.from(attendees)
          : this.attendees,
      waitlist: waitlist != null ? List<String>.from(waitlist) : this.waitlist,
      isCancelled: isCancelled ?? this.isCancelled,
      recurrenceId: clearRecurrenceId
          ? null
          : (recurrenceId ?? this.recurrenceId),
      attendeePlans: attendeePlans ?? this.attendeePlans,
      waitlistPlans: waitlistPlans ?? this.waitlistPlans,
    );
  }
}
