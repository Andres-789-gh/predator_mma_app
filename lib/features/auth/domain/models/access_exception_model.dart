import '../../../../features/plans/domain/models/plan_model.dart';

class AccessExceptionModel {
  final String id;
  final String? reason;
  final DateTime grantedAt; // fecha
  final String grantedBy; // id admin
  final int quantity; // cantidad ingresos
  final double price; // precio
  final DateTime? validUntil; // fecha vencimiento (opcional)
  final List<ScheduleRule> scheduleRules; // Guarda las reglas del plan original
  final String originalPlanName;

  const AccessExceptionModel({
    required this.id,
    this.reason,
    required this.grantedAt,
    required this.grantedBy,
    required this.scheduleRules,
    required this.originalPlanName,
    required this.quantity,
    required this.price,
    this.validUntil,
  });

  AccessExceptionModel copyWith({
    String? id,
    String? reason,
    DateTime? grantedAt,
    String? grantedBy,
    List<ScheduleRule>? scheduleRules,
    String? originalPlanName,

    int? quantity,
    double? price,
    DateTime? validUntil,
    bool clearValidUntil = false,
  }) {
    return AccessExceptionModel(
      id: id ?? this.id,
      reason: reason ?? this.reason,
      grantedAt: grantedAt ?? this.grantedAt,
      grantedBy: grantedBy ?? this.grantedBy,
      scheduleRules: scheduleRules ?? this.scheduleRules,
      originalPlanName: originalPlanName ?? this.originalPlanName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      validUntil: clearValidUntil ? null : (validUntil ?? this.validUntil),
    );
  }
}
