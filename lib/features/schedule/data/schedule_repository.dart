import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/class_model.dart';
import 'mappers/class_mapper.dart';
import '../../../../core/constants/enums.dart';

class ScheduleRepository {
  final FirebaseFirestore _firestore;

  ScheduleRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // leer clases
  Future<List<ClassModel>> getClasses({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('classes')
          .where('start_time', isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate))
          .where('start_time', isLessThanOrEqualTo: Timestamp.fromDate(toDate))
          .orderBy('start_time') // ordenadas por hora
          .get();

      return snapshot.docs
          .map((doc) => ClassMapper.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('error al cargar horario: $e');
    }
  }

  // reservar cupo
  Future<BookingStatus> reserveClass({
    required String classId,
    required String userId,
  }) async {
    final classRef = _firestore.collection('classes').doc(classId);

    try {
      return await _firestore.runTransaction((transaction) async { 
        final snapshot = await transaction.get(classRef);

        if (!snapshot.exists) throw Exception('la clase ya no existe');

        final classModel = ClassMapper.fromMap(snapshot.data()!, snapshot.id);

        // Validaciones
        if (classModel.isCancelled) throw Exception('la clase ha sido cancelada');
        
        // Validar que no este duplicado (ni en lista, ni en espera)
        if (classModel.attendees.contains(userId)) {
          throw Exception('ya estas inscrito en esta clase');
        }
        if (classModel.waitlist.contains(userId)) {
          throw Exception('ya estas en lista de espera');
        }

        // Decision de si entra a clase o a espera
        if (classModel.attendees.length < classModel.maxCapacity) {
          // cupo -> confirmado
          transaction.update(classRef, {
            'attendees': FieldValue.arrayUnion([userId])
          });
          return BookingStatus.confirmed;
        } else {
          // lleno -> lista de espera
          transaction.update(classRef, {
            'waitlist': FieldValue.arrayUnion([userId])
          });
          return BookingStatus.waitlist;
        }
      });
    } catch (e) {
      throw Exception('$e');
    }
  }

  // cancelar reserva
  Future<void> cancelReservation({
    required String classId,
    required String userId,
  }) async {
    final classRef = _firestore.collection('classes').doc(classId);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(classRef);

        if (!snapshot.exists) throw Exception('la clase no existe');

        final classModel = ClassMapper.fromMap(snapshot.data()!, snapshot.id);

        // Validar si la clase ya paso o esta empezando justo ahora
        if (!classModel.startTime.isAfter(DateTime.now())) {
             throw Exception('no puedes cancelar una clase que ya paso o esta empezando');
        }

        // Identificar donde esta el usuario
        final bool isInAttendees = classModel.attendees.contains(userId);
        final bool isInWaitlist = classModel.waitlist.contains(userId);

        if (!isInAttendees && !isInWaitlist) {
          throw Exception('no estas inscrito en esta clase');
        }

        // lista de espera -> se sale y ya
        if (isInWaitlist) {
          transaction.update(classRef, {
            'waitlist': FieldValue.arrayRemove([userId])
          });
          return;
        }

        // confirmado para clase -> Sale y mira si alguien sube
        if (isInAttendees) {
          // 1ro saca al usuario
          transaction.update(classRef, {
            'attendees': FieldValue.arrayRemove([userId])
          });

          // Revisa si hay alguien esperando y si realmente libera un espacio matematico
          if (classModel.waitlist.isNotEmpty) {
            
            final nextUser = classModel.waitlist.first; // 1ro de la fila
            
            // Entra a clase, sale de espera
            transaction.update(classRef, {
              'attendees': FieldValue.arrayUnion([nextUser]),
              'waitlist': FieldValue.arrayRemove([nextUser])
            });
          }
        }
      });
    } catch (e) {
      throw Exception('error al cancelar reserva: $e');
    }
  }

  // crear clase (Admin)
  Future<void> createClass(ClassModel classModel) async {
    try {
      // mapper para convertir a mapa de firebase
      final docRef = _firestore.collection('classes').doc(); 
      
      await docRef.set(ClassMapper.toMap(classModel));
    } catch (e) {
      throw Exception('error creando clase: $e');
    }
  }
}