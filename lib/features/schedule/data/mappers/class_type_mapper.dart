import '../../domain/models/class_type_model.dart';

class ClassTypeMapper {
  
  static ClassTypeModel fromMap(Map<String, dynamic> map, String docId) {
    
    final rawName = map['name'];
    final safeName = (rawName is String && rawName.isNotEmpty)
        ? rawName
        : 'Actividad sin nombre'; 

    return ClassTypeModel(
      id: docId,
      name: safeName,
      description: map['description'] ?? '',
      active: map['active'] ?? true, 
    );
  }

  static Map<String, dynamic> toMap(ClassTypeModel type) {
    return {
      'name': type.name,
      'description': type.description,
      'active': type.active,
    };
  }
}