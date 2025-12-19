import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'injection_container.dart' as di; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicia Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inicia la Inyección de Dependencias (NUEVO)
  await di.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Predator App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      // txt simple hasta el Login
      home: const Scaffold(
        body: Center(
          child: Text('Predator MMA - Backend Listo 🚀'),
        ),
      ), 
    );
  }
}