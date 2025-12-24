import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtener estado y tema
    final authState = context.watch<AuthCubit>().state;
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

    // Calcular edad
    final age = DateTime.now().difference(user.birthDate).inDays ~/ 365;
    final bool isMinor = age < 18;

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
          // btn salir con confirmación
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () {
              // llamar función del dialogo
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
              const SizedBox(height: 40),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.block, color: Colors.red, size: 50),
                    const SizedBox(height: 20),
                    const Text(
                      'Acceso Restringido',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isMinor 
                        ? 'Al ser menor de edad ($age años), tu acudiente debe firmar presencialmente.'
                        : 'Debes firmar la exoneración para poder reservar clases.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 16),
                    ),
                    
                    if (!isMinor) ...[
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.edit_document),
                          label: const Text('IR A FIRMAR'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Próximamente: Pantalla de Firma')),
                            );
                          },
                        ),
                      ),
                    ]
                  ],
                ),
              ),
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
                ],
              ),
            ),
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
                Navigator.pop(ctx); // cerrar diálogo
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