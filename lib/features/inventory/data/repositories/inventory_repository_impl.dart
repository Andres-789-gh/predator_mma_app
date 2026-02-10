import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/enums/inventory_sort_type.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../mappers/product_mapper.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  final FirebaseFirestore _firestore;

  InventoryRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> saveProduct(ProductEntity product) async {
    try {
      final docRef = _firestore
          .collection('inventory')
          .doc(product.id.isEmpty ? null : product.id);
      // asegura id consistente si es nuevo
      final productToSave = product.id.isEmpty
          ? product.copyWith(id: docRef.id)
          : product;

      await docRef.set(
        ProductMapper.toFirestore(productToSave),
        SetOptions(merge: true),
      );
    } catch (e) {
      throw Exception('error al guardar producto: $e');
    }
  }

  @override
  Future<void> deleteProduct(String productId) async {
    try {
      await _firestore.collection('inventory').doc(productId).update({
        'is_active': false,
      });
    } catch (e) {
      throw Exception('error al desactivar producto: $e');
    }
  }

  @override
  Future<List<ProductEntity>> getProducts({
    required int limit,
    required InventorySortType sortType,
    ProductEntity? lastProduct,
  }) async {
    try {
      Query query = _firestore
          .collection('inventory')
          .where('is_active', isEqualTo: true);

      // ordenamiento segun tipo
      switch (sortType) {
        case InventorySortType.byNameAsc:
          query = query.orderBy('name_lowercase', descending: false);
          break;
        case InventorySortType.byNameDesc:
          query = query.orderBy('name_lowercase', descending: true);
          break;
        case InventorySortType.byDateNewest:
          query = query.orderBy('created_at', descending: true);
          break;
        case InventorySortType.byDateOldest:
          query = query.orderBy('created_at', descending: false);
          break;
        case InventorySortType.byStockHigh:
          query = query.orderBy('stock', descending: true);
          break;
        case InventorySortType.byStockLow:
          query = query.orderBy('stock', descending: false);
          break;
      }

      // ordenamiento secundario por id
      query = query.orderBy(FieldPath.documentId);

      // paginacion si hay elemento previo
      if (lastProduct != null) {
        final cursorValues = _getCursorValues(sortType, lastProduct);
        query = query.startAfter(cursorValues);
      }

      final snapshot = await query.limit(limit).get();
      return snapshot.docs.map(ProductMapper.fromFirestore).toList();
    } catch (e) {
      throw Exception('error al obtener inventario: $e');
    }
  }

  @override
  Future<ProductEntity?> getProductByName(String name) async {
    try {
      final snapshot = await _firestore
          .collection('inventory')
          .where('name_lowercase', isEqualTo: name.toLowerCase())
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return ProductMapper.fromFirestore(snapshot.docs.first);
    } catch (e) {
      throw Exception('error validando nombre: $e');
    }
  }

  @override
  Future<List<ProductEntity>> searchProducts({
    required String query,
    required int limit,
    ProductEntity? lastProduct,
  }) async {
    try {
      // normalizar texto
      final searchTerm = query.toLowerCase();

      // configura query de rango para simular 'starts with'
      Query firestoreQuery = _firestore
          .collection('inventory')
          .where('is_active', isEqualTo: true)
          .orderBy('name_lowercase')
          .startAt([searchTerm])
          .endAt(['$searchTerm\uf8ff']);

      // paginacion especifica para busqueda
      if (lastProduct != null) {
        firestoreQuery = firestoreQuery.startAfter([
          lastProduct.name.toLowerCase(),
        ]);
      }

      final snapshot = await firestoreQuery.limit(limit).get();
      return snapshot.docs.map(ProductMapper.fromFirestore).toList();
    } catch (e) {
      throw Exception('error en busqueda de productos: $e');
    }
  }

  // genera valores del cursor segun el ordenamiento activo
  List<dynamic> _getCursorValues(
    InventorySortType sortType,
    ProductEntity product,
  ) {
    switch (sortType) {
      case InventorySortType.byNameAsc:
      case InventorySortType.byNameDesc:
        return [product.name.toLowerCase(), product.id];
      case InventorySortType.byDateNewest:
      case InventorySortType.byDateOldest:
        return [Timestamp.fromDate(product.createdAt), product.id];
      case InventorySortType.byStockHigh:
      case InventorySortType.byStockLow:
        return [product.stock, product.id];
    }
  }
}
