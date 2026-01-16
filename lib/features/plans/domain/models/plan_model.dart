import '../../../../core/constants/enums.dart';

class PlanModel {
  final String id;
  final String name;
  final double price;
  final bool isActive; 
  final PlanConsumptionType consumptionType; 
  final int? packClassesQuantity;
  final List<ScheduleRule> scheduleRules;

  PlanModel({
    required this.id,
    required this.name,
    required this.price,
    this.isActive = true,
    required this.consumptionType,
    this.packClassesQuantity,
    required this.scheduleRules,
  });

  PlanModel copyWith({
    String? id,
    String? name,
    double? price,
    bool? isActive,
    PlanConsumptionType? consumptionType,
    int? packClassesQuantity,
    List<ScheduleRule>? scheduleRules,
  }) {
    return PlanModel(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      isActive: isActive ?? this.isActive,
      consumptionType: consumptionType ?? this.consumptionType,
      packClassesQuantity: packClassesQuantity ?? this.packClassesQuantity,
      scheduleRules: scheduleRules ?? this.scheduleRules,
    );
  }
}

class ScheduleRule {
  final List<int> allowedDays; 
  final int startMinute; 
  final int endMinute;   

  // Categorías permitidas
  final List<ClassCategory> allowedCategories;

  ScheduleRule({
    required this.allowedDays,
    required this.startMinute,
    required this.endMinute,
    required this.allowedCategories,
  });

  // ¿permite entrar a esta clase?
  bool matchesClass(DateTime classDate, ClassCategory category) {
    // Valida Categoría
    if (!allowedCategories.contains(category)) return false;

    // Valida Día de la semana
    if (!allowedDays.contains(classDate.weekday)) return false;

    // Valida Horario
    final classMinute = classDate.hour * 60 + classDate.minute;
    if (classMinute < startMinute || classMinute > endMinute) return false;

    return true;
  }
}