import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/admin_cubit.dart';
import '../cubit/admin_state.dart';
import '../../../auth/domain/models/user_model.dart';
import 'package:intl/intl.dart';
import '../widgets/user_management_dialog.dart'; // El dialogo que haremos en el paso 5

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = "";

  @override
  void initState() {
    super.initState();
    // Cargar usuarios al entrar
    context.read<AdminCubit>().loadUsersManagement();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión de Usuarios"),
        actions: [
          // Botón Pausa Masiva (Vacaciones)
          IconButton(
            icon: const Icon(Icons.pause_circle_filled),
            tooltip: "Pausa Global (Vacaciones)",
            onPressed: () => _showGlobalPauseDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                labelText: "Buscar por nombre o documento",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _filter = v.toLowerCase()),
            ),
          ),
          
          // Lista
          Expanded(
            child: BlocBuilder<AdminCubit, AdminState>(
              builder: (context, state) {
                if (state is AdminLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is AdminUsersLoaded) {
                  final users = state.users.where((u) {
                    return u.fullName.toLowerCase().contains(_filter) ||
                           u.documentId.contains(_filter);
                  }).toList();

                  if (users.isEmpty) {
                    return const Center(child: Text("No se encontraron usuarios."));
                  }

                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final hasPlan = user.activePlan != null && user.activePlan!.isActive(DateTime.now());
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: hasPlan ? Colors.green : Colors.grey,
                          child: Text(user.firstName[0].toUpperCase()),
                        ),
                        title: Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("CC: ${user.documentId}"),
                            if (hasPlan)
                              Text(
                                "Plan: ${user.activePlan!.name}",
                                style: const TextStyle(color: Colors.green, fontSize: 12),
                              )
                            else 
                              const Text("Sin plan activo", style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // Abrir Dialogo de Edición
                          showDialog(
                            context: context,
                            builder: (_) => UserManagementDialog(
                              user: user,
                              availablePlans: state.availablePlans,
                              onSave: (updatedUser) {
                                context.read<AdminCubit>().updateUserProfile(updatedUser);
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                } else if (state is AdminError) {
                  return Center(child: Text("Error: ${state.message}"));
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showGlobalPauseDialog(BuildContext ctx) {
    DateTime? start;
    DateTime? end;
    
    showDialog(
      context: ctx,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Pausa Global (Vacaciones)"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Esto pausará TODOS los planes activos. Úsalo para cierres por vacaciones o mantenimiento.",
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.date_range),
              label: const Text("Seleccionar Rango de Fechas"),
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: dialogContext,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  start = picked.start;
                  end = picked.end;
                  (dialogContext as Element).markNeedsBuild(); // Refresh simple
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancelar")),
          FilledButton(
            onPressed: () {
              if (start != null && end != null) {
                Navigator.pop(dialogContext);
                ctx.read<AdminCubit>().applyMassivePause(start!, end!);
              }
            },
            child: const Text("Aplicar Pausa"),
          ),
        ],
      ),
    );
  }
}