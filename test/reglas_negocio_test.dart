import 'package:flutter_test/flutter_test.dart';
import 'package:predator_app/core/constants/enums.dart';
import 'package:predator_app/features/auth/domain/models/user_model.dart';
import 'package:predator_app/features/auth/domain/models/access_exception_model.dart';
import 'package:predator_app/features/schedule/domain/models/class_model.dart';


bool simulationDoesPlanAllowClass(UserModel user, ClassModel classModel) {
  final activePlan = user.activePlan;
  if (activePlan == null) return false;

  // Regla de Tiempo (Simulando la extensión canReserveNow)
  // Para el test asumimos que la fecha es válida, nos enfocamos en el PLAN.
  
  final PlanType planType = activePlan.type;

  // Regla Wild
  if (planType == PlanType.wild) {
    final minutes = classModel.startTime.hour * 60 + classModel.startTime.minute;
    if (minutes > 690) return false; // 11:30 AM
  }
  // Regla Kids
  if (planType == PlanType.kids) {
    final type = classModel.classType.toLowerCase();
    if (!type.contains('kids') && !type.contains('niños')) return false;
  }
  return true;
}

bool simulationCheckTickets(UserModel user, ClassModel classModel) {
  return user.accessExceptions.any((exc) {
    if (exc.quantity <= 0) return false;
    // Si el ticket es WILD, validamos hora
    if (exc.validForPlan == PlanType.wild) {
       final minutes = classModel.startTime.hour * 60 + classModel.startTime.minute;
       if (minutes > 690) return false;
    }
    return true;
  });
}

// --- TEST MAIN ---

void main() {
  group('Pruebas de Lógica de Negocio (Schedule)', () {
    
    // 1. Configurar datos de prueba
    final fechaBase = DateTime.now();
    
    // Clase de NOCHE (7:00 PM) - Adultos
    final claseNoche = ClassModel(
      classId: 'clase_noche', // CORREGIDO
      classType: 'Combate',   // CORREGIDO (Antes activityId)
      coachId: 'coach1',
      coachName: 'Profesor X', // AGREGADO (Requerido)
      startTime: DateTime(fechaBase.year, fechaBase.month, fechaBase.day, 19, 0), // 7 PM
      endTime: DateTime(fechaBase.year, fechaBase.month, fechaBase.day, 20, 0),
      maxCapacity: 20,
      attendees: [],
      waitlist: [],
    );

    // Clase de NIÑOS (5:00 PM)
    final claseKids = ClassModel(
      classId: 'clase_kids', // CORREGIDO
      classType: 'Kids JiuJitsu', // CORREGIDO
      coachId: 'coach1',
      coachName: 'Profesor X', // AGREGADO
      startTime: DateTime(fechaBase.year, fechaBase.month, fechaBase.day, 17, 0),
      endTime: DateTime(fechaBase.year, fechaBase.month, fechaBase.day, 18, 0),
      maxCapacity: 10,
      attendees: [],
      waitlist: [],
    );

    test('Usuario WILD no debe poder reservar de noche', () {
      final userWild = UserModel(
        userId: 'u1', email: 'test@test.com', firstName: 'Wild', lastName: 'User',
        documentId: '123', phoneNumber: '000', address: 'Cr 1', birthDate: DateTime(1990),
        emergencyContact: 'Mom',
        activePlan: UserPlan(
          type: PlanType.wild, 
          startDate: DateTime.now(), 
          endDate: DateTime.now().add(const Duration(days: 30))
        ),
      );

      final resultado = simulationDoesPlanAllowClass(userWild, claseNoche);
      expect(resultado, false, reason: 'El plan Wild debió bloquear la clase de las 7PM');
    });

    test('Usuario KIDS no debe poder reservar clase de Adultos', () {
      final userKids = UserModel(
        userId: 'u2', email: 'kid@test.com', firstName: 'Kid', lastName: 'User',
        documentId: '123', phoneNumber: '000', address: 'Cr 1', birthDate: DateTime(2015),
        emergencyContact: 'Mom',
        activePlan: UserPlan(
          type: PlanType.kids, 
          startDate: DateTime.now(), 
          endDate: DateTime.now().add(const Duration(days: 30))
        ),
      );

      final resultado = simulationDoesPlanAllowClass(userKids, claseNoche); // Clase Combate
      expect(resultado, false, reason: 'El plan Kids debió bloquear clase de Combate adultos');
    });

    test('Usuario WILD con TICKET FULL sí debe poder entrar de noche', () {
      final userWildConTicket = UserModel(
        userId: 'u3', email: 'ticket@test.com', firstName: 'Ticket', lastName: 'User',
        documentId: '123', phoneNumber: '000', address: 'Cr 1', birthDate: DateTime(1990),
        emergencyContact: 'Mom',
        activePlan: UserPlan(type: PlanType.wild, startDate: DateTime.now(), endDate: DateTime.now()),
        // TICKET MÁGICO
        accessExceptions: [
          AccessExceptionModel(
            id: 't1', grantedAt: DateTime.now(), grantedBy: 'admin',
            validForPlan: PlanType.full, // Ticket tipo Full (sirve de noche)
            quantity: 1, price: 0
          )
        ]
      );

      // 1. El plan debe fallar
      final planOk = simulationDoesPlanAllowClass(userWildConTicket, claseNoche);
      expect(planOk, false);

      // 2. El ticket debe salvarlo
      final ticketOk = simulationCheckTickets(userWildConTicket, claseNoche);
      expect(ticketOk, true, reason: 'El ticket Full debió permitir la entrada nocturna');
    });

    test('Usuario KIDS SI debe poder reservar clase de NIÑOS', () {
      final userKids = UserModel(
        userId: 'u2', email: 'kid@test.com', firstName: 'Kid', lastName: 'User',
        documentId: '123', phoneNumber: '000', address: 'Cr 1', birthDate: DateTime(2015),
        emergencyContact: 'Mom',
        activePlan: UserPlan(
          type: PlanType.kids, 
          startDate: DateTime.now(), 
          endDate: DateTime.now().add(const Duration(days: 30))
        ),
      );

      final resultado = simulationDoesPlanAllowClass(userKids, claseKids); 
      
      expect(resultado, true, reason: 'El plan Kids debe permitir reservar clases tipo Kids');
    });
  });
}