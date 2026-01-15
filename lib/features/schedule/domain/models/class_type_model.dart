class ClassTypeModel {
  final String id;
  final String name;
  final String description;
  final bool active;

  const ClassTypeModel({
    required this.id,
    required this.name,
    this.description = '',
    this.active = true,
  });

  ClassTypeModel copyWith({
    String? id,
    String? name,
    String? description,
    bool? active,
  }) {
    return ClassTypeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      active: active ?? this.active,
    );
  }
}