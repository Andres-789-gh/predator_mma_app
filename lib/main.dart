import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  // Asegura que el motor gráfico de Flutter esté listo antes de llamar código nativo
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa Firebase usando la configuración generada
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Arranca la App
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Predator MMA',
      theme: ThemeData(
        // Usara un color oscuro/rojo
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('Conexión con Firebase Exitosa'),
        ),
      ),
    );
  }
}