import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/sale_entity.dart';
import 'sales_repository.dart';

class SalesRepositoryImpl implements SalesRepository {
  final FirebaseFirestore _firestore;

  SalesRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> registerSale(SaleEntity sale) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // referencia producto inventario
        final productRef = _firestore
            .collection('inventory')
            .doc(sale.productId);
        final productDoc = await transaction.get(productRef);

        if (!productDoc.exists) {
          throw Exception('el producto ya no existe en inventario');
        }

        final currentStock = productDoc.data()?['stock'] as int?;

        // stock = se descuenta (no baja de 0)
        if (currentStock != null) {
          final newStock = (currentStock - sale.quantity) < 0
              ? 0
              : (currentStock - sale.quantity);
          transaction.update(productRef, {'stock': newStock});
        }

        final saleRef = _firestore.collection('sales').doc();
        transaction.set(saleRef, {
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
          'created_at': FieldValue.serverTimestamp(),
          'is_service': false,
        });
      });
    } catch (e) {
      throw Exception('error procesando la venta: $e');
    }
  }

  @override
  Future<void> registerServiceSale(SaleEntity sale) async {
    try {
      final saleRef = _firestore.collection('sales').doc();

      await saleRef.set({
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
        'created_at': FieldValue.serverTimestamp(),
        'is_service': true,
      });
    } catch (e) {
      throw Exception('error registrando venta de servicio: $e');
    }
  }
}
