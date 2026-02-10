import 'package:equatable/equatable.dart';

class SaleEntity extends Equatable {
  final String id;
  final String productId;
  final String productName;
  final double productUnitPrice;
  final double productUnitCost;
  final int quantity;
  final double totalPrice;
  final String? buyerId;
  final String? buyerName;
  final String paymentMethod;
  final DateTime saleDate;
  final String? note;

  const SaleEntity({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productUnitPrice,
    required this.productUnitCost,
    required this.quantity,
    required this.totalPrice,
    this.buyerId,
    this.buyerName,
    required this.paymentMethod,
    required this.saleDate,
    this.note,
  });

  @override
  List<Object?> get props => [
    id,
    productId,
    productName,
    productUnitPrice,
    productUnitCost,
    quantity,
    totalPrice,
    buyerId,
    buyerName,
    paymentMethod,
    saleDate,
    note,
  ];
}
