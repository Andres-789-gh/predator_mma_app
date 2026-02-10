import '../../domain/entities/sale_entity.dart';

abstract class SalesRepository {
  Future<void> registerSale(SaleEntity sale);
}
