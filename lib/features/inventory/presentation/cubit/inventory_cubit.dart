import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/enums/inventory_sort_type.dart';
import '../../domain/usecases/get_inventory_usecase.dart';
import 'inventory_state.dart';

class InventoryCubit extends Cubit<InventoryState> {
  final GetInventoryUseCase _getInventoryUseCase;
  Timer? _debounceTimer;

  InventoryCubit(this._getInventoryUseCase) : super(const InventoryState());

  // obtiene carga inicial
  Future<void> loadInitialData() async {
    if (isClosed) return;

    emit(
      state.copyWith(
        status: InventoryStatus.loading,
        products: [],
        hasReachedMax: false,
        errorMessage: null,
      ),
    );

    try {
      final newProducts = await _getInventoryUseCase.execute(
        limit: 15,
        sortType: state.currentSort,
        searchQuery: state.searchQuery,
      );

      if (isClosed) return;

      emit(
        state.copyWith(
          status: InventoryStatus.success,
          products: newProducts,
          hasReachedMax: newProducts.length < 15,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: InventoryStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  // obtiene siguiente pagina
  Future<void> loadNextPage() async {
    if (state.hasReachedMax ||
        state.status == InventoryStatus.loading ||
        isClosed) {
      return;
    }

    try {
      final lastProduct = state.products.isNotEmpty
          ? state.products.last
          : null;

      final nextProducts = await _getInventoryUseCase.execute(
        limit: 15,
        sortType: state.currentSort,
        searchQuery: state.searchQuery,
        lastProduct: lastProduct,
      );

      if (isClosed) return;

      emit(
        state.copyWith(
          products: List.of(state.products)..addAll(nextProducts),
          hasReachedMax: nextProducts.length < 15,
        ),
      );
    } catch (e) {
      debugPrint('Error en paginacion: $e');
    }
  }

  // actualiza ordenamiento
  void changeSort(InventorySortType newSort) {
    if (state.currentSort == newSort) return;

    emit(state.copyWith(currentSort: newSort));
    loadInitialData();
  }

  // controla busqueda en tiempo real
  void onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (isClosed) return;
      if (state.searchQuery == query) return;

      emit(state.copyWith(searchQuery: query));
      loadInitialData();
    });
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
