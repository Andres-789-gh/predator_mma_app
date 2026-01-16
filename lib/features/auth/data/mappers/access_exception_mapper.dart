import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/access_exception_model.dart';
import '../../../plans/data/mappers/plan_mapper.dart';

class AccessExceptionMapper {
  
  static AccessExceptionModel fromMap(Map<String, dynamic> map) {
    if (map['granted_at'] == null) {
      throw Exception('error critico: excepcion sin fecha');
    }

    double finalPrice = (map['price'] ?? 0).toDouble();
    if (finalPrice < 0) finalPrice = 0; // no precios negativos

    return AccessExceptionModel(
      id: map['id'] ?? '',
      reason: map['reason'],
      grantedAt: (map['granted_at'] as Timestamp).toDate(),
      grantedBy: map['granted_by'] ?? 'desconocido',
      
      scheduleRules: (map['schedule_rules'] as List<dynamic>?)
          ?.map((x) => ScheduleRuleMapper.fromMap(x))
          .toList() ?? [],
      originalPlanName: map['original_plan_name'] ?? 'Ingreso Extra',
      
      quantity: (map['quantity'] ?? 0).clamp(0, 999),
      price: finalPrice,
      
      validUntil: map['valid_until'] != null 
          ? (map['valid_until'] as Timestamp).toDate() 
          : null,
    );
  }

  static Map<String, dynamic> toMap(AccessExceptionModel model) {
    return {
      'id': model.id,
      'reason': model.reason,
      'granted_at': Timestamp.fromDate(model.grantedAt),
      'granted_by': model.grantedBy,
      'schedule_rules': model.scheduleRules
          .map((x) => ScheduleRuleMapper.toMap(x))
          .toList(),
      'original_plan_name': model.originalPlanName,
      'quantity': model.quantity,
      'price': model.price,
      'valid_until': model.validUntil != null 
          ? Timestamp.fromDate(model.validUntil!) 
          : null,
    };
  }
}