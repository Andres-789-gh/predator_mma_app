import 'models/user_model.dart';

extension UserBusinessRules on UserModel {
  // verifica si es menor de edad
  bool isMinor({DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();
    return _calculateAge(now) < 18;
  }

  // calcula edad exacta
  int _calculateAge(DateTime referenceDate) {
    int age = referenceDate.year - birthDate.year;

    if (referenceDate.month < birthDate.month ||
        (referenceDate.month == birthDate.month &&
            referenceDate.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  // verifica si tiene al menos un plan activo
  bool get hasActivePlan {
    if (activePlans.isEmpty) return false;

    final now = DateTime.now();
    return activePlans.any((plan) => plan.isActive(now));
  }

  // calcula dias hasta vencimiento del plan mas proximo
  int get daysUntilExpiration {
    if (activePlans.isEmpty) return 0;

    final now = DateTime.now();
    final validPlans = activePlans.where((p) => p.isActive(now)).toList();

    if (validPlans.isEmpty) return 0;

    validPlans.sort((a, b) => a.effectiveEndDate.compareTo(b.effectiveEndDate));
    return validPlans.first.effectiveEndDate.difference(now).inDays;
  }

  // determina si mostrar alerta de vencimiento
  bool get shouldShowExpirationWarning {
    if (!hasActivePlan) return false;
    final days = daysUntilExpiration;
    return days >= 0 && days <= 5;
  }

  // valida si cumple requisitos para reservar
  bool get canReserveClass {
    if (!hasActivePlan) return false;
    if (!isWaiverSigned) return false;
    return true;
  }
}
