class ActivityModel {
  final String id;
  final String name; // nombre clase
  final String description; // descripcion opcional para el cliente

  const ActivityModel({
    required this.id,
    required this.name,
    this.description = '',
  });

  factory ActivityModel.fromMap(Map<String, dynamic> map, String docId) {
    return ActivityModel(
      id: docId,
      name: map['name'] ?? 'Clase',
      description: map['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
    };
  }
}