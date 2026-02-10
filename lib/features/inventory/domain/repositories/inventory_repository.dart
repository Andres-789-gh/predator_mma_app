import '../entities/product_entity.dart';
import '../enums/inventory_sort_type.dart';

abstract class InventoryRepository {
  Future<void> saveProduct(ProductEntity product);

  Future<List<ProductEntity>> getProducts({
    required int limit,
    required InventorySortType sortType,
    ProductEntity? lastProduct,
  });

  Future<List<ProductEntity>> searchProducts({
    required String query,
    required int limit,
    ProductEntity? lastProduct,
  });

  Future<void> deleteProduct(String productId);
  Future<ProductEntity?> getProductByName(String name);
}
