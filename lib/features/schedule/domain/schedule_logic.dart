import 'models/class_model.dart';

class ScheduleLogic {

  // busca conflicto de horario entre una clase nueva y las existentes
  static ClassModel? findConflict(ClassModel newClass, List<ClassModel> existingClasses) {
    
    for (var existing in existingClasses) {
      
      // formula de solapamiento (verifica si los tiempos se cruzan)
      // condicion: (nuevo_inicio < viejo_fin) Y (nuevo_fin > viejo_inicio)
      
      if (newClass.startTime.isBefore(existing.endTime) && 
          newClass.endTime.isAfter(existing.startTime)) {
        return existing; // retorna la clase que estorba
      }
    }
    
    return null; // null = no hay conflicto
  }
}