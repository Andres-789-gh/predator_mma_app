import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../sales/data/mappers/sale_mapper.dart';
import '../../../sales/domain/entities/sale_entity.dart';

class ReportsRepository {
  final FirebaseFirestore _firestore;

  ReportsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<SaleEntity>> getSalesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final start = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        0,
        0,
        0,
      );
      final end = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        23,
        59,
        59,
      );

      final snapshot = await _firestore
          .collection('sales')
          .where('sale_date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('sale_date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('sale_date', descending: true)
          .get();

      return snapshot.docs.map((doc) => SaleMapper.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('error consultando ventas para reporte: $e');
    }
  }
}
