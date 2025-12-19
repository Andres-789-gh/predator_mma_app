import '../../../../core/constants/enums.dart';

class AccessExceptionModel {
  final String id;
  final String? reason; 
  final DateTime grantedAt; // fecha
  final String grantedBy; // id admin
  final PlanType validForPlan; // para que tipo de plan/clases sirve el ingreso extra
  final int quantity; // cantidad ingresos
  final double price; // precio
  final DateTime? validUntil; // fecha vencimiento (opcional)

  const AccessExceptionModel({
    required this.id,
    this.reason,
    required this.grantedAt,
    required this.grantedBy,
    required this.validForPlan,
    required this.quantity,
    required this.price,
    this.validUntil,
  });
  
  // CopyWith pa' poder corregir errores
  AccessExceptionModel copyWith({
    String? id,
    String? reason,
    DateTime? grantedAt,
    String? grantedBy,
    PlanType? validForPlan,
    int? quantity,
    double? price,
    DateTime? validUntil,
    // flag para forzar el borrado de la fecha (ponerla en null)
    bool clearValidUntil = false,
  }) {
    return AccessExceptionModel(
      id: id ?? this.id,
      reason: reason ?? this.reason,
      grantedAt: grantedAt ?? this.grantedAt,
      grantedBy: grantedBy ?? this.grantedBy,
      validForPlan: validForPlan ?? this.validForPlan,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      // si clearValidUntil es true, fuerza null. si no, mira si llego fecha nueva o deja la vieja.
      validUntil: clearValidUntil ? null : (validUntil ?? this.validUntil),
    );
  }
}