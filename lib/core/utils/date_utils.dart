class AppDateUtils {
  /* 
  Calcula la fecha de fin de un plan tipo Mensualidad
  Misma fecha del próximo mes, menos 1 día
  Ej: 7 Enero + 1 mes -> 6 Febrero
   */
  static DateTime calculateGymEndDate(DateTime start, int months) {
    final int year = start.year + ((start.month + months - 1) ~/ 12);
    final int month = (start.month + months - 1) % 12 + 1;
    final int lastDay = DateTime(year, month + 1, 0).day;

    if (start.day <= lastDay) {
      return DateTime(year, month, start.day).subtract(const Duration(days: 1));
    }

    // Si el día original no existe en el mes destino (ej: 31), usa último día
    return DateTime(year, month, lastDay);
  }
}
