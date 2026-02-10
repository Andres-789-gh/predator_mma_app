import 'package:equatable/equatable.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/enums/inventory_sort_type.dart';

enum InventoryStatus { initial, loading, success, failure }

class InventoryState extends Equatable {
  final InventoryStatus status;
  final List<ProductEntity> products;
  final bool hasReachedMax;
  final InventorySortType currentSort;
  final String searchQuery;
  final String? errorMessage;

  const InventoryState({
    this.status = InventoryStatus.initial,
    this.products = const [],
    this.hasReachedMax = false,
    this.currentSort = InventorySortType.byNameAsc,
    this.searchQuery = '',
    this.errorMessage,
  });

  InventoryState copyWith({
    InventoryStatus? status,
    List<ProductEntity>? products,
    bool? hasReachedMax,
    InventorySortType? currentSort,
    String? searchQuery,
    String? errorMessage,
  }) {
    return InventoryState(
      status: status ?? this.status,
      products: products ?? this.products,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      currentSort: currentSort ?? this.currentSort,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    products,
    hasReachedMax,
    currentSort,
    searchQuery,
    errorMessage,
  ];
}
