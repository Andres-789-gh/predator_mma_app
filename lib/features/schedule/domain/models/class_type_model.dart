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
}