import '../../../../core/constants/enums.dart';

class ClassTypeModel {
  final String id;
  final String name;
  final String description;
  final bool active;
  final ClassCategory category;

  const ClassTypeModel({
    required this.id,
    required this.name,
    this.description = '',
    this.active = true,
    this.category = ClassCategory.combat,
  });

  ClassTypeModel copyWith({
    String? id,
    String? name,
    String? description,
    bool? active,
    ClassCategory? category,
  }) {
    return ClassTypeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      active: active ?? this.active,
      category: category ?? this.category,
    );
  }
}
