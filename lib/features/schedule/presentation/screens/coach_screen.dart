import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/enums.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../notifications/data/repositories/notification_repository.dart';
import '../../../notifications/presentation/cubit/client_notification_cubit.dart';
import '../../../notifications/presentation/screens/client_notifications_screen.dart';
import '../../data/schedule_repository.dart';
import '../../domain/models/class_model.dart';

class CoachScreen extends StatelessWidget {
  const CoachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthCubit>().state;

    if (authState is! AuthAuthenticated) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    if (authState.user.role == UserRole.admin) {
      return const _CoachScreenContent();
    }

    return BlocProvider(
      create: (context) => ClientNotificationCubit(
        repository: NotificationRepositoryImpl(),
        userId: authState.user.userId,
      ),
      child: const _CoachScreenContent(),
    );
  }
}

class _CoachScreenContent extends StatefulWidget {
  const _CoachScreenContent();

  @override
  State<_CoachScreenContent> createState() => _CoachScreenContentState();
}

class _CoachScreenContentState extends State<_CoachScreenContent> {
  // agrupa dias con sus clases
  List<MapEntry<DateTime, List<ClassModel>>> _groupedClasses = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAgenda();
    });
  }

  // consulta bd
  Future<void> _fetchAgenda() async {
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) return;

    final currentUserId = authState.user.userId;

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      const int daysToFetch = 7;
      final endWindow = startOfToday.add(const Duration(days: daysToFetch));

      final allClasses = await context.read<ScheduleRepository>().getClasses(
        fromDate: startOfToday,
        toDate: endWindow,
      );

      if (mounted) {
        final myClasses = allClasses
            .where((c) => c.coachId == currentUserId)
            .toList();

        final Map<DateTime, List<ClassModel>> grouped = {};
        for (var c in myClasses) {
          final dateKey = DateTime(
            c.startTime.year,
            c.startTime.month,
            c.startTime.day,
          );
          if (!grouped.containsKey(dateKey)) {
            grouped[dateKey] = [];
          }
          grouped[dateKey]!.add(c);
        }

        final sortedKeys = grouped.keys.toList()..sort();

        for (var key in sortedKeys) {
          grouped[key]!.sort((a, b) => a.startTime.compareTo(b.startTime));
        }

        setState(() {
          _groupedClasses = sortedKeys
              .map((k) => MapEntry(k, grouped[k]!))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "Mi Agenda",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: bgColor,
        foregroundColor: isDark ? Colors.white : Colors.black,
        actions: [
          _buildNotificationBell(context),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : RefreshIndicator(
              onRefresh: _fetchAgenda,
              color: Colors.red,
              child: _groupedClasses.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 10, bottom: 80),
                      itemCount: _groupedClasses.length,
                      itemBuilder: (context, index) {
                        final dayData = _groupedClasses[index];
                        return _DayAgendaCard(
                          date: dayData.key,
                          classes: dayData.value,
                        );
                      },
                    ),
            ),
    );
  }

  // campana
  Widget _buildNotificationBell(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) return const SizedBox.shrink();

    if (authState.user.role == UserRole.admin) return const SizedBox.shrink();

    return BlocBuilder<ClientNotificationCubit, ClientNotificationState>(
      builder: (context, state) {
        int unreadCount = 0;
        if (state is ClientNotificationLoaded) {
          unreadCount = state.unreadCount;
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: context.read<ClientNotificationCubit>(),
                      child: const ClientNotificationsScreen(),
                    ),
                  ),
                );
              },
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // estado vacio
  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.event_available,
                size: 60,
                color: Colors.grey.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 15),
              Text(
                "No tienes clases en las próximas semanas",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // dialogo salida
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cerrar Sesión"),
        content: const Text("¿Estás seguro que deseas salir?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthCubit>().signOut();
            },
            child: const Text("Salir", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _DayAgendaCard extends StatelessWidget {
  final DateTime date;
  final List<ClassModel> classes;
  const _DayAgendaCard({required this.date, required this.classes});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const headerColor = Color(0xFF4CAF50);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: headerColor.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: isDark ? headerColor : Colors.black87,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDateHeader(date),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? headerColor : Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: classes.asMap().entries.map((entry) {
                final int index = entry.key;
                final ClassModel classModel = entry.value;
                final bool isLast = index == classes.length - 1;

                return Column(
                  children: [
                    _ClassRow(classModel: classModel),
                    if (!isLast) ...[
                      const SizedBox(height: 12),
                      Divider(
                        color: Colors.grey.withValues(alpha: 0.2),
                        height: 1,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // fecha a txt
  String _formatDateHeader(DateTime targetDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateStr = DateFormat("d 'de' MMMM", 'es').format(targetDate);
    if (targetDate == today) {
      return "Hoy, $dateStr";
    } else if (targetDate == tomorrow) {
      return "Mañana, $dateStr";
    } else {
      final rawStr = DateFormat("EEEE, d 'de' MMMM", 'es').format(targetDate);
      return rawStr[0].toUpperCase() + rawStr.substring(1).toLowerCase();
    }
  }
}

class _ClassRow extends StatelessWidget {
  final ClassModel classModel;

  const _ClassRow({required this.classModel});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final isExpired = classModel.endTime.isBefore(now);
    final isCancelled = classModel.isCancelled;
    final double rowOpacity = (isExpired && !isCancelled) ? 0.4 : 1.0;
    final timeFormat = DateFormat('h:mm a');
    final startTime = timeFormat.format(classModel.startTime);
    final endTime = timeFormat.format(classModel.endTime);
    final attendeesCount = classModel.attendees.length;

    Color accentColor = const Color(0xFF4CAF50);
    if (isCancelled) accentColor = Colors.red;
    if (isExpired && !isCancelled) accentColor = Colors.grey;

    return Opacity(
      opacity: rowOpacity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // bloque hora
          SizedBox(
            width: 75,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  startTime,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  endTime,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          Container(
            height: 35,
            width: 3,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(width: 12),

          // info extra
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  classModel.classType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.white : Colors.black87,
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),

                if (isCancelled)
                  const Text(
                    "CANCELADA",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  )
                else if (isExpired)
                  const Text(
                    "FINALIZADA",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  )
                else
                  Row(
                    children: [
                      Icon(
                        Icons.people_alt_rounded,
                        size: 14,
                        color: Colors.blue[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$attendeesCount / ${classModel.maxCapacity} Reservas',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
