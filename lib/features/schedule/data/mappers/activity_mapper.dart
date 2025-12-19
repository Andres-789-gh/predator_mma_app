import '../../domain/models/activity_model.dart';

class ActivityMapper {
  
  static ActivityModel fromMap(Map<String, dynamic> map, String docId) {
    // saca el nombre crudo
    final rawName = map['name'];

    // asegura que el nombre sea texto y no null
    // si la bd esta corrupta y trae un numero o null, pone un texto por defecto
    final safeName = (rawName is String && rawName.isNotEmpty)
        ? rawName
        : 'Actividad sin nombre'; 

    return ActivityModel(
      id: docId,
      name: safeName,
      description: map['description'] ?? '',
    );
  }

  static Map<String, dynamic> toMap(ActivityModel activity) {
    return {
      'name': activity.name,
      'description': activity.description,
    };
  }
}