import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/usecases/generate_excel_report_usecase.dart';

// estados
abstract class ReportState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ReportInitial extends ReportState {}

class ReportLoading extends ReportState {}

class ReportSuccess extends ReportState {}

class ReportError extends ReportState {
  final String message;
  ReportError(this.message);
  @override
  List<Object?> get props => [message];
}

class ReportCubit extends Cubit<ReportState> {
  final GenerateExcelReportUseCase _generateExcelUseCase;

  ReportCubit(this._generateExcelUseCase) : super(ReportInitial());

  Future<void> generateReport(DateTime start, DateTime end) async {
    if (end.difference(start).inDays > 90) {
      emit(
        ReportError("El rango máximo permitido es de 90 días por rendimiento."),
      );
      return;
    }

    try {
      emit(ReportLoading());
      await _generateExcelUseCase.execute(startDate: start, endDate: end);
      emit(ReportSuccess());
    } catch (e) {
      emit(ReportError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
