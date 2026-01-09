class SchedulePatternModel {
  final String id;
  final String classTypeId;
  final String coachId;
  final int capacity;
  final List<int> weekDays;
  final List<Map<String, dynamic>> timeSlots;
  final bool active;

  SchedulePatternModel({
    required this.id,
    required this.classTypeId,
    required this.coachId,
    required this.capacity,
    required this.weekDays,
    required this.timeSlots,
    this.active = true,
  });
}