import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/schedule_repository.dart';
import '../../domain/models/class_model.dart';
import '../../../auth/domain/models/user_model.dart';
import '../models/schedule_item.dart';
import 'schedule_state.dart';

class ScheduleCubit extends Cubit<ScheduleState> {
  final ScheduleRepository _repository;

  ScheduleCubit({required ScheduleRepository repository})
    : _repository = repository,
      super(ScheduleInitial());

  // helper privado
  Future<List<ScheduleItem>> _mapClassesToItems(
    List<ClassModel> classes,
    UserModel user,
  ) async {
    final futures = classes.map((c) async {
      final status = await _repository.getClassStatus(user, c);
      return ScheduleItem(classModel: c, status: status);
    });

    return Future.wait(futures);
  }

  // cargar horario
  Future<void> loadSchedule(DateTime from, DateTime to, UserModel user) async {
    try {
      if (isClosed) return;
      emit(ScheduleLoading());

      final classes = await _repository.getClasses(fromDate: from, toDate: to);
      if (isClosed) return;

      final items = await _mapClassesToItems(classes, user);
      if (isClosed) return;

      emit(ScheduleLoaded(items: items, selectedDate: from));
    } catch (e) {
      if (isClosed) return;
      emit(ScheduleError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  // refrescar horario
  Future<void> refreshSchedule(
    DateTime from,
    DateTime to,
    UserModel user,
  ) async {
    try {
      final classes = await _repository.getClasses(fromDate: from, toDate: to);
      if (isClosed) return;

      final items = await _mapClassesToItems(classes, user);
      if (isClosed) return;

      final currentDate = state is ScheduleLoaded
          ? (state as ScheduleLoaded).selectedDate
          : from;

      emit(
        ScheduleLoaded(
          items: items,
          selectedDate: currentDate,
          processingId: null,
        ),
      );
    } catch (e) {
      debugPrint('error refrescando horario: $e');
    }
  }

  // reservar clase
  Future<void> reserveClass({
    required String classId,
    required UserModel user,
    required DateTime currentFromDate,
    required DateTime currentToDate,
    String? planId,
  }) async {
    List<ScheduleItem> backupItems = [];
    DateTime backupDate = currentFromDate;

    if (state is ScheduleLoaded) {
      final loadedState = state as ScheduleLoaded;
      backupItems = loadedState.items;
      backupDate = loadedState.selectedDate;
      emit(loadedState.copyWith(processingId: classId));
    }

    try {
      await _repository.reserveClass(
        classId: classId,
        userId: user.userId,
        planId: planId,
      );

      if (isClosed) return;

      final updatedClasses = await _repository.getClasses(
        fromDate: currentFromDate,
        toDate: currentToDate,
      );

      if (isClosed) return;

      final updatedItems = await _mapClassesToItems(updatedClasses, user);

      if (isClosed) return;

      emit(
        ScheduleOperationSuccess(
          message: '¡Reserva exitosa!',
          items: updatedItems,
        ),
      );

      emit(
        ScheduleLoaded(
          items: updatedItems,
          selectedDate: backupDate,
          processingId: null,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(ScheduleError(e.toString().replaceAll('Exception: ', '')));

      if (backupItems.isNotEmpty) {
        emit(
          ScheduleLoaded(
            items: backupItems,
            selectedDate: backupDate,
            processingId: null,
          ),
        );
      }
    }
  }

  // cancelar clase
  Future<void> cancelClass({
    required String classId,
    required UserModel user,
    required DateTime currentFromDate,
    required DateTime currentToDate,
  }) async {
    List<ScheduleItem> backupItems = [];
    DateTime backupDate = currentFromDate;

    if (state is ScheduleLoaded) {
      final loadedState = state as ScheduleLoaded;
      backupItems = loadedState.items;
      backupDate = loadedState.selectedDate;
      emit(loadedState.copyWith(processingId: classId));
    }

    try {
      await _repository.cancelReservation(
        classId: classId,
        userId: user.userId,
      );

      if (isClosed) return;

      final updatedClasses = await _repository.getClasses(
        fromDate: currentFromDate,
        toDate: currentToDate,
      );

      if (isClosed) return;

      final updatedItems = await _mapClassesToItems(updatedClasses, user);

      if (isClosed) return;

      emit(
        ScheduleOperationSuccess(
          message: 'Reserva cancelada.',
          items: updatedItems,
        ),
      );

      emit(
        ScheduleLoaded(
          items: updatedItems,
          selectedDate: backupDate,
          processingId: null,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(ScheduleError(e.toString().replaceAll('Exception: ', '')));

      if (backupItems.isNotEmpty) {
        emit(
          ScheduleLoaded(
            items: backupItems,
            selectedDate: backupDate,
            processingId: null,
          ),
        );
      }
    }
  }
}
