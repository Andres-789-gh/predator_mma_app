import 'package:flutter/material.dart';
import '../../features/auth/domain/models/user_model.dart';
import '../../features/admin/presentation/screens/admin_home_screen.dart';
import '../../features/schedule/presentation/screens/coach_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart'; 
import '../constants/enums.dart';

class RoleDispatcher extends StatelessWidget {
  final UserModel user;

  const RoleDispatcher({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    switch (user.role) {
      case UserRole.admin:
        return const AdminHomeScreen(); 
      case UserRole.coach:
        return const CoachScreen();
      case UserRole.client:
        return const HomeScreen();
    }
  }
}