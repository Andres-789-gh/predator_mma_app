class ClassModel {
  final String classId; 
  final DateTime startTime; 
  final DateTime endTime; 
  final String classType; 
  
  // info del profesor
  final String coachId;
  final String coachName; 
  
  final int maxCapacity; 
  
  // Listas blindadas
  final List<String> attendees; 
  final List<String> waitlist; 

  final bool isCancelled;

  // identificador para edicion masiva:
  // agrupa clases recurrentes (ej: todas las de viernes 7:30 pm)
  final String? recurrenceId;

  ClassModel({
    required this.classId,
    required this.startTime,
    required this.endTime,
    required this.classType,
    required this.coachId,
    required this.coachName,
    required this.maxCapacity,
    required List<String> attendees,
    required List<String> waitlist,
    this.isCancelled = false,
    this.recurrenceId,
  }) : 
    // convertir lists en inmutables
    attendees = List.unmodifiable(attendees),
    waitlist = List.unmodifiable(waitlist) {
    
    // Validaciones
    if (endTime.isBefore(startTime)) {
      throw ArgumentError('Error: La clase termina antes de empezar.');
    }
    
    if (maxCapacity <= 0) {
      throw ArgumentError('Error: La capacidad debe ser mayor a 0.');
    }
  }

  ClassModel copyWith({
    String? classId,
    DateTime? startTime,
    DateTime? endTime,
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
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      classType: classType ?? this.classType,
      coachId: coachId ?? this.coachId,
      coachName: coachName ?? this.coachName,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      
      // Si mandan nueva lista, la blinda. Si no, deja la vieja.
      attendees: attendees != null ? List<String>.from(attendees) : this.attendees,
      waitlist: waitlist != null ? List<String>.from(waitlist) : this.waitlist,
      
      isCancelled: isCancelled ?? this.isCancelled,
      recurrenceId: clearRecurrenceId ? null : (recurrenceId ?? this.recurrenceId),
    );
  }
}