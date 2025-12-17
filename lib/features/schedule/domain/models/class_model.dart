import 'package:cloud_firestore/cloud_firestore.dart';

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

  // identificador para edicion masiva
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

  factory ClassModel.fromMap(Map<String, dynamic> map, String docId) {
    return ClassModel(
      classId: docId,
      startTime: (map['start_time'] as Timestamp).toDate(),
      endTime: (map['end_time'] as Timestamp).toDate(),
      classType: map['type'] ?? 'General',
      coachId: map['coach_id'] ?? '',
      coachName: map['coach_name'] ?? 'Instructor',
      maxCapacity: map['max_capacity'] ?? 12, // 12 por si es null
      attendees: List<String>.from(map['attendees'] ?? []),
      waitlist: List<String>.from(map['waitlist'] ?? []),
      isCancelled: map['is_cancelled'] ?? false,
      recurrenceId: map['recurrence_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'start_time': Timestamp.fromDate(startTime),
      'end_time': Timestamp.fromDate(endTime),
      'type': classType,
      'coach_id': coachId,
      'coach_name': coachName,
      'max_capacity': maxCapacity,
      'attendees': attendees,
      'waitlist': waitlist,
      'is_cancelled': isCancelled,
      'recurrence_id': recurrenceId,
    };
  }
}