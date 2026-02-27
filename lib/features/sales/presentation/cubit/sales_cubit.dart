import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/sale_entity.dart';
import '../../domain/usecases/register_sale_usecase.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../../core/constants/enums.dart';
import 'sales_state.dart';

class SalesCubit extends Cubit<SalesState> {
  final RegisterSaleUseCase _registerSaleUseCase;
  final AuthRepository _authRepository;

  SalesCubit(this._registerSaleUseCase, this._authRepository)
    : super(const SalesState());

  // obtiene listado de clientes
  Future<void> loadUsers() async {
    if (isClosed) return;
    emit(state.copyWith(status: SalesStatus.loadingUsers));

    try {
      final allUsers = await _authRepository.getAllUsers();
      if (isClosed) return;

      final clientsOnly = allUsers
          .where((u) => u.role != UserRole.admin)
          .toList();

      emit(state.copyWith(status: SalesStatus.ready, users: clientsOnly));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: SalesStatus.failure,
          errorMessage: 'error cargando usuarios',
        ),
      );
    }
  }

  // registra venta en sistema
  Future<void> submitSale(SaleEntity sale) async {
    if (isClosed) return;
    emit(state.copyWith(status: SalesStatus.processing));

    try {
      await _registerSaleUseCase.execute(sale);
      if (isClosed) return;
      emit(state.copyWith(status: SalesStatus.success));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(status: SalesStatus.failure, errorMessage: e.toString()),
      );
    }
  }
}
