import '../entities/sale_entity.dart';
import '../../data/repositories/sales_repository.dart';

class RegisterSaleUseCase {
  final SalesRepository _repository;

  RegisterSaleUseCase(this._repository);

  Future<void> execute(SaleEntity sale) async {
    if (sale.quantity <= 0) {
      throw Exception('la cantidad debe ser mayor a cero');
    }
    await _repository.registerSale(sale);
  }
}
