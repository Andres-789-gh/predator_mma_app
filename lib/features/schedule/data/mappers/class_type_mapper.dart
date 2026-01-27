import '../../domain/models/class_type_model.dart';
import '../../../../core/constants/enums.dart';

class ClassTypeMapper {
  
  static ClassTypeModel fromMap(Map<String, dynamic> map, String docId) {
    
    final rawName = map['name'];
    final safeName = (rawName is String && rawName.isNotEmpty)
        ? rawName
        : 'Actividad sin nombre'; 
        
    final catString = map['category'] as String? ?? 'combat';
    final category = ClassCategory.values.firstWhere(
      (e) => e.name == catString,
      orElse: () => ClassCategory.combat,
    );

    return ClassTypeModel(
      id: docId,
      name: safeName,
      description: map['description'] ?? '',
      active: map['active'] ?? true, 
      category: category,
    );
  }

  static Map<String, dynamic> toMap(ClassTypeModel type) {
    return {
      'name': type.name,
      'description': type.description,
      'active': type.active,
      'category': type.category.name,
    };
  }
}