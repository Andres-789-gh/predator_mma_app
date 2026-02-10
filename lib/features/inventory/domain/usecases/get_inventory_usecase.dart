import '../entities/product_entity.dart';
import '../enums/inventory_sort_type.dart';
import '../repositories/inventory_repository.dart';

class GetInventoryUseCase {
  final InventoryRepository _repository;

  GetInventoryUseCase(this._repository);

  Future<List<ProductEntity>> execute({
    required int limit,
    required InventorySortType sortType,
    String? searchQuery,
    ProductEntity? lastProduct,
  }) {
    // búsqueda o listado normal
    if (searchQuery != null && searchQuery.isNotEmpty) {
      return _repository.searchProducts(
        query: searchQuery,
        limit: limit,
        lastProduct: lastProduct,
      );
    }

    // retorna listado normal
    return _repository.getProducts(
      limit: limit,
      sortType: sortType,
      lastProduct: lastProduct,
    );
  }
}
