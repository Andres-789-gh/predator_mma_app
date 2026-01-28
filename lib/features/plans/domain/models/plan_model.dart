import 'package:equatable/equatable.dart';
import '../../../../core/constants/enums.dart';

class ScheduleRule extends Equatable {
  final List<int> allowedDays;
  final int startMinute;
  final int endMinute;
  final List<ClassCategory> allowedCategories;

  const ScheduleRule({
    required this.allowedDays,
    required this.startMinute,
    required this.endMinute,
    required this.allowedCategories,
  });

  bool matchesClass(DateTime classDate, ClassCategory category) {
    if (!allowedCategories.contains(category)) return false;
    if (!allowedDays.contains(classDate.weekday)) return false;
    final classMinute = classDate.hour * 60 + classDate.minute;
    if (classMinute < startMinute || classMinute > endMinute) return false;
    return true;
  }

  @override
  List<Object?> get props => [
    allowedDays,
    startMinute,
    endMinute,
    allowedCategories,
  ];
}

class PlanModel extends Equatable {
  final String id;
  final String name;
  final double price;
  final bool isActive;
  final PlanConsumptionType consumptionType;
  final int? packClassesQuantity;
  final int? dailyLimit;
  final List<ScheduleRule> scheduleRules;

  const PlanModel({
    required this.id,
    required this.name,
    required this.price,
    this.isActive = true,
    required this.consumptionType,
    this.packClassesQuantity,
    this.dailyLimit,
    required this.scheduleRules,
  });

  PlanModel copyWith({
    String? id,
    String? name,
    double? price,
    bool? isActive,
    PlanConsumptionType? consumptionType,
    int? packClassesQuantity,
    int? dailyLimit,
    List<ScheduleRule>? scheduleRules,
  }) {
    return PlanModel(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      isActive: isActive ?? this.isActive,
      consumptionType: consumptionType ?? this.consumptionType,
      packClassesQuantity: packClassesQuantity ?? this.packClassesQuantity,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      scheduleRules: scheduleRules ?? this.scheduleRules,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    price,
    isActive,
    consumptionType,
    packClassesQuantity,
    dailyLimit,
    scheduleRules,
  ];
}
