import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import 'admin_screen.dart';
import '../cubit/admin_cubit.dart';
import '../../../plans/presentation/screens/plans_screen.dart';
import 'admin_users_screen.dart';
import '../../../../features/inventory/presentation/screens/inventory_screen.dart';
import '../../../../features/notifications/presentation/cubit/admin_notification_cubit.dart';
import '../../../../features/notifications/presentation/screens/admin_notifications_screen.dart';
import '../../../../injection_container.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../../features/schedule/presentation/screens/coach_screen.dart';
import '../../../../core/widgets/smart_avatar.dart';
import '../../../auth/presentation/screens/profile_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    if (authState is! AuthAuthenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = authState.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          lazy: false,
          create: (_) =>
              sl<AdminCubit>()..loadFormData(checkSchedule: true, silent: true),
        ),
        BlocProvider(create: (context) => sl<AdminNotificationCubit>()),
      ],
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text("Panel de Control"),
              actions: [
                // btn notificaciones
                BlocBuilder<AdminNotificationCubit, AdminNotificationState>(
                  builder: (context, state) {
                    int pendingCount = 0;
                    if (state is AdminNotificationLoaded) {
                      pendingCount = state.pendingCount;
                    }

                    return IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: context.read<AdminNotificationCubit>(),
                              child: const AdminNotificationsScreen(),
                            ),
                          ),
                        );
                      },
                      icon: Badge(
                        isLabelVisible: pendingCount > 0,
                        label: Text('$pendingCount'),
                        child: const Icon(Icons.notifications),
                      ),
                      tooltip: "Notificaciones",
                    );
                  },
                ),
                const SizedBox(width: 15),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 15),
                    child: SmartAvatar(
                      photoUrl: user.profilePictureUrl,
                      name: user.firstName,
                      radius: 18,
                    ),
                  ),
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Bienvenido, ${user.firstName}",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Administrador",
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 30),

                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      children: [
                        _AdminMenuCard(
                          icon: Icons.calendar_month,
                          title: "Gestionar\nHorarios/Clases",
                          color: Colors.redAccent,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BlocProvider.value(
                                  value: context.read<AdminCubit>(),
                                  child: const AdminScreen(),
                                ),
                              ),
                            );
                          },
                        ),
                        _AdminMenuCard(
                          icon: Icons.people,
                          title: "Usuarios",
                          color: Colors.redAccent,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BlocProvider.value(
                                  value: context.read<AdminCubit>(),
                                  child: const AdminUsersScreen(),
                                ),
                              ),
                            );
                          },
                        ),
                        _AdminMenuCard(
                          icon: Icons.monetization_on,
                          title: "Planes",
                          color: Colors.redAccent,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PlansScreen(),
                              ),
                            );
                          },
                        ),
                        _AdminMenuCard(
                          icon: Icons.analytics,
                          title: "Reportes",
                          color: Colors.redAccent,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ReportsScreen(),
                              ),
                            );
                          },
                        ),
                        _AdminMenuCard(
                          icon: Icons.inventory_2,
                          title: "Inventario",
                          color: Colors.redAccent,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const InventoryScreen(),
                              ),
                            );
                          },
                        ),
                        // agenda si admin es coach
                        if (user.isInstructor)
                          _AdminMenuCard(
                            icon: Icons.event_note,
                            title: "Mis Clases\n(Coach)",
                            color: Colors.redAccent,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CoachScreen(),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AdminMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _AdminMenuCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.2),
              radius: 30,
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 15),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
