import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'injection_container.dart' as di;
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/auth/presentation/cubit/auth_state.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'features/schedule/data/schedule_repository.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initializeDateFormatting('es', null);

  runApp(
    RepositoryProvider(
      create: (context) => ScheduleRepository(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<AuthCubit>()..checkAuthStatus(),
      child: MaterialApp(
        title: 'Predator',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system, 

        // tema claro
        theme: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: Colors.white,
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFD32F2F),
            surface: Colors.white,
            onSurface: Colors.black,
          ),
          useMaterial3: true,
        ),

        // tema oscuro
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Colors.black,
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFD32F2F),
            surface: Colors.black,
            onSurface: Colors.white,
          ),
          useMaterial3: true,
        ),

        // Portero
        home: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            if (state is AuthAuthenticated) {
              return const HomeScreen(); // Home
            }
            if (state is AuthUnauthenticated) {
              return const LoginScreen(); // Login
            }
            // pantalla de espera
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F))),
            );
          },
        ),
      ),
    );
  }
}