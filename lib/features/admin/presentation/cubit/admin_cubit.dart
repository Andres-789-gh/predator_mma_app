import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../schedule/data/schedule_repository.dart';
import '../../../schedule/domain/models/class_model.dart';
import '../../../schedule/domain/models/class_type_model.dart';
import '../../../schedule/domain/schedule_logic.dart';
import 'admin_state.dart';
import '../../../schedule/domain/models/schedule_pattern_model.dart';

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

  // Carga inicial de datos
  Future<void> loadFormData({bool silent = false}) async {
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

      _checkAndRefillSchedule();

    } catch (e) {
      if (isClosed) return;
      emit(AdminError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  // admin guarda horario nuevo
  Future<void> projectSchedule({
    required ClassTypeModel classType,
    required UserModel coach,
    required int capacity,
    required List<int> weekDays,
    required List<TimeSlot> timeSlots,
    required DateTime startDate,
  }) async {
    try {
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
      await _scheduleRepository.saveSchedulePattern(pattern);

      await _generateClassesFromPattern(
        pattern, 
        months: 3, 
        throwOnConflict: true,
        overrideClassType: classType,
        overrideCoach: coach,
        startDateOverride: startDate,
      );

      emit(const AdminOperationSuccess("Horario guardado y generado por 3 meses."));
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

      // Revisa si hay clases el mes que viene
      final nextMonth = DateTime.now().add(const Duration(days: 30));
      final classesNextMonth = await _scheduleRepository.getClasses(
        fromDate: nextMonth,
        toDate: nextMonth.add(const Duration(days: 1)),
      );

      // Si está vacío rellena
      if (classesNextMonth.isEmpty) {
        debugPrint("Generando horarios...");
        for (var pattern in patternsSnapshot) {
           await _generateClassesFromPattern(pattern, months: 3, throwOnConflict: false);
        }
        debugPrint("Horarios generados correctamente.");
        await loadFormData(silent: true);
      }
    } catch (e) {
      debugPrint("Error en generación de horarios: $e");
    }
  }

  Future<void> _generateClassesFromPattern(
    SchedulePatternModel pattern, {
    required int months,
    bool throwOnConflict = false,
    ClassTypeModel? overrideClassType,
    UserModel? overrideCoach,
    DateTime? startDateOverride,
  }) async {
    
    ClassTypeModel? type = overrideClassType;
    UserModel? coach = overrideCoach;

    if (state is AdminLoadedData) {
      final loadedData = state as AdminLoadedData;
      
      if (type == null) {
        try {
          type = loadedData.classTypes.firstWhere((t) => t.id == pattern.classTypeId);
        } catch (_) {
        }
      }

      if (coach == null) {
        try {
           coach = loadedData.instructors.firstWhere((u) => u.userId == pattern.coachId);
        } catch (_) {
        }
      }
    }

    if (type == null || coach == null) {
      debugPrint("Saltando patrón corrupto o incompleto ID: ${pattern.id}");
      return;
    }

    final startDate = startDateOverride ?? DateTime.now();
    final endDate = DateTime(startDate.year, startDate.month + months, startDate.day);

    final existingClasses = await _scheduleRepository.getClasses(
      fromDate: startDate,
      toDate: endDate,
    );

    final List<ClassModel> classesToCreate = [];
    DateTime current = startDate;

    while (current.isBefore(endDate)) {
      if (pattern.weekDays.contains(current.weekday)) {
        
        for (var slotMap in pattern.timeSlots) {
          final hour = slotMap['hour'] as int;
          final minute = slotMap['minute'] as int;
          final duration = slotMap['duration'] as int; 

          final startDateTime = DateTime(current.year, current.month, current.day, hour, minute);
          final endDateTime = startDateTime.add(Duration(minutes: duration));

          final newClass = ClassModel(
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

          // Chequeo de conflictos
          var conflict = ScheduleLogic.findConflict(newClass, existingClasses);
          conflict ??= ScheduleLogic.findConflict(newClass, classesToCreate);

          if (conflict != null) {
            if (throwOnConflict) {
              emit(AdminConflictDetected(
                newClass: newClass,
                conflictingClass: conflict,
              ));
              throw Exception("Conflicto detectado"); 
            } else {
              continue; 
            }
          }
          classesToCreate.add(newClass);
        }
      }
      current = current.add(const Duration(days: 1));
    }

    for (var cls in classesToCreate) {
      await _scheduleRepository.createScheduleClass(cls);
    }
  }

  // Crear Tipo
  Future<void> createClassType(String name, String description) async {
    try {
      emit(AdminLoading());
      final newType = ClassTypeModel(id: '', name: name, description: description, active: true);
      await _scheduleRepository.createClassType(newType);
      emit(const AdminOperationSuccess("Disciplina creada exitosamente"));
      await loadFormData(silent: true); 
    } catch (e) {
      emit(AdminError(e.toString().replaceAll('Exception: ', '')));
      await loadFormData(silent: true); 
    }
  }

  // Reemplazar Clase
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
}