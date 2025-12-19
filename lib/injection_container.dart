import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/schedule/data/schedule_repository.dart';

// Variable global para acceder a las dependencias desde cualquier lado
final sl = GetIt.instance;

Future<void> init() async {
  
  // Herramientas externas
  
  sl.registerLazySingleton(() => FirebaseAuth.instance);
  sl.registerLazySingleton(() => FirebaseFirestore.instance);

  // auth
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepository(
      auth: sl(),      // Inyecta FirebaseAuth
      firestore: sl(), // Inyecta FirebaseFirestore
    ),
  );

  sl.registerLazySingleton<ScheduleRepository>(
    () => ScheduleRepository(firestore: sl()),
  );

  // inventario (pendiente)
}