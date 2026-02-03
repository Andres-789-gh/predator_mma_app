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
import '../../../plans/data/plan_repository.dart';
import '../../../plans/domain/models/plan_model.dart';
import 'package:intl/intl.dart';

class TimeSlot {
  final TimeOfDay time;
  final int durationMinutes;
  TimeSlot(this.time, this.durationMinutes);
}

class AdminCubit extends Cubit<AdminState> {
  final AuthRepository _authRepository;
  final ScheduleRepository _scheduleRepository;
  final PlanRepository _planRepository;

  AdminCubit({
    required AuthRepository authRepository,
    required ScheduleRepository scheduleRepository,
    required PlanRepository planRepository,
  }) : _authRepository = authRepository,
       _scheduleRepository = scheduleRepository,
       _planRepository = planRepository,
       super(AdminInitial());

  Future<void> loadFormData({
    bool silent = false,
    bool checkSchedule = false,
  }) async {
    try {
      if (!silent) emit(AdminLoading());

      final results = await Future.wait([
        _authRepository.getInstructors(),
        _scheduleRepository.getClassTypes(),
      ]);

      if (isClosed) return;

      final instructorsList = results[0] as List<UserModel>;
      final classTypesList = results[1] as List<ClassTypeModel>;
      classTypesList.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      emit(
        AdminLoadedData(
          instructors: instructorsList,
          classTypes: classTypesList,
        ),
      );

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

      for (final day in weekDays) {
        for (final slot in timeSlots) {
          final newPatternId = _scheduleRepository.generateNewPatternId();
          final atomicPattern = SchedulePatternModel(
            id: newPatternId,
            classTypeId: classType.id,
            coachId: coach.userId,
            capacity: capacity,
            weekDays: [day],
            timeSlots: [
              {
                'hour': slot.time.hour,
                'minute': slot.time.minute,
                'duration': slot.durationMinutes,
              },
            ],
          );

          await _generateClassesFromPattern(
            atomicPattern,
            months: 3,
            throwOnConflict: !force,
            overrideClassType: classType,
            overrideCoach: coach,
            startDateOverride: startDate,
            forceReplace: force,
            preservedData: currentData,
          );

          if (state is AdminConflictDetected) return;
          await _scheduleRepository.saveSchedulePattern(atomicPattern);
        }
      }

      emit(const AdminOperationSuccess("Horario guardado correctamente."));
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
          throwOnConflict: false,
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
          type = preservedData.classTypes.firstWhere(
            (t) => t.id == pattern.classTypeId,
          );
        } catch (e) {
          debugPrint(
            "admin_cubit: no se encontró tipo de clase en preservedData: $e",
          );
        }
      }
      if (coach == null) {
        try {
          coach = preservedData.instructors.firstWhere(
            (u) => u.userId == pattern.coachId,
          );
        } catch (e) {
          debugPrint("admin_cubit: no se encontró coach en preservedData: $e");
        }
      }
    } else if (state is AdminLoadedData) {
      final loadedData = state as AdminLoadedData;

      if (type == null) {
        try {
          type = loadedData.classTypes.firstWhere(
            (t) => t.id == pattern.classTypeId,
          );
        } catch (e) {
          debugPrint(
            "admin_cubit: no se encontro tipo clase en loadeddata: $e",
          );
        }
      }

      if (coach == null) {
        try {
          coach = loadedData.instructors.firstWhere(
            (u) => u.userId == pattern.coachId,
          );
        } catch (e) {
          debugPrint("admin_cubit: no se encontro coach en loadeddata: $e");
        }
      }
    }

    if (type == null || coach == null) return;

    final startDate = startDateOverride ?? DateTime.now();
    final endDate = DateTime(
      startDate.year,
      startDate.month + months,
      startDate.day,
    );

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

          final startDateTime = DateTime(
            current.year,
            current.month,
            current.day,
            hour,
            minute,
          );
          final endDateTime = startDateTime.add(Duration(minutes: duration));

          var newClass = ClassModel(
            classId: '',
            classTypeId: type.id,
            classType: type.name,
            category: type.category,
            coachId: coach.userId,
            coachName: "${coach.firstName} ${coach.lastName}",
            startTime: startDateTime,
            endTime: endDateTime,
            maxCapacity: pattern.capacity,
            attendees: const [],
            waitlist: const [],
            isCancelled: false,
            recurrenceId: pattern.id,
          );

          final dbConflicts = existingClasses
              .where(
                (e) =>
                    newClass.startTime.isBefore(e.endTime) &&
                    newClass.endTime.isAfter(e.startTime),
              )
              .toList();

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

                await _scheduleRepository.deleteClasses(
                  classModel: oldClass,
                  mode: ClassEditMode.single,
                );
              }

              if (migratedAttendees.isNotEmpty || migratedWaitlist.isNotEmpty) {
                newClass = newClass.copyWith(
                  attendees: migratedAttendees.toList(),
                  waitlist: migratedWaitlist.toList(),
                );
                debugPrint(
                  "Migrando ${migratedAttendees.length} alumnos a la nueva clase.",
                );
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
      final refClass = classesToCreate.isNotEmpty
          ? classesToCreate.first
          : ClassModel(
              classId: '',
              classTypeId: type.id,
              classType: type.name,
              category: type.category,
              coachId: coach.userId,
              coachName: '',
              startTime: DateTime.now(),
              endTime: DateTime.now().add(const Duration(hours: 1)),
              maxCapacity: pattern.capacity,
              attendees: [],
              waitlist: [],
              isCancelled: false,
            );

      final finalData =
          preservedData ??
          (state is AdminLoadedData
              ? state as AdminLoadedData
              : const AdminLoadedData(instructors: [], classTypes: []));

      emit(
        AdminConflictDetected(
          newClass: refClass,
          conflictingClasses: allDbConflicts,
          originalData: finalData,
          conflictMessage:
              "Se encontraron ${allDbConflicts.length} conflictos al generar el horario.",
        ),
      );
      return;
    }

    for (var cls in classesToCreate) {
      await _scheduleRepository.createScheduleClass(cls);
    }
  }

  Future<void> createClassType(
    String name,
    String description,
    ClassCategory category,
  ) async {
    try {
      if (state is AdminLoadedData) {
        final currentData = state as AdminLoadedData;
        final exists = currentData.classTypes.any(
          (t) => t.name.toLowerCase().trim() == name.toLowerCase().trim(),
        );

        if (exists) {
          emit(AdminError("Ya existe una clase con el nombre '$name'"));
          emit(currentData);
          return;
        }
      }

      emit(AdminLoading());
      final newType = ClassTypeModel(
        id: '',
        name: name,
        description: description,
        active: true,
        category: category,
      );
      await _scheduleRepository.createClassType(newType);

      emit(const AdminOperationSuccess("Clase creada exitosamente"));
      await loadFormData(silent: true);
    } catch (e) {
      emit(AdminError(e.toString().replaceAll('Exception: ', '')));
      await loadFormData(silent: true);
    }
  }

  Future<void> replaceConflictingClass(
    String oldClassId,
    ClassModel newClass,
  ) async {
    try {
      emit(AdminLoading());

      if (state is AdminConflictDetected) {
        final conflicts = (state as AdminConflictDetected).conflictingClasses;
        try {
          final oldClassModel = conflicts.firstWhere(
            (c) => c.classId == oldClassId,
          );
          await _scheduleRepository.deleteClasses(
            classModel: oldClassModel,
            mode: ClassEditMode.single,
          );
        } catch (_) {}
      }

      await _scheduleRepository.createScheduleClass(newClass);

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
    bool force = false,
  }) async {
    try {
      emit(AdminLoading());

      if (!force && mode != ClassEditMode.allType) {
        final startOfDay = DateTime(
          updatedClass.startTime.year,
          updatedClass.startTime.month,
          updatedClass.startTime.day,
        );
        final endOfDay = startOfDay.add(const Duration(days: 1));

        final existing = await _scheduleRepository.getClasses(
          fromDate: startOfDay,
          toDate: endOfDay,
        );

        final conflicts = existing.where((e) {
          return e.classId != originalClass.classId &&
              !e.isCancelled &&
              updatedClass.startTime.isBefore(e.endTime) &&
              updatedClass.endTime.isAfter(e.startTime);
        }).toList();

        if (conflicts.isNotEmpty) {
          final msg = conflicts
              .map(
                (c) =>
                    "${c.classType} (${c.startTime.hour}:${c.startTime.minute.toString().padLeft(2, '0')})",
              )
              .join(", ");

          emit(
            AdminConflictDetected(
              newClass: updatedClass,
              conflictingClasses: conflicts,
              originalData: state is AdminLoadedData
                  ? (state as AdminLoadedData)
                  : const AdminLoadedData(instructors: [], classTypes: []),
              conflictMessage: msg,
            ),
          );
          return;
        }
      }

      switch (mode) {
        case ClassEditMode.single:
          await _scheduleRepository.editClassSingle(updatedClass, force: force);
          break;

        case ClassEditMode.similar:
          await _scheduleRepository.editClassSimilar(
            originalClass: originalClass,
            updatedClass: updatedClass,
            force: force,
          );
          break;

        case ClassEditMode.allType:
          await _scheduleRepository.editClassAll(updatedClass);
          break;
      }

      emit(const AdminOperationSuccess("Edición realizada correctamente"));
      await loadFormData(silent: true);
    } catch (e) {
      emit(AdminError(e.toString().replaceAll('Exception: ', '')));
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
      await _scheduleRepository.deleteClasses(
        classModel: classModel,
        mode: mode,
      );
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

  // GESTIÓN DE USUARIOS:
  // Cargar lista de usuarios y planes disponibles
  Future<void> loadUsersManagement() async {
    try {
      emit(AdminLoading());

      final results = await Future.wait([
        _authRepository.getAllUsers(),
        _planRepository.getActivePlans(),
      ]);

      final users = results[0] as List<UserModel>;
      final plans = results[1] as List<PlanModel>;

      emit(AdminUsersLoaded(users: users, availablePlans: plans));
    } catch (e) {
      emit(AdminError(e.toString()));
    }
  }

  Future<void> updateUserProfile(UserModel user) async {
    try {
      emit(AdminLoading());
      await _authRepository.updateUser(user);
      emit(const AdminOperationSuccess("Usuario actualizado correctamente"));
      await loadUsersManagement();
    } catch (e) {
      emit(AdminError(e.toString()));
      await loadUsersManagement();
    }
  }

  // Pausas masivas
  Future<void> applyMassivePause(
    DateTime startDate,
    DateTime endDate,
    String adminName,
  ) async {
    emit(AdminLoading());
    try {
      final String pauseTag = "MASIVA_${DateFormat('yyyyMMdd').format(startDate)}";
      final String auditLabel = "$pauseTag (por $adminName)";
      List<UserModel> usersToUpdate = [];
      
      if (state is AdminUsersLoaded) {
        usersToUpdate = (state as AdminUsersLoaded).users;
      } else {
        return; 
      }

      int updatedCount = 0;

      for (final user in usersToUpdate) {
        if (user.activePlan == null) continue;
        
        final currentPlan = user.activePlan!;

        // Proteccion duplicados
        final alreadyHasThisPause = currentPlan.pauses.any((p) => 
            p.createdBy.startsWith(pauseTag) &&
            p.startDate.isAtSameMomentAs(startDate) && 
            p.endDate.isAtSameMomentAs(endDate)
        );

        if (alreadyHasThisPause) continue; 

        // Crear pausa
        final newPause = PlanPause(
          startDate: startDate,
          endDate: endDate,
          createdBy: auditLabel,
        );

        final updatedPauses = List<PlanPause>.from(currentPlan.pauses)
          ..add(newPause);

        final updatedUser = user.copyWith(
          activePlan: currentPlan.copyWith(pauses: updatedPauses),
        );

        await _authRepository.updateUser(updatedUser); 
        
        updatedCount++;
      }

      await loadUsersManagement();
      
      print("Se aplicó pausa masiva a $updatedCount usuarios.");

    } catch (e) {
      emit(AdminError("Error aplicando pausa masiva: $e"));
    }
  }

  // Deshacer pausas masivas
  Future<void> undoMassivePause(DateTime originalStartDate) async {
    emit(AdminLoading());
    try {
      final String targetTag = "MASIVA_${DateFormat('yyyyMMdd').format(originalStartDate)}";
      final users = (state as AdminUsersLoaded).users;
      
      for (final user in users) {
        if (user.activePlan == null) continue;
        final currentPlan = user.activePlan!;
        final filteredPauses = currentPlan.pauses.where((p) {
          return !p.createdBy.startsWith(targetTag);
        }).toList();

        if (filteredPauses.length != currentPlan.pauses.length) {
          final updatedUser = user.copyWith(
            activePlan: currentPlan.copyWith(pauses: filteredPauses),
          );
          await _authRepository.updateUser(updatedUser);
        }
      }

      await loadUsersManagement();
    } catch (e) {
      emit(AdminError("Error deshaciendo pausa: $e"));
    }
  }
}
