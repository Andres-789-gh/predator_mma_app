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

  // verifica existencia de plan activo
  bool get hasActivePlan {
    if (currentPlans.isEmpty) return false;

    final now = DateTime.now();
    return currentPlans.any((plan) => plan.isActive(now));
  }

  // calcula dias restantes del plan mas cercano
  int get daysUntilExpiration {
    if (currentPlans.isEmpty) return 0;

    final now = DateTime.now();
    final validPlans = currentPlans.where((p) => p.isActive(now)).toList();

    if (validPlans.isEmpty) return 0;

    validPlans.sort((a, b) => a.effectiveEndDate.compareTo(b.effectiveEndDate));
    return validPlans.first.effectiveEndDate.difference(now).inDays;
  }

  // evalua necesidad de mostrar alerta
  bool get shouldShowExpirationWarning {
    if (!hasActivePlan) return false;
    final days = daysUntilExpiration;
    return days >= 0 && days <= 5;
  }

  // valida requisitos de reserva
  bool get canReserveClass {
    if (!hasActivePlan) return false;
    if (!isWaiverSigned) return false;
    return true;
  }
}
