class ClassModel {
  final String classId; 
  final DateTime startTime; // fecha y hora inicio de la clase
  final DateTime endTime; // fecha y hora finalizacion
  final String classType; // tipo de clase (texto abierto)
  
  // info del profesor
  final String coachId;
  final String coachName; // nombre guardado pa' lectura rapida
  
  // capacidad y aforo
  final int maxCapacity; // cupo maximo de personas x clase
  final List<String> attendees; // lista de usuario confirmado (id)
  final List<String> waitlist; // lista de espera (id)

  // estado de la clase
  final bool isCancelled;

  // identificador para edicion masiva:
  // agrupa clases recurrentes (ej: todas las de viernes 7:30 pm)
  final String? recurrenceId;

  const ClassModel({
    required this.classId,
    required this.startTime,
    required this.endTime,
    required this.classType,
    required this.coachId,
    required this.coachName,
    required this.maxCapacity,
    required this.attendees,
    required this.waitlist,
    this.isCancelled = false, // por defecto clase activa
    this.recurrenceId,
  });
}