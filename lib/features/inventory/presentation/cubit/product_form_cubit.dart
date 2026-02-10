import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/usecases/manage_product_usecase.dart';
import 'product_form_state.dart';

class ProductFormCubit extends Cubit<ProductFormState> {
  final ManageProductUseCase _manageProductUseCase;

  ProductFormCubit(this._manageProductUseCase)
    : super(const ProductFormState());

  Future<void> saveProduct(ProductEntity product) async {
    if (isClosed) return;
    emit(const ProductFormState(status: ProductFormStatus.loading));

    try {
      await _manageProductUseCase.executeSave(product);
      if (isClosed) return;
      emit(const ProductFormState(status: ProductFormStatus.success));
    } on ProductInactiveException catch (e) {
      emit(
        ProductFormState(
          status: ProductFormStatus.askRevive,
          existingProductId: e.existingId,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        ProductFormState(
          status: ProductFormStatus.failure,
          errorMessage: e
              .toString(),
        ),
      );
    }
  }

  // revivir desactivado
  Future<void> reviveProduct(String oldId, ProductEntity newProductData) async {
    final revivedProduct = newProductData.copyWith(id: oldId, isActive: true);
    await saveProduct(revivedProduct);
  }

  Future<void> deleteProduct(String productId) async {
    if (isClosed) return;
    emit(const ProductFormState(status: ProductFormStatus.loading));

    try {
      await _manageProductUseCase.executeDelete(productId);
      if (isClosed) return;
      emit(const ProductFormState(status: ProductFormStatus.success));
    } catch (e) {
      if (isClosed) return;
      emit(
        ProductFormState(
          status: ProductFormStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
