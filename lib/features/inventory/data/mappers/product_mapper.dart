import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/product_entity.dart';

class ProductMapper {
  static ProductEntity fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductEntity(
      id: doc.id,
      name: data['name'] ?? '',
      costPrice: (data['cost_price'] as num?)?.toDouble() ?? 0.0,
      salePrice: (data['sale_price'] as num?)?.toDouble() ?? 0.0,
      stock: data['stock'] as int?,
      createdAt: (data['created_at'] as Timestamp).toDate(),
      isActive: data['is_active'] ?? true,
    );
  }

  static Map<String, dynamic> toFirestore(ProductEntity product) {
    return {
      'name': product.name,
      'name_lowercase': product.name.toLowerCase(),
      'cost_price': product.costPrice,
      'sale_price': product.salePrice,
      'stock': product.stock,
      'created_at': Timestamp.fromDate(product.createdAt),
      'is_active': product.isActive,
    };
  }
}
