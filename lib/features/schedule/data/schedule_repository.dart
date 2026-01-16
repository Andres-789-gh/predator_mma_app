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

  static const int cutOffTimeMinutes = 690;

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

    // Validación: El ticket verifica sus reglas copiadas
    return exception.scheduleRules.any((rule) => 
      rule.matchesClass(classModel.startTime, classModel.category)
    );
  }

  // Validación para saber qué ticket devolver
  bool _isValidExceptionForRefund(AccessExceptionModel exception, ClassModel classModel) {
    // Si el ticket servía para entrar a esta clase, sirve pa' reembolso.
    return exception.scheduleRules.any((rule) => 
      rule.matchesClass(classModel.startTime, classModel.category)
    );
  }

  bool _doesPlanAllowClass(UserModel user, ClassModel classModel) {
    final activePlan = user.activePlan;
    if (activePlan == null) return false;
    if (!classModel.canReserveNow) return false;
    return activePlan.scheduleRules.any((rule) => 
      rule.matchesClass(classModel.startTime, classModel.category)
    );
  }

  Future<void> _assertBasePlanAsync(UserModel userModel, ClassModel classModel, DateTime now) async {
    final activePlan = userModel.activePlan;
    if (activePlan == null) throw Exception('No tienes un plan activo.');

    if (!classModel.canReserveNow) {
       throw Exception('El tiempo de reserva ha finalizado o la clase es muy lejana.');
    }

    // Valida Reglas del Plan (Horario, Categoría, Días)
    final bool isAllowed = activePlan.scheduleRules.any((rule) => 
      rule.matchesClass(classModel.startTime, classModel.category)
    );

    if (!isAllowed) {
      throw Exception('Tu plan ${activePlan.name} no permite clases en este horario o categoría.');
    }

    // Límite Diario
    bool hasDailyLimit = activePlan.consumptionType == PlanConsumptionType.limitedDaily;
    
    // Usuario Legacy o plan Ilimitado = apaga el límite diario
    if (userModel.isLegacyUser || activePlan.consumptionType == PlanConsumptionType.unlimited) {
      hasDailyLimit = false;
    }
    
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

  // Guardar patron de horario
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

  // EDICIÓN de clases:
  
  // actualiza una clase especifica
  Future<void> updateClass(ClassModel classModel) async {
    try {
      await _firestore.collection('classes').doc(classModel.classId).update(ClassMapper.toMap(classModel));
    } catch (e) {
      throw Exception('error actualizando clase: $e');
    }
  }

  // actualiza lote de clases por lista de ids
  Future<void> updateBatchClasses(List<String> classIds, Map<String, dynamic> updates) async {
    try {
      for (var i = 0; i < classIds.length; i += 500) {
        final batch = _firestore.batch();
        final end = (i + 500 < classIds.length) ? i + 500 : classIds.length;
        final chunk = classIds.sublist(i, end);

        for (var id in chunk) {
          final ref = _firestore.collection('classes').doc(id);
          batch.update(ref, updates);
        }
        await batch.commit();
      }
    } catch (e) {
      throw Exception('error en actualizacion masiva: $e');
    }
  }

  // actualiza patrones coincidentes
  Future<void> updateMatchingPatterns({
    required String classTypeId,
    required Map<String, dynamic> updates,
    int? specificWeekday,
    int? specificHour,
    int? specificMinute,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('schedule_patterns')
          .where('active', isEqualTo: true)
          .where('class_type_id', isEqualTo: classTypeId)
          .get();

      final batch = _firestore.batch();
      bool changesMade = false;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final weekDays = List<int>.from(data['week_days'] ?? []);
        final timeSlots = List<dynamic>.from(data['time_slots'] ?? []);
        
        bool isMatch = true;

        // filtra por dia
        if (specificWeekday != null && !weekDays.contains(specificWeekday)) {
          isMatch = false;
        }
        
        // filtra por hora exacta
        if (isMatch && specificHour != null && specificMinute != null) {
           final hasSlot = timeSlots.any((slot) => 
             slot['hour'] == specificHour && slot['minute'] == specificMinute
           );
           if (!hasSlot) isMatch = false;
        }

        if (isMatch) {
          batch.update(doc.reference, updates);
          changesMade = true;
        }
      }

      if (changesMade) await batch.commit();
    } catch (e) {
      throw Exception('error actualizando patrones: $e');
    }
  }

  // Actualizaciones tipo de clase
  Future<void> updateClassType(ClassTypeModel type) async {
    try {
      await _firestore.collection('class_types').doc(type.id).update(ClassTypeMapper.toMap(type));
    } catch (e) {
      throw Exception('Error actualizando tipo: $e');
    }
  }

  Future<void> deleteClassType(String id) async {
    try {
      await _firestore.collection('class_types').doc(id).update({'active': false});
    } catch (e) {
      throw Exception('Error eliminando tipo: $e');
    }
  }

  // Eliminar clases
  Future<void> deleteClasses({
    required ClassModel classModel,
    required ClassEditMode mode,
  }) async {
    try {
      // Identifica qué clases borrar
      List<String> idsToDelete = [];

      if (mode == ClassEditMode.single) {
        idsToDelete.add(classModel.classId);
      } else {
        final now = DateTime.now();
        // Busca clases futuras para limpiar el calendario
        final futureClasses = await getClasses(
          fromDate: now, 
          toDate: now.add(const Duration(days: 90))
        );

        if (mode == ClassEditMode.similar) {
          idsToDelete = futureClasses.where((c) {
            // mismo tipo, mismo día de semana, misma hora
            return c.classTypeId == classModel.classTypeId &&
                   c.startTime.weekday == classModel.startTime.weekday &&
                   c.startTime.hour == classModel.startTime.hour &&
                   c.startTime.minute == classModel.startTime.minute;
          }).map((c) => c.classId).toList();
        } else if (mode == ClassEditMode.allType) {
          idsToDelete = futureClasses
              .where((c) => c.classTypeId == classModel.classTypeId)
              .map((c) => c.classId)
              .toList();
        }
      }

      // Ejecuta borrado de clases por lote (batch)
      for (var i = 0; i < idsToDelete.length; i += 500) {
        final chunkBatch = _firestore.batch();
        final end = (i + 500 < idsToDelete.length) ? i + 500 : idsToDelete.length;
        
        for (var id in idsToDelete.sublist(i, end)) {
          chunkBatch.delete(_firestore.collection('classes').doc(id));
        }
        await chunkBatch.commit();
      }

      // Actualizacion de patrones
      
      // Caso 1: Borra serie (similares), desactiva patrón padre específico
      if (mode == ClassEditMode.similar && classModel.recurrenceId != null) {
         await _firestore.collection('schedule_patterns')
             .doc(classModel.recurrenceId)
             .update({'active': false});
      }

      // Caso 2: Borra todo el tipo, desactiva todos los patrones de ese tipo
      if (mode == ClassEditMode.allType) {
         final patternsSnapshot = await _firestore.collection('schedule_patterns')
             .where('class_type_id', isEqualTo: classModel.classTypeId)
             .where('active', isEqualTo: true)
             .get();

         if (patternsSnapshot.docs.isNotEmpty) {
           final patternBatch = _firestore.batch();
           for (var doc in patternsSnapshot.docs) {
             patternBatch.update(doc.reference, {'active': false});
           }
           await patternBatch.commit();
         }
      }

    } catch (e) {
      throw Exception('Error eliminando clases y patrones: $e');
    }
  }
}