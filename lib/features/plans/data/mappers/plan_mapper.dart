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
    final rawDays = map['allowed_days'] ?? map['days'] ?? [];
    final rawCategories = map['allowed_categories'] ?? map['categories'] ?? [];

    return ScheduleRule(
      allowedDays: List<int>.from(rawDays),
      startMinute: map['start_minute'] ?? 0,
      endMinute: map['end_minute'] ?? 1440,
      allowedCategories: (rawCategories as List<dynamic>).map((e) {
        final cleanName = e.toString().contains('.')
            ? e.toString().split('.').last
            : e.toString();

        return ClassCategory.values.firstWhere(
          (c) => c.name == cleanName,
          orElse: () => ClassCategory.combat,
        );
      }).toList(),
    );
  }

  static Map<String, dynamic> toMap(ScheduleRule rule) {
    return {
      'allowed_days': rule.allowedDays,
      'start_minute': rule.startMinute,
      'end_minute': rule.endMinute,
      'allowed_categories': rule.allowedCategories.map((e) => e.name).toList(),
    };
  }
}
