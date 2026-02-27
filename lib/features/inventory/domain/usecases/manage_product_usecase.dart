import '../entities/product_entity.dart';
import '../repositories/inventory_repository.dart';

// crea una excepcion personalizada para detectar el caso de "revivir"
class ProductInactiveException implements Exception {
  final String existingId;
  ProductInactiveException(this.existingId);
}

class ManageProductUseCase {
  final InventoryRepository _repository;

  ManageProductUseCase(this._repository);

  Future<void> executeSave(ProductEntity product) async {
    if (product.costPrice < 0) {
      throw Exception('El costo no puede ser negativo.');
    }
    if (product.salePrice < 0) {
      throw Exception('El precio no puede ser negativo.');
    }
    if (product.salePrice < product.costPrice) {
      throw Exception('El precio de venta no puede ser menor al costo.');
    }

    final existingProduct = await _repository.getProductByName(product.name);

    if (existingProduct != null) {
      if (product.id == existingProduct.id) {
      } else {
        if (!existingProduct.isActive) {
          throw ProductInactiveException(existingProduct.id);
        } else {
          throw Exception('Ya existe un producto con este nombre.');
        }
      }
    }

    await _repository.saveProduct(product);
  }

  Future<void> executeDelete(String productId) async {
    await _repository.deleteProduct(productId);
  }
}
