import 'models/class_model.dart';
import '../../../../core/constants/enums.dart';

// extension clases
extension ClassBusinessRules on ClassModel {

  int get availableSlots => maxCapacity - attendees.length; // calcula cupo disponible
  bool get isFull => attendees.length >= maxCapacity; // clase llena?

  // clase ya paso?
  bool get hasFinished {
    final now = DateTime.now();
    return now.isAfter(endTime);
  }

  // revisa si el usuario ya tiene cupo confirmado
  bool isUserConfirmed(String userId) {
    return attendees.contains(userId);
  }

  // revisa si el usuario esta en lista de espera
  bool isUserOnWaitlist(String userId) {
    return waitlist.contains(userId);
  }

  // obtiene estado de reserva para mostrar btn correcto en pantalla
  BookingStatus getUserBookingStatus(String userId) {
    if (isUserConfirmed(userId)) return BookingStatus.confirmed;
    if (isUserOnWaitlist(userId)) return BookingStatus.waitlist;
    return BookingStatus.none; // sin reserva
  }

  // Tiempo y reserva clases

  // verifica que la clase no termine antes de empezar
  bool get hasValidDuration {
    return endTime.isAfter(startTime);
  }

  // logica de si se puede reservar en este instante
  bool get canReserveNow {
    final now = DateTime.now();

    // si ya empezo no
    if (now.isAfter(startTime)) return false;

    // calcula la distancia en dias (0 = hoy, 1 = mañana)
    final today = DateTime(now.year, now.month, now.day);
    final classDate = DateTime(startTime.year, startTime.month, startTime.day);
    final daysDifference = classDate.difference(today).inDays;

    // no reservar muy a futuro (max mañana, mas alla paila)
    if (daysDifference > 1) return false;

    // detecta tipos de clase especiales
    final isSpecial = classType.toLowerCase().contains('virtual') || 
                      classType.toLowerCase().contains('personalizada');
    
    // si es clase especial, no puede reservar el mismo dia (dia 0), tiene que ser con un dia de anticipacion
    if (isSpecial && daysDifference == 0) return false;

    // calculo de la hora deadline
    final isMorningClass = startTime.hour < 12;
    DateTime deadline;

    // si son clases en la mañana o especiales
    if (isSpecial || isMorningClass) {      
      // corte a las 11:59:59 pm de hoy (dia anterior a la clase)
      final dayBefore = startTime.subtract(const Duration(days: 1));
      deadline = DateTime(dayBefore.year, dayBefore.month, dayBefore.day, 23, 59, 59);

    } else { // clases normales tarde/noche
      // corte a las 12:00:00 pm mediodia del mismo día
      deadline = DateTime(startTime.year, startTime.month, startTime.day, 12, 0, 0);
    }

    // si la hora actual ya paso la fecha limite no deja reservar
    return now.isBefore(deadline);
  }

  bool get canCancelNow {
    final now = DateTime.now();
    if (now.isAfter(startTime)) return false;
    return true; 
  }
}