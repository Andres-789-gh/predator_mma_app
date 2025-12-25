/*
import 'package:cloud_firestore/cloud_firestore.dart';

class DataSeeder {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> seedWeekClasses() async {
    final batch = _firestore.batch(); // Para subir todo de un golpe
    final now = DateTime.now();
    
    // Generamos clases para hoy y los próximos 3 días
    for (int i = 0; i < 4; i++) {
      final date = now.add(Duration(days: i));
      
      // 1. CLASE MAÑANA (7:00 AM) - Ideal para Plan Wild
      final morningRef = _firestore.collection('classes').doc();
      batch.set(morningRef, {
        'class_type': 'Muay Thai (Wild)',
        'coach_name': 'Kru Juan',
        'coach_id': 'coach_01',
        'max_capacity': 20,
        'start_time': Timestamp.fromDate(DateTime(date.year, date.month, date.day, 7, 0)),
        'end_time': Timestamp.fromDate(DateTime(date.year, date.month, date.day, 8, 30)),
        'attendees': [],
        'waitlist': [],
        'is_cancelled': false,
      });

      // 2. CLASE NOCHE (7:00 PM) - Plan Wild debería fallar aquí (o pedir ticket)
      final eveningRef = _firestore.collection('classes').doc();
      batch.set(eveningRef, {
        'class_type': 'Jiu Jitsu (General)',
        'coach_name': 'Sensei Pedro',
        'coach_id': 'coach_02',
        'max_capacity': 20,
        'start_time': Timestamp.fromDate(DateTime(date.year, date.month, date.day, 19, 0)),
        'end_time': Timestamp.fromDate(DateTime(date.year, date.month, date.day, 20, 30)),
        'attendees': [],
        'waitlist': [],
        'is_cancelled': false,
      });

      // 3. CLASE LLENA (6:00 PM) - Para probar UI de "Lleno"
      // Llenamos el array de attendees artificialmente
      final fullClassRef = _firestore.collection('classes').doc();
      List<String> fakeAttendees = List.generate(15, (index) => 'user_$index');
      
      batch.set(fullClassRef, {
        'class_type': 'Boxeo (Lleno)',
        'coach_name': 'Profe Carlos',
        'coach_id': 'coach_03',
        'max_capacity': 15, // Capacidad igual a asistentes
        'start_time': Timestamp.fromDate(DateTime(date.year, date.month, date.day, 18, 0)),
        'end_time': Timestamp.fromDate(DateTime(date.year, date.month, date.day, 19, 0)),
        'attendees': fakeAttendees, // <--- LLENO
        'waitlist': [],
        'is_cancelled': false,
      });
    }

    await batch.commit();
    print("✅ ¡SEMBRADO! Clases creadas para 4 días.");
  }

  // ... (tu código anterior seedWeekClasses sigue ahí)

  // 👇 NUEVA FUNCIÓN PARA ASIGNARTE UN PLAN
  Future<void> assignTestPlan(String userId, String planType) async {
    final now = DateTime.now();
    final nextMonth = now.add(const Duration(days: 30));

    // Estructura del mapa 'active_plan'
    final Map<String, dynamic> planData = {
      'id': 'test_plan_${planType}_001',
      'type': planType, // 'wild', 'full', 'unlimited'
      'name': 'Plan Test ${planType.toUpperCase()}',
      'start_date': Timestamp.fromDate(now),
      'end_date': Timestamp.fromDate(nextMonth),
      'price': 0,
      'status': 'active', // O el estado que maneje tu lógica
      // 'remaining_classes': 1, // Descomenta si quieres probar planes limitados
    };

    await _firestore.collection('users').doc(userId).update({
      'active_plan': planData,
    });
    
    print("✅ ¡PLAN $planType ASIGNADO AL USUARIO!");
  }
}
*/