import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/class_model.dart';
import '../../auth/data/mappers/user_mapper.dart';
import '../../auth/data/mappers/access_exception_mapper.dart';
import 'mappers/class_mapper.dart';
import '../../../../core/constants/enums.dart';
import '../../auth/domain/models/user_model.dart';
import '../domain/schedule_logic.dart';
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
          .where(
            'start_time',
            isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate),
          )
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
      final startOfDay = DateTime(
        newClass.startTime.year,
        newClass.startTime.month,
        newClass.startTime.day,
      );
      final endOfDay = startOfDay
          .add(const Duration(days: 1))
          .subtract(const Duration(seconds: 1));
      final existingClasses = await getClasses(
        fromDate: startOfDay,
        toDate: endOfDay,
      );

      return ScheduleLogic.findConflict(newClass, existingClasses);
    } catch (e) {
      throw Exception('Error verificando conflictos: $e');
    }
  }

  ClassStatus getClassStatus(UserModel user, ClassModel classModel) {
    if (classModel.isUserConfirmed(user.userId) ||
        classModel.isUserOnWaitlist(user.userId)) {
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
      (exc) => _isValidException(exc, classModel, DateTime.now()),
    );

    if (hasValidTicket) {
      return ClassStatus.availableWithTicket;
    }

    return ClassStatus.blockedByPlan;
  }

  // Escritura
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

        final classModel = ClassMapper.fromMap(
          classSnapshot.data()!,
          classSnapshot.id,
        );
        final userModel = UserMapper.fromMap(
          userSnapshot.data()!,
          userSnapshot.id,
        );
        final now = DateTime.now();

        if (!userModel.isWaiverSigned)
          throw Exception('Debes firmar la exoneración antes de reservar.');
        if (classModel.isCancelled)
          throw Exception('La clase ha sido cancelada');

        if (classModel.isUserConfirmed(userId))
          throw Exception('Ya estás inscrito en esta clase');
        if (classModel.isUserOnWaitlist(userId))
          throw Exception('Ya estás en lista de espera');

        if (classModel.hasFinished) throw Exception('La clase ya finalizó');

        if (userModel.activePlan != null &&
            userModel.activePlan!.isPaused(now)) {
          throw Exception(
            'Tu plan está pausado actualmente, no puedes reservar',
          );
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
          }).toList();

          transaction.update(userRef, {
            'access_exceptions': updatedExceptions
                .map((x) => AccessExceptionMapper.toMap(x))
                .toList(),
          });
        }

        // Asignación Cupo
        if (classModel.availableSlots > 0) {
          transaction.update(classRef, {
            'attendees': FieldValue.arrayUnion([userId]),
          });
          return BookingStatus.confirmed;
        } else {
          transaction.update(classRef, {
            'waitlist': FieldValue.arrayUnion([userId]),
          });
          return BookingStatus.waitlist;
        }
      });
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      throw Exception(msg);
    }
  }

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

        final classModel = ClassMapper.fromMap(
          classSnapshot.data()!,
          classSnapshot.id,
        );
        final userModel = UserMapper.fromMap(
          userSnapshot.data()!,
          userSnapshot.id,
        );

        if (classModel.hasFinished ||
            classModel.startTime.isBefore(DateTime.now())) {
          throw Exception('No puedes cancelar una clase que ya pasó o empezó');
        }

        final bool isInAttendees = classModel.isUserConfirmed(userId);
        final bool isInWaitlist = classModel.isUserOnWaitlist(userId);

        if (!isInAttendees && !isInWaitlist)
          throw Exception('No estás inscrito en esta clase');

        // Logica reembolso
        if (isInAttendees) {
          bool coveredByPlan = _doesPlanAllowClass(userModel, classModel);

          if (!coveredByPlan) {
            bool ticketRefunded = false;

            final updatedExceptions = userModel.accessExceptions.map((exc) {
              if (!ticketRefunded &&
                  _isValidExceptionForRefund(exc, classModel)) {
                ticketRefunded = true;
                return exc.copyWith(quantity: exc.quantity + 1); // +1 💰
              }
              return exc;
            }).toList();

            if (ticketRefunded) {
              transaction.update(userRef, {
                'access_exceptions': updatedExceptions
                    .map((x) => AccessExceptionMapper.toMap(x))
                    .toList(),
              });
            }
          }
        }

        // Sacar de listas
        if (isInWaitlist) {
          transaction.update(classRef, {
            'waitlist': FieldValue.arrayRemove([userId]),
          });
          return;
        }

        if (isInAttendees) {
          transaction.update(classRef, {
            'attendees': FieldValue.arrayRemove([userId]),
          });

          if (classModel.waitlist.isNotEmpty) {
            final nextUser = classModel.waitlist.first;
            transaction.update(classRef, {
              'attendees': FieldValue.arrayUnion([nextUser]),
              'waitlist': FieldValue.arrayRemove([nextUser]),
            });
          }
        }
      });
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      throw Exception(msg);
    }
  }

  // Metodos admin
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

  String generateNewPatternId() {
    return _firestore.collection('schedule_patterns').doc().id;
  }

  // Guardar patron de horario
  Future<void> saveSchedulePattern(SchedulePatternModel pattern) async {
    try {
      await _firestore
          .collection('schedule_patterns')
          .doc(pattern.id)
          .set(SchedulePatternMapper.toMap(pattern));
    } catch (e) {
      throw Exception('Error guardando el patrón de horario: $e');
    }
  }

  // Leer patron
  Future<List<SchedulePatternModel>> getSchedulePatterns() async {
    try {
      final snapshot = await _firestore
          .collection('schedule_patterns')
          .where('active', isEqualTo: true)
          .get();
      return snapshot.docs
          .map((doc) => SchedulePatternMapper.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception("Error leyendo patrones: $e");
    }
  }

  Future<void> updateClassType(ClassTypeModel type) async {
    try {
      await _firestore
          .collection('class_types')
          .doc(type.id)
          .update(ClassTypeMapper.toMap(type));
    } catch (e) {
      throw Exception('Error actualizando tipo: $e');
    }
  }

  Future<void> deleteClassType(String id) async {
    try {
      await _firestore.collection('class_types').doc(id).update({
        'active': false,
      });
    } catch (e) {
      throw Exception('Error eliminando tipo: $e');
    }
  }

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

        if (specificWeekday != null && !weekDays.contains(specificWeekday)) {
          isMatch = false;
        }

        if (isMatch && specificHour != null && specificMinute != null) {
          final hasSlot = timeSlots.any(
            (slot) =>
                slot['hour'] == specificHour &&
                slot['minute'] == specificMinute,
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

  // Validación de conflictos
  Future<void> _validateConflictOrThrow(
    ClassModel classModel, {
    String? excludeClassId,
    bool force = false,
  }) async {
    final startOfDay = DateTime(
      classModel.startTime.year,
      classModel.startTime.month,
      classModel.startTime.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection('classes')
        .where(
          'start_time',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('start_time', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    final candidates = snapshot.docs
        .map((d) => ClassMapper.fromMap(d.data(), d.id))
        .where((c) => c.classId != excludeClassId && !c.isCancelled)
        .toList();

    List<ClassModel> conflicts = [];

    for (var existing in candidates) {
      if (classModel.startTime.isBefore(existing.endTime) &&
          classModel.endTime.isAfter(existing.startTime)) {
        conflicts.add(existing);
      }
    }

    if (conflicts.isNotEmpty) {
      if (force) {
        for (var conflict in conflicts) {
          final deleteMode =
              (conflict.recurrenceId != null &&
                  conflict.recurrenceId!.isNotEmpty)
              ? ClassEditMode.similar
              : ClassEditMode.single;

          await deleteClasses(classModel: conflict, mode: deleteMode);
        }
      } else {
        final first = conflicts.first;
        throw Exception(
          'Choque de horario con: ${first.classType} (${first.startTime.hour}:${first.startTime.minute.toString().padLeft(2, '0')})',
        );
      }
    }
  }

  // Edición Solo esta
  Future<void> editClassSingle(
    ClassModel updatedClass, {
    bool force = false,
  }) async {
    try {
      if (updatedClass.hasFinished) {
         throw Exception('no se puede editar una clase que ya finalizó');
      }

      await _validateConflictOrThrow(
        updatedClass,
        excludeClassId: updatedClass.classId,
        force: force,
      );

      await _firestore
          .collection('classes')
          .doc(updatedClass.classId)
          .update(ClassMapper.toMap(updatedClass));
    } catch (e) {
      throw Exception('Error editando clase única: $e');
    }
  }

  // Edición Similares
  Future<void> editClassSimilar({
    required ClassModel originalClass,
    required ClassModel updatedClass,
    bool force = false,
  }) async {
    final String? patternId = originalClass.recurrenceId;

    if (patternId == null || patternId.isEmpty) {
      return editClassSingle(updatedClass, force: force);
    }

    try {
      await _validateConflictOrThrow(
        updatedClass,
        excludeClassId: originalClass.classId,
        force: force,
      );

      final patternRef = _firestore
          .collection('schedule_patterns')
          .doc(patternId);

      final newTimeSlot = {
        'hour': updatedClass.startTime.hour,
        'minute': updatedClass.startTime.minute,
        'duration': updatedClass.endTime
            .difference(updatedClass.startTime)
            .inMinutes,
      };

      await patternRef.update({
        'coach_id': updatedClass.coachId,
        'coach_name': updatedClass.coachName,
        'max_capacity': updatedClass.maxCapacity,
        'class_type_id': updatedClass.classTypeId,
        'week_days': [updatedClass.startTime.weekday],
        'time_slots': [newTimeSlot],
      });

      await _regenerateAtomicPattern(patternId, updatedClass);
    } catch (e) {
      throw Exception('Error en edición atómica: $e');
    }
  }

  // Edición Todas
  Future<void> editClassAll(ClassModel updatedClass) async {
    return editClassSimilar(
      originalClass: updatedClass,
      updatedClass: updatedClass,
    );
  }

  Future<void> _regenerateAtomicPattern(
    String patternId,
    ClassModel sourceClass,
  ) async {
    final now = DateTime.now();
    final batch = _firestore.batch();

    final futureClasses = await _firestore
        .collection('classes')
        .where('recurrence_id', isEqualTo: patternId)
        .where('start_time', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .get();

    for (var doc in futureClasses.docs) {
      batch.delete(doc.reference);
    }

    // Obtiene datos actualizados del patrón
    final patternSnap = await _firestore
        .collection('schedule_patterns')
        .doc(patternId)
        .get();
    if (!patternSnap.exists) return;

    final pData = SchedulePatternMapper.fromMap(
      patternSnap.data()!,
      patternSnap.id,
    );

    // Genera nuevas clases
    final endDate = now.add(const Duration(days: 90));

    if (pData.weekDays.isEmpty || pData.timeSlots.isEmpty) return;

    final targetDay = pData.weekDays.first;
    final slot = pData.timeSlots.first;

    var cursor = DateTime(now.year, now.month, now.day);

    while (cursor.weekday != targetDay) {
      cursor = cursor.add(const Duration(days: 1));
    }

    cursor = DateTime(
      cursor.year,
      cursor.month,
      cursor.day,
      slot['hour'],
      slot['minute'] as int,
    );

    if (cursor.isBefore(now)) {
      cursor = cursor.add(const Duration(days: 7));
    }

    while (cursor.isBefore(endDate)) {
      final endCursor = cursor.add(Duration(minutes: slot['duration'] as int));
      final newDocRef = _firestore.collection('classes').doc();

      final newClass = ClassModel(
        classId: newDocRef.id,
        classTypeId: pData.classTypeId,
        classType: sourceClass.classType,
        category: sourceClass.category,
        coachId: pData.coachId,
        coachName: sourceClass.coachName,
        startTime: cursor,
        endTime: endCursor,
        maxCapacity: pData.capacity,
        attendees: [],
        waitlist: [],
        recurrenceId: patternId,
      );

      batch.set(newDocRef, ClassMapper.toMap(newClass));
      cursor = cursor.add(const Duration(days: 7));
    }

    await batch.commit();
  }

  // Eliminación
  Future<void> deleteClasses({
    required ClassModel classModel,
    required ClassEditMode mode,
  }) async {
    try {
      if (mode == ClassEditMode.single) {
        // Borrado simple
        await _firestore.collection('classes').doc(classModel.classId).delete();
      } else {
        // Borrado de serie
        if (classModel.recurrenceId != null) {
          // Desactiva patrón
          await _firestore
              .collection('schedule_patterns')
              .doc(classModel.recurrenceId)
              .update({'active': false});

          // Borra clases futuras vinculadas
          final now = DateTime.now();
          final snapshot = await _firestore
              .collection('classes')
              .where('recurrence_id', isEqualTo: classModel.recurrenceId)
              .where(
                'start_time',
                isGreaterThanOrEqualTo: Timestamp.fromDate(now),
              )
              .get();

          final batch = _firestore.batch();
          for (var doc in snapshot.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      }
    } catch (e) {
      throw Exception('Error eliminando clases: $e');
    }
  }

  bool _isValidException(
    AccessExceptionModel exception,
    ClassModel classModel,
    DateTime now,
  ) {
    if (exception.quantity <= 0) return false;
    if (exception.validUntil != null && now.isAfter(exception.validUntil!))
      return false;

    return exception.scheduleRules.any(
      (rule) => rule.matchesClass(classModel.startTime, classModel.category),
    );
  }

  bool _isValidExceptionForRefund(
    AccessExceptionModel exception,
    ClassModel classModel,
  ) {
    return exception.scheduleRules.any(
      (rule) => rule.matchesClass(classModel.startTime, classModel.category),
    );
  }

  bool _doesPlanAllowClass(UserModel user, ClassModel classModel) {
    final activePlan = user.activePlan;
    if (activePlan == null) return false;
    if (!classModel.canReserveNow) return false;
    return activePlan.scheduleRules.any(
      (rule) => rule.matchesClass(classModel.startTime, classModel.category),
    );
  }

  Future<void> _assertBasePlanAsync(
    UserModel userModel,
    ClassModel classModel,
    DateTime now,
  ) async {
    final activePlan = userModel.activePlan;
    if (activePlan == null) throw Exception('No tienes un plan activo.');

    if (!classModel.canReserveNow) {
      throw Exception(
        'El tiempo de reserva ha finalizado o la clase es muy lejana.',
      );
    }

    final bool isAllowed = activePlan.scheduleRules.any(
      (rule) => rule.matchesClass(classModel.startTime, classModel.category),
    );

    if (!isAllowed) {
      throw Exception(
        'Tu plan ${activePlan.name} no permite clases en este horario o categoría.',
      );
    }

    bool hasDailyLimit =
        activePlan.consumptionType == PlanConsumptionType.limitedDaily;

    if (userModel.isLegacyUser ||
        activePlan.consumptionType == PlanConsumptionType.unlimited) {
      hasDailyLimit = false;
    }

    if (hasDailyLimit) {
      final startOfClassDay = DateTime(
        classModel.startTime.year,
        classModel.startTime.month,
        classModel.startTime.day,
      );
      final endOfClassDay = startOfClassDay.add(const Duration(days: 1));

      final existingBookings = await _firestore
          .collection('classes')
          .where(
            'start_time',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfClassDay),
          )
          .where('start_time', isLessThan: Timestamp.fromDate(endOfClassDay))
          .where('attendees', arrayContains: userModel.userId)
          .get();

      if (existingBookings.docs.isNotEmpty) {
        throw Exception('Tu plan base ya usó su cupo diario.');
      }
    }
  }
}
