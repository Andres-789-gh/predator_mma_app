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

  // Helper privado
  List<ScheduleItem> _mapClassesToItems(List<ClassModel> classes, UserModel user) {
    return classes.map((c) {
      final status = _repository.getClassStatus(user, c);
      return ScheduleItem(classModel: c, status: status);
    }).toList();
  }

  // Cargar clases
  Future<void> loadSchedule(DateTime from, DateTime to, UserModel user) async {
    try {
      emit(ScheduleLoading());
      final classes = await _repository.getClasses(fromDate: from, toDate: to);
      final items = _mapClassesToItems(classes, user);
      
      emit(ScheduleLoaded(items: items, selectedDate: from));
    } catch (e) {
      emit(ScheduleError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  // Refresh
  Future<void> refreshSchedule(DateTime from, DateTime to, UserModel user) async {
    try {
      final classes = await _repository.getClasses(fromDate: from, toDate: to);
      final items = _mapClassesToItems(classes, user);
      
      final currentDate = state is ScheduleLoaded 
          ? (state as ScheduleLoaded).selectedDate 
          : from;
          
      emit(ScheduleLoaded(items: items, selectedDate: currentDate));
    } catch (e) {
      debugPrint('Error refrescando horario: $e');
    }
  }

  // Reservar
  Future<void> reserveClass({
    required String classId, 
    required UserModel user,
    required DateTime currentFromDate,
    required DateTime currentToDate,
  }) async {
    
    // Backup del ViewModel
    List<ScheduleItem> backupItems = [];
    DateTime backupDate = currentFromDate;

    if (state is ScheduleLoaded) {
      final loadedState = state as ScheduleLoaded;
      backupItems = loadedState.items;
      backupDate = loadedState.selectedDate;
      emit(loadedState.copyWith(isOperationLoading: true));
    }

    try {
      await _repository.reserveClass(classId: classId, userId: user.userId);
      
      final updatedClasses = await _repository.getClasses(fromDate: currentFromDate, toDate: currentToDate);
      final updatedItems = _mapClassesToItems(updatedClasses, user);
      
      emit(ScheduleOperationSuccess(
        message: '¡Reserva exitosa!', 
        items: updatedItems
      ));

      emit(ScheduleLoaded(
        items: updatedItems, 
        selectedDate: backupDate,
        isOperationLoading: false,
      ));

    } catch (e) {
      emit(ScheduleError(e.toString().replaceAll('Exception: ', '')));

      if (backupItems.isNotEmpty) {
        emit(ScheduleLoaded(
          items: backupItems,
          selectedDate: backupDate,
          isOperationLoading: false, 
        ));
      }
    }
  }

  // Cancelar
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
      emit(loadedState.copyWith(isOperationLoading: true));
    }

    try {
      await _repository.cancelReservation(classId: classId, userId: user.userId);
      
      final updatedClasses = await _repository.getClasses(fromDate: currentFromDate, toDate: currentToDate);
      final updatedItems = _mapClassesToItems(updatedClasses, user);
      
      emit(ScheduleOperationSuccess(
        message: 'Reserva cancelada.', 
        items: updatedItems
      ));

      emit(ScheduleLoaded(
        items: updatedItems, 
        selectedDate: backupDate,
        isOperationLoading: false,
      ));
      
    } catch (e) {
      emit(ScheduleError(e.toString().replaceAll('Exception: ', '')));

      if (backupItems.isNotEmpty) {
        emit(ScheduleLoaded(
          items: backupItems,
          selectedDate: backupDate,
          isOperationLoading: false,
        ));
      }
    }
  }
}