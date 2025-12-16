import 'models/user_model.dart';

// Extension: le agrega funciones al usermodel sin modificar el archivo original (reglas de negocio)
extension UserBusinessRules on UserModel {

  // funcion para calcular si es menor de edad
  bool isMinor({DateTime? referenceDate}) {
    // si no dan una fecha referencia, usa la fecha de hoy
    final now = referenceDate ?? DateTime.now();
    return _calculateAge(now) < 18;
  }

  // funcion privada para calcular la edad exacta
  int _calculateAge(DateTime referenceDate) {
    int age = referenceDate.year - birthDate.year;

    // si aun no ha cumplido años este año, le resta 1 a la edad
    if (referenceDate.month < birthDate.month || 
       (referenceDate.month == birthDate.month && referenceDate.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  // verifica si el plan esta pausado el dia de hoy
  bool get isPlanPausedToday {
    // si no tiene plan o no tiene pausas registradas, pues no esta pausado
    if (activePlan == null) return false;
    if (activePlan!.pauses.isEmpty) return false;

    final now = DateTime.now();
    
    // revisa lista de pausas una por una
    for (var pause in activePlan!.pauses) {
      // si hoy esta despues del inicio Y antes del final de la pausa
      if (now.isAfter(pause.startDate) && now.isBefore(pause.endDate)) {
        return true;
      }
      // si hoy es el dia de inicio o fin
      if (_isSameDay(now, pause.startDate) || _isSameDay(now, pause.endDate)) {
        return true;
      }
    }
    // si no coincidio con ninguna pausa, plan corre normal
    return false;
  }

  // verificar si tiene un plan activo, que no haya vencido y que no este pausado
  bool get hasActivePlan {
    if (activePlan == null) return false;
    
    // si hoy esta pausado, cuenta como inactivo para reservar
    if (isPlanPausedToday) return false;
    
    final now = DateTime.now();
    // verifica que la fecha actual sea antes de la fecha de fin
    return now.isBefore(activePlan!.endDate);
  }

  // calcula cuantos dias faltan para que se venza el plan
  int get daysUntilExpiration {
    if (activePlan == null) return 0;
    
    final now = DateTime.now();
    // devuelve la diferencia en dias
    return activePlan!.endDate.difference(now).inDays;
  }

  // define si debe mostrar la alerta de vencimiento (ej: faltan 5 dias)
  bool get shouldShowExpirationWarning {
    if (!hasActivePlan) return false;
    final days = daysUntilExpiration;
    return days >= 0 && days <= 5;
  }

  // regla: puede reservar clase?
  bool get canReserveClass {
    // debe tener plan activo (y no pausado)
    if (!hasActivePlan) return false;

    // debe haber firmado la exoneracion
    if (!isWaiverSigned) return false;

    return true;
  }
  
  // ayuda para comparar fechas ignorando la hora exacta
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}