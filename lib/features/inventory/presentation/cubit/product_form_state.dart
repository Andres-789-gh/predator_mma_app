import 'package:equatable/equatable.dart';

enum ProductFormStatus { initial, loading, success, failure, askRevive }

class ProductFormState extends Equatable {
  final ProductFormStatus status;
  final String? errorMessage;
  final String? existingProductId;

  const ProductFormState({
    this.status = ProductFormStatus.initial,
    this.errorMessage,
    this.existingProductId,
  });

  ProductFormState copyWith({
    ProductFormStatus? status,
    String? errorMessage,
    String? existingProductId,
  }) {
    return ProductFormState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      existingProductId: existingProductId ?? this.existingProductId,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage, existingProductId];
}
