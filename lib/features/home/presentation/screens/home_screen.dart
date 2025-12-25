import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../schedule/presentation/cubit/schedule_cubit.dart';
import '../../../schedule/data/schedule_repository.dart';
import '../../../schedule/presentation/screens/schedule_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtener estado y tema
    final authState = context.select((AuthCubit c) => c.state);   
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;

    // no autenticado, muestra carga
    if (authState is! AuthAuthenticated) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    final user = authState.user;
    final bool hasActivePlan = user.activePlan != null; 
    final bool isWaiverSigned = user.isWaiverSigned;
    final bool hasTickets = user.accessExceptions.any((t) => t.quantity > 0);
    final bool canReserve = hasActivePlan || hasTickets;
    // Calcular edad
    final today = DateTime.now();
    int age = today.year - user.birthDate.year;
    if (today.month < user.birthDate.month || 
      (today.month == user.birthDate.month && today.day < user.birthDate.day)) {
      age--;
    }

    final bool isMinor = age < 18;
    final Color ticketTextColor = hasActivePlan 
        ? Colors.white 
        : (isDark ? Colors.white : Colors.black);

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
              'Hola, ${user.firstName}',
              style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            
            if (!isWaiverSigned) ...[
              const SizedBox(height: 30),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  border: Border.all(color: Colors.red.withOpacity(0.5)),
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
                      isMinor 
                        ? 'Al ser menor de edad ($age años), tu acudiente debe firmar presencialmente.'
                        : 'Debes firmar la exoneración para poder reservar clases.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 14),
                    ),
                    
                    if (!isMinor) ...[
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Próximamente: Pantalla de Firma')),
                            );
                          },
                          child: const Text('FIRMAR AHORA', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ] else ...[
              Text(
                'Gestiona tus clases', 
                style: TextStyle(color: isDark ? Colors.grey : Colors.grey[700], fontSize: 16),
              ),
              const SizedBox(height: 30),
            ],
  
            // tarjeta membresia
            Text(
              'TU MEMBRESÍA',
              style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            const SizedBox(height: 10),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: hasActivePlan 
                    ? [const Color(0xFF1E1E1E), const Color(0xFF2C2C2C)] 
                    : [
                        isDark ? const Color(0xFF1E1E1E) : Colors.grey[300]!, 
                        isDark ? const Color(0xFF252525) : Colors.grey[200]!
                      ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
                border: Border.all(
                  color: hasActivePlan 
                    ? Colors.green.withOpacity(0.5) 
                    : (isDark ? Colors.white10 : Colors.grey[400]!),
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
                        color: hasActivePlan ? Colors.white : (isDark ? Colors.grey : Colors.black54),
                        size: 30,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: hasActivePlan ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          hasActivePlan ? 'ACTIVO' : 'INACTIVO',
                          style: TextStyle(
                            color: hasActivePlan ? Colors.green : (isDark ? Colors.grey : Colors.black54),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  if (hasActivePlan) ...[
                    // detalles plan activo
                    Text(
                      user.activePlan!.type.name.toUpperCase(), 
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Vence: ${user.activePlan!.endDate.day}/${user.activePlan!.endDate.month}/${user.activePlan!.endDate.year}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    if (user.activePlan!.remainingClasses != null) ...[
                      LinearProgressIndicator(
                        value: 0.5, 
                        backgroundColor: Colors.grey[800],
                        color: Colors.red,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${user.activePlan!.remainingClasses} clases disponibles',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ] else ...[
                      const Text('Plan Ilimitado', style: TextStyle(color: Colors.white70)),
                    ],
                  ] else ...[
                    // mensaje sin plan
                    Text(
                      'Sin Plan Activo',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87, 
                        fontSize: 22, 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Consulta con tu entrenador para adquirir tu membresía y comenzar a reservar clases.',
                      style: TextStyle(color: isDark ? Colors.grey : Colors.black54),
                    ),
                  ],

                  // Tickets
                  if (hasTickets) ...[
                    const SizedBox(height: 20),
                    Divider(color: ticketTextColor.withOpacity(0.2)),
                    const SizedBox(height: 10),
                    Text(
                      'INGRESOS EXTRA DISPONIBLES:',
                      style: TextStyle(color: ticketTextColor, fontSize: 10, fontWeight: FontWeight.bold)
                    ),
                    const SizedBox(height: 5),
                    ...user.accessExceptions.where((t) => t.quantity > 0).map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.local_activity, color: Colors.amber, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '${t.validForPlan.name.toUpperCase()}: ${t.quantity}',
                            style: TextStyle(color: ticketTextColor, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 40),

            // Btn reservar
            if (canReserve) ...[
              Container(
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
                      color: Colors.red.withOpacity(0.3),
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
              ),
            ] else ...[
              Center(
                child: Column(
                  children: [
                    Icon(Icons.lock_clock, size: 40, color: Colors.grey[400]),
                    const SizedBox(height: 10),
                    Text(
                      'No tienes ingresos disponibles',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
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