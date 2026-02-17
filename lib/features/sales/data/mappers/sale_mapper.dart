import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/sale_entity.dart';

class SaleMapper {
  static SaleEntity fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return SaleEntity(
      id: doc.id,
      productId: data['product_id'] ?? '',
      productName: data['product_name'] ?? 'Producto Desconocido',
      productUnitPrice: (data['unit_price'] ?? 0).toDouble(),
      productUnitCost: (data['unit_cost'] ?? 0).toDouble(),
      quantity: (data['quantity'] ?? 1).toInt(),
      totalPrice: (data['total_price'] ?? 0).toDouble(),
      buyerId: data['buyer_id'],
      buyerName: data['buyer_name'] ?? 'Cliente Casual',
      paymentMethod: data['payment_method'] ?? 'Efectivo',
      saleDate: (data['sale_date'] as Timestamp).toDate(),
      note: data['note'],
      isService: data['is_service'] ?? false,
    );
  }

  static Map<String, dynamic> toMap(SaleEntity sale) {
    return {
      'product_id': sale.productId,
      'product_name': sale.productName,
      'unit_price': sale.productUnitPrice,
      'unit_cost': sale.productUnitCost,
      'quantity': sale.quantity,
      'total_price': sale.totalPrice,
      'buyer_id': sale.buyerId,
      'buyer_name': sale.buyerName,
      'payment_method': sale.paymentMethod,
      'sale_date': Timestamp.fromDate(sale.saleDate),
      'note': sale.note,
      'is_service': sale.isService,
    };
  }
}
