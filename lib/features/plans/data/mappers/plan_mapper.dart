import '../../domain/models/plan_model.dart';
import '../../../../core/constants/enums.dart';

class PlanMapper {
  static PlanModel fromMap(Map<String, dynamic> map, String id) {
    return PlanModel(
      id: id,
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      isActive: map['is_active'] ?? true,

      consumptionType: PlanConsumptionType.values.firstWhere(
        (e) => e.name == (map['consumption_type'] ?? 'limitedDaily'),
        orElse: () => PlanConsumptionType.limitedDaily,
      ),

      dailyLimit: map['daily_limit'] as int?,
      packClassesQuantity: map['pack_quantity'],
      scheduleRules:
          (map['schedule_rules'] as List<dynamic>?)
              ?.map((x) => ScheduleRuleMapper.fromMap(x))
              .toList() ??
          [],
    );
  }

  static Map<String, dynamic> toMap(PlanModel plan) {
    return {
      'name': plan.name,
      'price': plan.price,
      'is_active': plan.isActive,
      'consumption_type': plan.consumptionType.name,
      'daily_limit': plan.dailyLimit,
      'pack_quantity': plan.packClassesQuantity,
      'schedule_rules': plan.scheduleRules
          .map((x) => ScheduleRuleMapper.toMap(x))
          .toList(),
    };
  }
}

class ScheduleRuleMapper {
  static ScheduleRule fromMap(Map<String, dynamic> map) {
    return ScheduleRule(
      allowedDays: List<int>.from(map['days'] ?? []),
      startMinute: map['start_minute'] ?? 0,
      endMinute: map['end_minute'] ?? 1440,
      allowedCategories:
          (map['categories'] as List<dynamic>?)
              ?.map(
                (e) => ClassCategory.values.firstWhere(
                  (c) => c.name == e,
                  orElse: () => ClassCategory.combat,
                ),
              )
              .toList() ??
          [],
    );
  }

  static Map<String, dynamic> toMap(ScheduleRule rule) {
    return {
      'days': rule.allowedDays,
      'start_minute': rule.startMinute,
      'end_minute': rule.endMinute,
      'categories': rule.allowedCategories.map((e) => e.name).toList(),
    };
  }
}
