class ActivityModel {
  final String id;
  final String name; // nombre clase
  final String description; // descripcion opcional para el cliente

  const ActivityModel({
    required this.id,
    required this.name,
    this.description = '',
  });
}