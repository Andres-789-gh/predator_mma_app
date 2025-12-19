import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/access_exception_model.dart';
import '../../../../core/constants/enums.dart';

class AccessExceptionMapper {
  
  // convierte de mapa (firebase) a modelo (dart)
  static AccessExceptionModel fromMap(Map<String, dynamic> map) {
    if (map['granted_at'] == null) {
      throw Exception('error critico: excepcion sin fecha');
    }

    double finalPrice = (map['price'] ?? 0).toDouble();
    if (finalPrice < 0) finalPrice = 0; // no precios negativos

    return AccessExceptionModel(
      id: map['id'] ?? '',
      reason: map['reason'],
      // Timestamp -> DateTime
      grantedAt: (map['granted_at'] as Timestamp).toDate(),
      grantedBy: map['granted_by'] ?? 'desconocido',
      
      validForPlan: PlanType.values.firstWhere(
        (e) => e.name == (map['valid_for_plan'] ?? 'full'),
        orElse: () => PlanType.full,
      ),
      
      quantity: (map['quantity'] ?? 0).clamp(0, 999),
      price: finalPrice,
      
      validUntil: map['valid_until'] != null 
          ? (map['valid_until'] as Timestamp).toDate() 
          : null,
    );
  }

  // convierte de modelo (dart) a mapa (firebase)
  static Map<String, dynamic> toMap(AccessExceptionModel model) {
    return {
      'id': model.id,
      'reason': model.reason,
      // DateTime -> Timestamp
      'granted_at': Timestamp.fromDate(model.grantedAt),
      'granted_by': model.grantedBy,
      'valid_for_plan': model.validForPlan.name,
      'quantity': model.quantity,
      'price': model.price,
      'valid_until': model.validUntil != null 
          ? Timestamp.fromDate(model.validUntil!) 
          : null,
    };
  }
}