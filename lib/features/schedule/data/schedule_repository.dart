import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/class_model.dart';
import '../../auth/data/mappers/user_mapper.dart'; 
import '../../auth/data/mappers/access_exception_mapper.dart';
import 'mappers/class_mapper.dart';
import '../../../../core/constants/enums.dart';
import '../../auth/domain/models/user_model.dart';
import '../domain/schedule_logic.dart'; 
import '../domain/class_logic.dart'; 
import '../../auth/domain/models/access_exception_model.dart';
import '../domain/models/class_type_model.dart';
import 'mappers/class_type_mapper.dart';
import '../domain/models/schedule_pattern_model.dart';
import 'mappers/schedule_pattern_mapper.dart';

class ScheduleRepository {
  final FirebaseFirestore _firestore;

  ScheduleRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Lectura

  Future<List<ClassModel>> getClasses({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('classes')
          .where('start_time', isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate))
          .where('start_time', isLessThanOrEqualTo: Timestamp.fromDate(toDate))
          .orderBy('start_time')
          .get();

      return snapshot.docs
          .map((doc) => ClassMapper.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error al cargar horario: $e');
    }
  }

  Future<ClassModel?> checkConflict(ClassModel newClass) async {
    try {
      final startOfDay = DateTime(newClass.startTime.year, newClass.startTime.month, newClass.startTime.day);
      final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
      final existingClasses = await getClasses(fromDate: startOfDay, toDate: endOfDay);

      return ScheduleLogic.findConflict(newClass, existingClasses);
    } catch (e) {
      throw Exception('Error verificando conflictos: $e');
    }
  }

  ClassStatus getClassStatus(UserModel user, ClassModel classModel) {
    if (classModel.isUserConfirmed(user.userId) || classModel.isUserOnWaitlist(user.userId)) {
      return ClassStatus.reserved;
    }

    if (classModel.isFull) {
      return ClassStatus.full;
    }
    
    if (_doesPlanAllowClass(user, classModel)) {
      return ClassStatus.available;
    }

    // Validación Ticket Extra
    final hasValidTicket = user.accessExceptions.any(
      (exc) => _isValidException(exc, classModel, DateTime.now())
    );

    if (hasValidTicket) {
      return ClassStatus.availableWithTicket;
    }

    return ClassStatus.blockedByPlan;
  }

  // Escritura reservar

  Future<BookingStatus> reserveClass({
    required String classId,
    required String userId,
  }) async {
    final classRef = _firestore.collection('classes').doc(classId);
    final userRef = _firestore.collection('users').doc(userId);

    try {
      return await _firestore.runTransaction((transaction) async {
        final classSnapshot = await transaction.get(classRef);
        final userSnapshot = await transaction.get(userRef);

        if (!classSnapshot.exists) throw Exception('La clase ya no existe');
        if (!userSnapshot.exists) throw Exception('Usuario no encontrado');

        final classModel = ClassMapper.fromMap(classSnapshot.data()!, classSnapshot.id);
        final userModel = UserMapper.fromMap(userSnapshot.data()!, userSnapshot.id);
        final now = DateTime.now();

        if (!userModel.isWaiverSigned) throw Exception('Debes firmar la exoneración antes de reservar.');
        if (classModel.isCancelled) throw Exception('La clase ha sido cancelada');
        
        if (classModel.isUserConfirmed(userId)) throw Exception('Ya estás inscrito en esta clase');
        if (classModel.isUserOnWaitlist(userId)) throw Exception('Ya estás en lista de espera');
        
        if (classModel.hasFinished) throw Exception('La clase ya finalizó');

        if (userModel.activePlan != null && userModel.activePlan!.isPaused(now)) {
          throw Exception('Tu plan está pausado actualmente, no puedes reservar');
        }

        // Lógica de Reserva
        bool useException = false;
        String? exceptionIdToConsume;
        String planError = '';

        try {
          await _assertBasePlanAsync(userModel, classModel, now);
        } catch (e) {
          planError = e.toString().replaceAll('Exception: ', '');
          
          final validException = userModel.accessExceptions.firstWhere(
            (exc) => _isValidException(exc, classModel, now),
            orElse: () => throw Exception(planError),
          );

          useException = true;
          exceptionIdToConsume = validException.id;
        }

        // Consumo Ticket
        if (useException && exceptionIdToConsume != null) {
          final updatedExceptions = userModel.accessExceptions.map((exc) {
            if (exc.id == exceptionIdToConsume) {
              return exc.copyWith(quantity: exc.quantity - 1);
            }
            return exc;
          })
          .toList();

          transaction.update(userRef, {
            'access_exceptions': updatedExceptions
                .map((x) => AccessExceptionMapper.toMap(x))
                .toList()
          });
        }

        // Asignación Cupo
        if (classModel.availableSlots > 0) {
          transaction.update(classRef, {
            'attendees': FieldValue.arrayUnion([userId])
          });
          return BookingStatus.confirmed;
        } else {
          transaction.update(classRef, {
            'waitlist': FieldValue.arrayUnion([userId])
          });
          return BookingStatus.waitlist;
        }
      });
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      throw Exception(msg);
    }
  }

  // Escritura

  Future<void> cancelReservation({
    required String classId,
    required String userId,
  }) async {
    final classRef = _firestore.collection('classes').doc(classId);
    final userRef = _firestore.collection('users').doc(userId);

    try {
      await _firestore.runTransaction((transaction) async {
        final classSnapshot = await transaction.get(classRef);
        final userSnapshot = await transaction.get(userRef);

        if (!classSnapshot.exists) throw Exception('La clase no existe');
        if (!userSnapshot.exists) throw Exception('Usuario no encontrado');

        final classModel = ClassMapper.fromMap(classSnapshot.data()!, classSnapshot.id);
        final userModel = UserMapper.fromMap(userSnapshot.data()!, userSnapshot.id);

        if (classModel.hasFinished || classModel.startTime.isBefore(DateTime.now())) {
             throw Exception('No puedes cancelar una clase que ya pasó o empezó');
        }

        final bool isInAttendees = classModel.isUserConfirmed(userId);
        final bool isInWaitlist = classModel.isUserOnWaitlist(userId);

        if (!isInAttendees && !isInWaitlist) throw Exception('No estás inscrito en esta clase');

        // Logica reembolso
        // Si estaba confirmado (no en lista de espera), verificamos si gastó ticket
        if (isInAttendees) {
          bool coveredByPlan = _doesPlanAllowClass(userModel, classModel);
          
          // Si el plan no lo cubre, asume que usó Ticket y se devuelve
          if (!coveredByPlan) {
             bool ticketRefunded = false;
             
             final updatedExceptions = userModel.accessExceptions.map((exc) {
               if (!ticketRefunded && _isValidExceptionForRefund(exc, classModel)) {
                 ticketRefunded = true;
                 return exc.copyWith(quantity: exc.quantity + 1); // +1 💰
               }
               return exc;
             }).toList();

             if (ticketRefunded) {
               transaction.update(userRef, {
                 'access_exceptions': updatedExceptions
                    .map((x) => AccessExceptionMapper.toMap(x))
                    .toList()
               });
             }
          }
        }

        // Sacar de listas
        if (isInWaitlist) {
          transaction.update(classRef, {'waitlist': FieldValue.arrayRemove([userId])});
          return;
        }

        if (isInAttendees) {
          transaction.update(classRef, {'attendees': FieldValue.arrayRemove([userId])});

          if (classModel.waitlist.isNotEmpty) {
            final nextUser = classModel.waitlist.first; 
            transaction.update(classRef, {
              'attendees': FieldValue.arrayUnion([nextUser]), 
              'waitlist': FieldValue.arrayRemove([nextUser])  
            });
          }
        }
      });
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      throw Exception(msg);
    }
  }

  // metodos admin

  Future<void> createClassType(ClassTypeModel classType) async {
    try {
      final docRef = _firestore.collection('class_types').doc();
      await docRef.set(ClassTypeMapper.toMap(classType));
    } catch (e) {
      throw Exception('Error creando tipo de clase: $e');
    }
  }

  Future<List<ClassTypeModel>> getClassTypes() async {
    try {
      final snapshot = await _firestore
          .collection('class_types')
          .where('active', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => ClassTypeMapper.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error cargando tipos de clase: $e');
    }
  }

  Future<void> createScheduleClass(ClassModel classModel) async {
    try {
      final docRef = _firestore.collection('classes').doc(); 
      await docRef.set(ClassMapper.toMap(classModel));
    } catch (e) {
      throw Exception('Error agendando clase: $e');
    }
  }

  Future<void> replaceClass({required String oldClassId, required ClassModel newClass}) async {
    try {
      final batch = _firestore.batch();
      final oldRef = _firestore.collection('classes').doc(oldClassId);
      batch.delete(oldRef);
      final newRef = _firestore.collection('classes').doc();
      batch.set(newRef, ClassMapper.toMap(newClass));
      await batch.commit();
    } catch (e) {
      throw Exception('Error reemplazando clase: $e');
    }
  }

  // Validaciones privadas

  bool _isValidException(AccessExceptionModel exception, ClassModel classModel, DateTime now) {
    if (exception.quantity <= 0) return false;
    if (exception.validUntil != null && now.isAfter(exception.validUntil!)) return false;

    final type = exception.validForPlan;

    if (type == PlanType.wild) {
      final minutes = classModel.startTime.hour * 60 + classModel.startTime.minute;
      if (minutes > 690) return false; 
    }
    if (type == PlanType.kids) {
      final className = classModel.classType.toLowerCase();
      if (!className.contains('kids') && !className.contains('niños')) return false;
    }
    return true;
  }

  // Validación para saber qué ticket devolver
  bool _isValidExceptionForRefund(AccessExceptionModel exception, ClassModel classModel) {
    final type = exception.validForPlan;

    // Si es Wild, devuelve si la clase cancelada era de mañana
    if (type == PlanType.wild) {
      final minutes = classModel.startTime.hour * 60 + classModel.startTime.minute;
      if (minutes > 690) return false; 
    }
    // Si es Kids, devuelve si la clase cancelada era de niños
    if (type == PlanType.kids) {
      final className = classModel.classType.toLowerCase();
      if (!className.contains('kids') && !className.contains('niños')) return false;
    }
    // Si es Weekend, devuelve si la clase era fin de semana
    if (type == PlanType.weekends) {
      final day = classModel.startTime.weekday;
      if (day != 6 && day != 7) return false;
    }

    // Si el ticket es FULL, devuelve true siempre
    return true;
  }

  bool _doesPlanAllowClass(UserModel user, ClassModel classModel) {
    final activePlan = user.activePlan;
    if (activePlan == null) return false;
    
    // Regla temporal
    if (!classModel.canReserveNow) return false;

    final PlanType planType = activePlan.type;
    
    if (planType == PlanType.wild) {
      final minutes = classModel.startTime.hour * 60 + classModel.startTime.minute;
      if (minutes > 690) return false;
    }
    if (planType == PlanType.weekends) {
      final day = classModel.startTime.weekday;
      if (day != 6 && day != 7) return false;
    }
    if (planType == PlanType.kids) {
      final type = classModel.classType.toLowerCase();
      if (!type.contains('kids') && !type.contains('niños')) return false;
    }
    return true;
  }

  Future<void> _assertBasePlanAsync(UserModel userModel, ClassModel classModel, DateTime now) async {
    final activePlan = userModel.activePlan;
    if (activePlan == null) throw Exception('No tienes un plan activo.');

    if (!classModel.canReserveNow) {
       throw Exception('El tiempo de reserva ha finalizado o la clase es muy lejana.');
    }

    final PlanType planType = activePlan.type;
    
    // Validaciones de reglas
    if (planType == PlanType.wild) {
      final minutes = classModel.startTime.hour * 60 + classModel.startTime.minute;
      if (minutes > 690) throw Exception('Tu Plan WILD no permite clases en este horario.');
    }
    if (planType == PlanType.weekends) {
      final day = classModel.startTime.weekday;
      if (day != 6 && day != 7) throw Exception('Tu Plan WEEKENDS solo sirve sábados y domingos.');
    }
    if (planType == PlanType.kids) {
      final type = classModel.classType.toLowerCase();
      if (!type.contains('kids') && !type.contains('niños')) throw Exception('Tu Plan KIDS no permite esta clase.');
    }

    // Límite Diario
    bool hasDailyLimit = (planType == PlanType.wild || planType == PlanType.full || planType == PlanType.fitness);
    if (userModel.isLegacyUser || planType == PlanType.unlimited) hasDailyLimit = false;
    
    if (hasDailyLimit) {
      final startOfClassDay = DateTime(classModel.startTime.year, classModel.startTime.month, classModel.startTime.day);
      final endOfClassDay = startOfClassDay.add(const Duration(days: 1));
      
      final existingBookings = await _firestore.collection('classes')
          .where('start_time', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfClassDay))
          .where('start_time', isLessThan: Timestamp.fromDate(endOfClassDay))
          .where('attendees', arrayContains: userModel.userId)
          .get(); 
          
      if (existingBookings.docs.isNotEmpty) {
        throw Exception('Tu plan base ya usó su cupo diario.');
      }
    }
  }

  // Guardar patron
  Future<void> saveSchedulePattern(SchedulePatternModel pattern) async {
    try {
      await _firestore.collection('schedule_patterns').add(SchedulePatternMapper.toMap(pattern));
    } catch (e) {
      throw Exception('Error guardando el patrón de horario: $e');
    }
  }

  // Leer patron
  Future<List<SchedulePatternModel>> getSchedulePatterns() async {
    try {
      final snapshot = await _firestore.collection('schedule_patterns').where('active', isEqualTo: true).get();
      return snapshot.docs
          .map((doc) => SchedulePatternMapper.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception("Error leyendo patrones: $e");
    }
  }

  Future<void> forceReplaceSchedule(ClassModel newClass) async {
    try {
      final batch = _firestore.batch();
      
      final startOfDay = DateTime(newClass.startTime.year, newClass.startTime.month, newClass.startTime.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore.collection('classes')
          .where('start_time', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('start_time', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      final candidates = snapshot.docs.map((d) => ClassMapper.fromMap(d.data(), d.id)).toList();

      for (var existing in candidates) {
         if (newClass.startTime.isBefore(existing.endTime) && 
             newClass.endTime.isAfter(existing.startTime)) {
            batch.delete(_firestore.collection('classes').doc(existing.classId));
         }
      }

      final newRef = _firestore.collection('classes').doc();
      batch.set(newRef, ClassMapper.toMap(newClass));

      await batch.commit();
    } catch (e) {
      throw Exception('Error en reemplazo forzado: $e');
    }
  }
}