import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../schedule/presentation/cubit/schedule_cubit.dart';
import '../../../schedule/data/schedule_repository.dart';
import '../../../schedule/presentation/screens/schedule_screen.dart';
import '../../../auth/presentation/screens/waiver_screen.dart';
import '../../../../core/constants/enums.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;

    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is AuthLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.red)),
          );
        }

        if (state is AuthAuthenticated) {
          final user = state.user;
          final plan = user.activePlan;
          final now = DateTime.now();
          // Estados
          final bool hasPlanObject = plan != null;
          // vencido
          final bool isPlanExpired = hasPlanObject && plan.endDate.isBefore(now);
          // pausado
          final bool isPlanPaused = hasPlanObject && !isPlanExpired && plan.pauses.any((p) {
             return now.isAfter(p.startDate.subtract(const Duration(seconds: 1))) && 
                    now.isBefore(p.endDate.add(const Duration(seconds: 1)));
          });
          // activo
          final bool isPlanActiveVisual = hasPlanObject && !isPlanExpired && !isPlanPaused;
          final bool isWaiverSigned = user.isWaiverSigned;
          final bool hasTickets = user.accessExceptions.any((t) => t.quantity > 0);
          final bool canReserve = isPlanActiveVisual || hasTickets;

          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Text('PREDATOR', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.red),
                  onPressed: () {
                    _showLogoutDialog(context);
                  },
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // header
                  Text(
                    'Bienvenido, ${user.firstName}',
                    style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 5),
                  Text(
                    'Cliente',
                    style: TextStyle(color: isDark ? Colors.grey : Colors.grey[700], fontSize: 16),
                  ),
                  const SizedBox(height: 20),

                  if (!isWaiverSigned) ...[
                    const SizedBox(height: 30),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.05),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
                          const SizedBox(height: 10),
                          const Text(
                            'Exoneración Pendiente',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Debes firmar la exoneración para poder reservar clases.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textColor.withValues(alpha: 0.8), fontSize: 14),
                          ),
                          
                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity,
                            height: 45,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const WaiverScreen()),
                                );
                              },
                              child: const Text('FIRMAR AHORA', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],

                  // tarjeta membresia
                  Text(
                    'TU PLAN',
                    style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isPlanActiveVisual 
                            ? (isDark
                                ? [const Color(0xFF1E1E1E), const Color(0xFF2C2C2C)]
                                : [Colors.white, const Color(0xFFF5F5F5)])
                            : [ 
                                isDark ? const Color(0xFF251818) : Colors.red[50]!,
                                isDark ? const Color(0xFF1E1E1E) : Colors.white
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      border: Border.all(
                        color: isPlanExpired 
                            ? Colors.red.withOpacity(0.3)
                            : isPlanPaused
                                ? Colors.orange.withOpacity(0.3)
                                : (isPlanActiveVisual
                                    ? Colors.green.withOpacity(0.5)
                                    : (isDark ? Colors.white10 : Colors.grey[400]!)),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(
                              Icons.card_membership,
                              color: isPlanActiveVisual && !isDark 
                                  ? Colors.black87 
                                  : (isPlanExpired 
                                      ? Colors.red 
                                      : (isPlanPaused ? Colors.orange : Colors.white)),
                              size: 30,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isPlanExpired
                                    ? Colors.red.withOpacity(0.1) 
                                    : isPlanPaused
                                        ? Colors.orange.withOpacity(0.1)
                                        : (isPlanActiveVisual 
                                            ? Colors.green.withOpacity(0.2) 
                                            : Colors.grey.withOpacity(0.2)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isPlanExpired 
                                    ? 'VENCIDO' 
                                    : isPlanPaused
                                        ? 'PAUSADO'
                                        : (hasPlanObject ? 'ACTIVO' : 'INACTIVO'),
                                style: TextStyle(
                                  color: isPlanExpired 
                                      ? Colors.red 
                                      : isPlanPaused
                                          ? Colors.orange
                                          : (isPlanActiveVisual 
                                              ? Colors.green 
                                              : (isDark ? Colors.grey : Colors.grey[700])),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),

                        if (hasPlanObject) ...[ 
                          Text(
                            user.activePlan!.name.toUpperCase(),
                            style: TextStyle(
                              color: !isDark ? Colors.black87 : Colors.white,
                              fontSize: 24, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Vence: ${user.activePlan!.endDate.day}/${user.activePlan!.endDate.month}/${user.activePlan!.endDate.year}',
                            style: TextStyle(
                              color: !isDark ? Colors.grey[700] : Colors.grey
                            ),
                          ),
                          const SizedBox(height: 5),

                          if (user.activePlan!.remainingClasses != null) ...[
                            LinearProgressIndicator(
                              value: 0.5, 
                              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                              color: Colors.red,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${user.activePlan!.remainingClasses} clases disponibles',
                              style: TextStyle(color: !isDark ? Colors.grey[800] : Colors.white70),
                            ),
                          ] else ...[
                            if (user.isLegacyUser)
                              Text(
                                'Ingreso Ilimitado (Usuario Antiguo)', 
                                style: TextStyle(
                                  color: Colors.amber[700],
                                  fontWeight: FontWeight.bold
                                )
                              )
                            else if (user.activePlan!.consumptionType == PlanConsumptionType.limitedDaily)
                              Text(
                                'Límite: ${user.activePlan!.dailyLimit ?? 1} clase(s) por día', 
                                style: TextStyle(color: !isDark ? Colors.grey[800] : Colors.white70)
                              )
                            else
                              Text(
                                'Ingreso Ilimitado', 
                                style: TextStyle(color: !isDark ? Colors.grey[800] : Colors.white70)
                              ),
                          ],
                        ] else ...[
                          Text(
                            'Sin Plan Activo',
                            style: TextStyle(
                              color: !isDark ? Colors.black87 : Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Adquiere un plan para comenzar a reservar clases.',
                            style: TextStyle(color: !isDark ? Colors.grey[700] : Colors.white54),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Ingresos extra
                  if (hasTickets) ...[
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        Icon(Icons.confirmation_number_outlined, 
                          color: textColor.withOpacity(0.6), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'INGRESOS EXTRA DISPONIBLES',
                          style: TextStyle(
                            color: textColor.withOpacity(0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: user.accessExceptions.where((t) => t.quantity > 0).length,
                        separatorBuilder: (_, __) => const SizedBox(width: 15),
                        itemBuilder: (context, index) {
                          final ticket = user.accessExceptions.where((t) => t.quantity > 0).toList()[index];
                          return Container(
                            width: 200,
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.amber.withOpacity(0.5)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${ticket.quantity}',
                                        style: const TextStyle(
                                          color: Colors.amber, 
                                          fontWeight: FontWeight.bold
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        ticket.originalPlanName.isEmpty 
                                            ? 'Ticket General' 
                                            : ticket.originalPlanName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                          overflow: TextOverflow.ellipsis
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (ticket.validUntil != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Vence: ${ticket.validUntil!.day}/${ticket.validUntil!.month}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                  ),
                                ]
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),
                  
                ],
              ),
            ),

                  // Btn reservar
            bottomNavigationBar: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: canReserve
                    ? Container(
                        width: double.infinity,
                        height: 55,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(15),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BlocProvider(
                                    create: (context) => ScheduleCubit(
                                      repository: context.read<ScheduleRepository>(),
                                    ),
                                    child: const ScheduleScreen(),
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.calendar_month, color: Colors.white, size: 22),
                                SizedBox(width: 10),
                                Text(
                                  'VER HORARIOS Y RESERVAR',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SizedBox(
                        height: 55,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_clock, size: 20, color: Colors.grey[400]),
                            const SizedBox(height: 4),
                            Text(
                              'No tienes ingresos disponibles',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          );
        }

        // Fallback
        return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.red)));
      },
    );
  }

  // confirmacion salida
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text('Cerrar Sesión', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          content: Text('¿Estás seguro de que quieres salir?', style: TextStyle(color: isDark ? Colors.grey : Colors.black87)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.read<AuthCubit>().signOut();
              },
              child: const Text('Salir', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}