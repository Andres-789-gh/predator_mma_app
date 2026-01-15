import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../schedule/data/schedule_repository.dart';
import '../../../schedule/domain/models/class_model.dart';
import '../../../schedule/domain/models/class_type_model.dart';
import 'admin_state.dart';
import '../../../schedule/domain/models/schedule_pattern_model.dart';
import '../../../../core/constants/enums.dart';

class TimeSlot {
  final TimeOfDay time;
  final int durationMinutes;
  TimeSlot(this.time, this.durationMinutes);
}

class AdminCubit extends Cubit<AdminState> {
  final AuthRepository _authRepository;
  final ScheduleRepository _scheduleRepository;

  AdminCubit({
    required AuthRepository authRepository,
    required ScheduleRepository scheduleRepository,
  })  : _authRepository = authRepository,
        _scheduleRepository = scheduleRepository,
        super(AdminInitial());

  Future<void> loadFormData({bool silent = false, bool checkSchedule = false}) async {
    try {
      if (!silent) emit(AdminLoading());

      final results = await Future.wait([
        _authRepository.getInstructors(),
        _scheduleRepository.getClassTypes(),
      ]);

      if (isClosed) return;

      final instructorsList = results[0] as List<UserModel>;
      final classTypesList = results[1] as List<ClassTypeModel>;

      emit(AdminLoadedData(
        instructors: instructorsList,
        classTypes: classTypesList,
      ));

      if (checkSchedule) {
        await _checkAndRefillSchedule();
      }

    } catch (e) {
      if (isClosed) return;
      emit(AdminError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> projectSchedule({
    required ClassTypeModel classType,
    required UserModel coach,
    required int capacity,
    required List<int> weekDays,
    required List<TimeSlot> timeSlots,
    required DateTime startDate,
    bool force = false,
  }) async {
    try {
      AdminLoadedData? currentData;
      
      if (state is AdminLoadedData) {
        currentData = state as AdminLoadedData;
      } else if (state is AdminConflictDetected) {
        currentData = (state as AdminConflictDetected).originalData;
      }

      emit(AdminLoading());

      final pattern = SchedulePatternModel(
        id: '',
        classTypeId: classType.id,
        coachId: coach.userId,
        capacity: capacity,
        weekDays: weekDays,
        timeSlots: timeSlots.map((t) => {
          'hour': t.time.hour,
          'minute': t.time.minute,
          'duration': t.durationMinutes
        }).toList(),
      );
      
      await _generateClassesFromPattern(
        pattern, 
        months: 3, 
        throwOnConflict: !force,
        overrideClassType: classType,
        overrideCoach: coach,
        startDateOverride: startDate,
        forceReplace: force,
        preservedData: currentData, 
      );

      if (state is AdminConflictDetected) {
        return; 
      }

      await _scheduleRepository.saveSchedulePattern(pattern);
      
      emit(const AdminOperationSuccess("Horario guardado."));
      
      await loadFormData(silent: true);

    } catch (e) {
      emit(AdminError(e.toString().replaceAll('Exception: ', '')));
      await loadFormData(silent: true);
    }
  }

  Future<void> _checkAndRefillSchedule() async {
    try {
      if (state is! AdminLoadedData) return;

      final patternsSnapshot = await _scheduleRepository.getSchedulePatterns();
      if (patternsSnapshot.isEmpty) return;

      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final thisWeekClasses = await _scheduleRepository.getClasses(
        fromDate: startOfToday,
        toDate: startOfToday.add(const Duration(days: 7)),
      );

      final nextMonthDate = startOfToday.add(const Duration(days: 30));
      final nextMonthClasses = await _scheduleRepository.getClasses(
        fromDate: nextMonthDate,
        toDate: nextMonthDate.add(const Duration(days: 7)),
      );

      DateTime? targetStartDate;

      if (thisWeekClasses.isEmpty) {
        debugPrint("Semana actual vacía. Generando desde hoy...");
        targetStartDate = startOfToday;
      } else if (nextMonthClasses.isEmpty) {
        debugPrint("Semana actual activa. Extendiendo horario a futuro...");
        targetStartDate = nextMonthDate;
      } else {
        debugPrint("Calendario saludable. Robot en reposo.");
        return;
      }

      for (var pattern in patternsSnapshot) {
          await _generateClassesFromPattern(
            pattern, 
            months: 3, 
            startDateOverride: targetStartDate, 
            throwOnConflict: false
          );
      }
      debugPrint("Mantenimiento completado.");
      
    } catch (e) {
      debugPrint("Error en mantenimiento: $e");
    }
  }

  Future<void> _generateClassesFromPattern(
    SchedulePatternModel pattern, {
    required int months,
    bool throwOnConflict = false,
    ClassTypeModel? overrideClassType,
    UserModel? overrideCoach,
    DateTime? startDateOverride,
    bool forceReplace = false,
    AdminLoadedData? preservedData, 
  }) async {
    
    for (int i = 0; i < pattern.timeSlots.length; i++) {
      for (int j = i + 1; j < pattern.timeSlots.length; j++) {
        final slotA = pattern.timeSlots[i];
        final slotB = pattern.timeSlots[j];
        final startA = (slotA['hour'] as int) * 60 + (slotA['minute'] as int);
        final endA = startA + (slotA['duration'] as int);
        final startB = (slotB['hour'] as int) * 60 + (slotB['minute'] as int);
        final endB = startB + (slotB['duration'] as int);

        if (startA < endB && endA > startB) {
           throw Exception("Error: Horarios superpuestos en la lista.");
        }
      }
    }

    ClassTypeModel? type = overrideClassType;
    UserModel? coach = overrideCoach;

    if (preservedData != null) {
      if (type == null) {
        try { 
          type = preservedData.classTypes.firstWhere((t) => t.id == pattern.classTypeId); 
        } catch (e) {
          debugPrint("admin_cubit: no se encontró tipo de clase en preservedData: $e");
        }
      }
      if (coach == null) {
        try { 
          coach = preservedData.instructors.firstWhere((u) => u.userId == pattern.coachId); 
        } catch (e) {
          debugPrint("admin_cubit: no se encontró coach en preservedData: $e");
        }
      }
    } else if (state is AdminLoadedData) {
      final loadedData = state as AdminLoadedData;
      
      if (type == null) {
        try { 
          type = loadedData.classTypes.firstWhere((t) => t.id == pattern.classTypeId); 
        } catch (e) {
          debugPrint("admin_cubit: no se encontro tipo clase en loadeddata: $e");
        }
      }

      if (coach == null) {
        try { 
          coach = loadedData.instructors.firstWhere((u) => u.userId == pattern.coachId); 
        } catch (e) {
          debugPrint("admin_cubit: no se encontro coach en loadeddata: $e");
        }
      }
    }

    if (type == null || coach == null) return;

    final startDate = startDateOverride ?? DateTime.now();
    final endDate = DateTime(startDate.year, startDate.month + months, startDate.day);

    final existingClasses = await _scheduleRepository.getClasses(
      fromDate: startDate,
      toDate: endDate,
    );

    final List<ClassModel> classesToCreate = [];
    final List<ClassModel> allDbConflicts = []; 
    
    DateTime current = startDate;

    while (current.isBefore(endDate)) {
      if (pattern.weekDays.contains(current.weekday)) {
        for (var slotMap in pattern.timeSlots) {
          final hour = slotMap['hour'] as int;
          final minute = slotMap['minute'] as int;
          final duration = slotMap['duration'] as int; 

          final startDateTime = DateTime(current.year, current.month, current.day, hour, minute);
          final endDateTime = startDateTime.add(Duration(minutes: duration));

          var newClass = ClassModel(
            classId: '',
            classTypeId: type.id,
            classType: type.name,
            coachId: coach.userId,
            coachName: "${coach.firstName} ${coach.lastName}",
            startTime: startDateTime,
            endTime: endDateTime,
            maxCapacity: pattern.capacity,
            attendees: const [],
            waitlist: const [],
            isCancelled: false,
          );

          final dbConflicts = existingClasses.where((e) => 
              newClass.startTime.isBefore(e.endTime) && 
              newClass.endTime.isAfter(e.startTime)
          ).toList();
          
          if (dbConflicts.isNotEmpty) {
            if (!forceReplace && throwOnConflict) {
              allDbConflicts.addAll(dbConflicts);
              continue; 
            }
            
            if (forceReplace) {
               final Set<String> migratedAttendees = {};
               final Set<String> migratedWaitlist = {};

               for (var oldClass in dbConflicts) {
                 migratedAttendees.addAll(oldClass.attendees);
                 migratedWaitlist.addAll(oldClass.waitlist);
               }

               if (migratedAttendees.isNotEmpty || migratedWaitlist.isNotEmpty) {
                 newClass = newClass.copyWith(
                   attendees: migratedAttendees.toList(),
                   waitlist: migratedWaitlist.toList(),
                 );
                 debugPrint("Migrando ${migratedAttendees.length} alumnos a la nueva clase.");
               }
            } else {
              continue;
            }
          }
          
          classesToCreate.add(newClass);
        }
      }
      current = current.add(const Duration(days: 1));
    }

    if (allDbConflicts.isNotEmpty && throwOnConflict) {
       final refClass = classesToCreate.isNotEmpty ? classesToCreate.first : 
          ClassModel(
            classId: '', 
            classTypeId: type.id, 
            classType: type.name, 
            coachId: coach.userId, 
            coachName: '', 
            startTime: DateTime.now(), 
            endTime: DateTime.now().add(const Duration(hours: 1)),
            maxCapacity: pattern.capacity,
            attendees: [], 
            waitlist: [], 
            isCancelled: false
          );

       final finalData = preservedData ?? (state is AdminLoadedData ? state as AdminLoadedData : 
          const AdminLoadedData(instructors: [], classTypes: []));

       emit(AdminConflictDetected(
          newClass: refClass,
          conflictingClasses: allDbConflicts, 
          originalData: finalData, 
       ));
       return; 
    }

    for (var cls in classesToCreate) {
      if (forceReplace) {
        await _scheduleRepository.forceReplaceSchedule(cls);
      } else {
        await _scheduleRepository.createScheduleClass(cls);
      }
    }
  }

  Future<void> createClassType(String name, String description) async {
    try {
      if (state is AdminLoadedData) {
        final currentData = state as AdminLoadedData;
        final exists = currentData.classTypes.any(
          (t) => t.name.toLowerCase().trim() == name.toLowerCase().trim()
        );
        
        if (exists) {
          emit(AdminError("Ya existe una clase con el nombre '$name'"));
          emit(currentData);
          return;
        }
      }

      emit(AdminLoading());
      final newType = ClassTypeModel(id: '', name: name, description: description, active: true);
      await _scheduleRepository.createClassType(newType);
      
      emit(const AdminOperationSuccess("Clase creada exitosamente"));
      await loadFormData(silent: true); 
      
    } catch (e) {
      emit(AdminError(e.toString().replaceAll('Exception: ', '')));
      await loadFormData(silent: true); 
    }
  }

  Future<void> replaceConflictingClass(String oldClassId, ClassModel newClass) async {
    try {
      emit(AdminLoading());
      await _scheduleRepository.replaceClass(oldClassId: oldClassId, newClass: newClass);
      emit(const AdminOperationSuccess("Clase reemplazada exitosamente"));
      await loadFormData(silent: true);
    } catch (e) {
      emit(AdminError(e.toString().replaceAll('Exception: ', '')));
      await loadFormData(silent: true);
    }
  }

  Future<void> editClass({
    required ClassModel originalClass,
    required ClassModel updatedClass,
    required ClassEditMode mode,
  }) async {
    try {
      emit(AdminLoading());
      final Map<String, dynamic> updates = {};
      
      if (originalClass.coachId != updatedClass.coachId) {
        updates['coach_id'] = updatedClass.coachId; 
        updates['coach_name'] = updatedClass.coachName;
      }
      if (originalClass.maxCapacity != updatedClass.maxCapacity) {
        updates['max_capacity'] = updatedClass.maxCapacity;
      }
      if (originalClass.classTypeId != updatedClass.classTypeId) {
        updates['class_type_id'] = updatedClass.classTypeId;
        updates['type'] = updatedClass.classType;
      }
      if (originalClass.startTime != updatedClass.startTime || originalClass.endTime != updatedClass.endTime) {
        updates['start_time'] = updatedClass.startTime;
        updates['end_time'] = updatedClass.endTime;
      }

      if (updates.isEmpty) {
        emit(const AdminOperationSuccess("No se detectaron cambios"));
        await loadFormData(silent: true);
        return;
      }

      switch (mode) {
        case ClassEditMode.single:
          await _scheduleRepository.updateClass(updatedClass);
          break;

        case ClassEditMode.similar:
          // Actualizar la actual
          await _scheduleRepository.updateClass(updatedClass);
          
          // Buscar futuras
          final now = DateTime.now();
          final futureClasses = await _scheduleRepository.getClasses(
            fromDate: now, 
            toDate: now.add(const Duration(days: 90))
          );

          // Filtro Diagnóstico (Mismo tipo, día y hora)
          final idsToUpdate = futureClasses.where((c) {
            if (c.classId == originalClass.classId) return false;
            
            return c.classTypeId == originalClass.classTypeId && 
                   c.startTime.weekday == originalClass.startTime.weekday &&
                   c.startTime.hour == originalClass.startTime.hour &&
                   (c.startTime.minute - originalClass.startTime.minute).abs() <= 1; 
          }).map((c) => c.classId).toList();

          // Actualizar Clases Futuras
          if (idsToUpdate.isNotEmpty) {
            final safeUpdates = Map<String, dynamic>.from(updates);
            if (safeUpdates.containsKey('start_time')) {
               safeUpdates.remove('start_time');
               safeUpdates.remove('end_time');
            }
            if (safeUpdates.isNotEmpty) {
               await _scheduleRepository.updateBatchClasses(idsToUpdate, safeUpdates);
            }
          }

          if (updates.isNotEmpty) {
             final patternUpdates = <String, dynamic>{};
             
             if (updates.containsKey('coach_id')) {
               patternUpdates['coach_id'] = updates['coach_id'];
             }
             
             if (updates.containsKey('max_capacity')) {
               patternUpdates['capacity'] = updates['max_capacity']; 
             }
             
             if (updates.containsKey('class_type_id')) {
               patternUpdates['class_type_id'] = updates['class_type_id'];
             }
             
             if (patternUpdates.isNotEmpty) {
               await _scheduleRepository.updateMatchingPatterns(
                 classTypeId: originalClass.classTypeId,
                 updates: patternUpdates,
                 specificWeekday: originalClass.startTime.weekday,
                 specificHour: originalClass.startTime.hour,
                 specificMinute: originalClass.startTime.minute,
               );
             }
          }
          break;

        case ClassEditMode.allType:
          // Actualizar la actual
          await _scheduleRepository.updateClass(updatedClass);

          // Buscar todas las de ese tipo
          final nowType = DateTime.now();
          final futureClassesType = await _scheduleRepository.getClasses(
            fromDate: nowType, 
            toDate: nowType.add(const Duration(days: 90))
          );

          final idsToUpdateType = futureClassesType
              .where((c) => c.classTypeId == originalClass.classTypeId && c.classId != originalClass.classId)
              .map((c) => c.classId)
              .toList();

          // Actualizar Lote
          if (idsToUpdateType.isNotEmpty) {
             final safeUpdates = Map<String, dynamic>.from(updates);
             safeUpdates.remove('start_time'); 
             safeUpdates.remove('end_time');

             if (safeUpdates.isNotEmpty) {
               await _scheduleRepository.updateBatchClasses(idsToUpdateType, safeUpdates);
             }
          }

          // Actualizar todos los patrones de ese tipo
          if (updates.isNotEmpty) {
             final patternUpdates = <String, dynamic>{};
             
             if (updates.containsKey('coach_id')) patternUpdates['coach_id'] = updates['coach_id'];
             if (updates.containsKey('max_capacity')) patternUpdates['capacity'] = updates['max_capacity'];
             if (updates.containsKey('class_type_id')) patternUpdates['class_type_id'] = updates['class_type_id'];
             
             if (patternUpdates.isNotEmpty) {
               await _scheduleRepository.updateMatchingPatterns(
                 classTypeId: originalClass.classTypeId,
                 updates: patternUpdates,
               );
             }
          }
          break;
      }

      emit(const AdminOperationSuccess("Edición realizada correctamente"));
      await loadFormData(silent: true);

    } catch (e) {
      emit(AdminError(e.toString()));
      await loadFormData(silent: true);
    }
  }

  // Eliminar Clases (Calendario)
  Future<void> deleteClass({
    required ClassModel classModel,
    required ClassEditMode mode,
  }) async {
    try {
      emit(AdminLoading());
      await _scheduleRepository.deleteClasses(classModel: classModel, mode: mode);
      emit(const AdminOperationSuccess("Clase(s) eliminada(s)"));
      await loadFormData(silent: true);
    } catch (e) {
      emit(AdminError(e.toString()));
      await loadFormData(silent: true);
    }
  }

  // Actualizar Clase (Catálogo)
  Future<void> updateClassType(ClassTypeModel type) async {
    try {
      emit(AdminLoading());
      await _scheduleRepository.updateClassType(type);
      emit(const AdminOperationSuccess("Catálogo actualizado"));
      await loadFormData(silent: true);
    } catch (e) {
      emit(AdminError(e.toString()));
      await loadFormData(silent: true);
    }
  }

  // Eliminar Clase (Catálogo)
  Future<void> deleteClassType(String id) async {
    try {
      emit(AdminLoading());
      await _scheduleRepository.deleteClassType(id);
      emit(const AdminOperationSuccess("Clase eliminada del catálogo"));
      await loadFormData(silent: true);
    } catch (e) {
      emit(AdminError(e.toString()));
      await loadFormData(silent: true);
    }
  }
}