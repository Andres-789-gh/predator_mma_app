import 'package:equatable/equatable.dart';

class ProductEntity extends Equatable {
  final String id;
  final String name;
  final double costPrice;
  final double salePrice;
  final int? stock;
  final DateTime createdAt;
  final bool isActive;

  const ProductEntity({
    required this.id,
    required this.name,
    required this.costPrice,
    required this.salePrice,
    this.stock,
    required this.createdAt,
    this.isActive = true,
  });

  // calcula ganancia neta del producto
  double get profit => salePrice - costPrice;

  // inventario físico?
  bool get hasInfiniteStock => stock == null;

  ProductEntity copyWith({
    String? id,
    String? name,
    double? costPrice,
    double? salePrice,
    int? stock,
    DateTime? createdAt,
    bool? isActive,
    bool setStockToNull = false,
  }) {
    return ProductEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      costPrice: costPrice ?? this.costPrice,
      salePrice: salePrice ?? this.salePrice,
      stock: setStockToNull ? null : (stock ?? this.stock),
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    costPrice,
    salePrice,
    stock,
    createdAt,
    isActive,
  ];
}
