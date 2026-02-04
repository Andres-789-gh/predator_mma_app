import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/admin_cubit.dart';
import '../cubit/admin_state.dart';
import '../../../../core/constants/enums.dart';
import 'admin_user_detail_screen.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import 'package:intl/intl.dart';
import '../../../../features/auth/domain/models/user_model.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fabController;
  late Animation<double> _fabRotation;
  bool _isMenuOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _filterName = "";
  String _filterRole = "Todos";

  @override
  void initState() {
    super.initState();

    // Cargar lista usuarios
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminCubit>().loadUsersManagement();
    });

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _fabRotation = Tween<double>(
      begin: 0.0,
      end: 0.125,
    ).animate(CurvedAnimation(parent: _fabController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _fabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // funcion abrir/cerrar menu
  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gestión de Usuarios")),
      body: Stack(
        children: [
          Column(
            children: [
              // buscador y filtros
              Container(
                padding: const EdgeInsets.all(16.0),
                color: Theme.of(context).cardColor,
                child: Column(
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        labelText: "Buscar por nombre o documento",
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onChanged: (v) =>
                          setState(() => _filterName = v.toLowerCase()),
                    ),
                    const SizedBox(height: 10),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 250,
                        child: DropdownButtonFormField<String>(
                          initialValue: _filterRole,
                          decoration: const InputDecoration(
                            labelText: "Filtrar por Rol",
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 0,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: "Todos",
                              child: Text("Todos los Usuarios"),
                            ),
                            DropdownMenuItem(
                              value: "Clientes",
                              child: Text("Clientes"),
                            ),
                            DropdownMenuItem(
                              value: "Profesores",
                              child: Text("Profesores"),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _filterRole = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // lista usuarios
              Expanded(
                child: BlocBuilder<AdminCubit, AdminState>(
                  builder: (context, state) {
                    if (state is AdminLoading) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (state is AdminUsersLoaded) {
                      final filteredUsers = state.users
                          .where((u) {
                            if (u.role == UserRole.admin) return false;

                            final matchesName =
                                u.fullName.toLowerCase().contains(
                                  _filterName,
                                ) ||
                                u.documentId.contains(_filterName);
                            if (!matchesName) {
                              return false;
                            }

                            if (_filterRole == "Clientes" &&
                                u.role != UserRole.client) {
                              return false;
                            }

                            if (_filterRole == "Profesores" &&
                                u.role != UserRole.coach) {
                              return false;
                            }

                            return true;
                          })
                          .take(20)
                          .toList();

                      if (filteredUsers.isEmpty) {
                        return const Center(
                          child: Text("No se encontraron usuarios."),
                        );
                      }

                      return ListView.builder(
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          final activePlan = user.activePlan;

                          bool isPaused = false;
                          bool isActive = false;

                          if (activePlan != null) {
                            final now = DateTime.now();
                            isPaused = activePlan.pauses.any(
                              (p) =>
                                  now.isAfter(
                                    p.startDate.subtract(
                                      const Duration(seconds: 1),
                                    ),
                                  ) &&
                                  now.isBefore(
                                    p.endDate.add(const Duration(seconds: 1)),
                                  ),
                            );

                            isActive = activePlan.isActive(now);
                          }

                          String planText = "Sin plan activo";
                          Color planColor = Colors.grey;

                          if (isPaused) {
                            planText = "Plan: ${activePlan!.name} (PAUSADO)";
                            planColor = Colors.orange[800]!;
                          } else if (isActive) {
                            planText = "Plan: ${activePlan!.name}";
                            planColor = Colors.green[800]!;
                          } else if (activePlan != null) {
                            planText = "Plan: ${activePlan.name} (Vencido)";
                            planColor = Colors.red;
                          }

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isPaused
                                  ? Colors.orange
                                  : (isActive ? Colors.green : Colors.grey),
                              foregroundColor: Colors.white,
                              child: Text(
                                user.firstName.isNotEmpty
                                    ? user.firstName[0].toUpperCase()
                                    : "-",
                              ),
                            ),
                            title: Text(
                              user.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.role == UserRole.coach
                                      ? "Profesor - CC: ${user.documentId}"
                                      : "Cliente - CC: ${user.documentId}",
                                ),
                                Text(
                                  planText,
                                  style: TextStyle(
                                    color: planColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdminUserDetailScreen(
                                    user: user,
                                    availablePlans: state.availablePlans,
                                    onSave: (updatedUser) {
                                      context
                                          .read<AdminCubit>()
                                          .updateUserProfile(updatedUser);
                                    },
                                  ),
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

          if (_isMenuOpen)
            GestureDetector(
              onTap: _toggleMenu,
              child: Container(
                color: Colors.black.withValues(alpha: 0.7),
                width: double.infinity,
                height: double.infinity,
              ),
            ),
        ],
      ),

      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isMenuOpen) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(blurRadius: 4, color: Colors.black26),
                    ],
                  ),
                  child: const Text(
                    "Restaurar Planes",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  mini: true,
                  heroTag: "btn_restore",
                  backgroundColor: Colors.green,
                  onPressed: () {
                    _toggleMenu();
                    _showUndoPauseDialog(context);
                  },
                  child: const Icon(Icons.restore_page, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 15),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(blurRadius: 4, color: Colors.black26),
                    ],
                  ),
                  child: const Text(
                    "Pausar Planes",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  mini: true,
                  heroTag: "btn_pause_all",
                  backgroundColor: Colors.orange[800],
                  onPressed: () {
                    _toggleMenu();
                    _showGlobalPauseDialog(context);
                  },
                  child: const Icon(Icons.pause, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 15),
          ],

          RotationTransition(
            turns: _fabRotation,
            child: FloatingActionButton(
              heroTag: "btn_main",
              backgroundColor: _isMenuOpen
                  ? Colors.grey[800]
                  : Theme.of(context).primaryColor,
              onPressed: _toggleMenu,
              tooltip: "Opciones",
              child: const Icon(Icons.add, size: 30, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showGlobalPauseDialog(BuildContext context) {
    final adminCubit = context.read<AdminCubit>();
    final authCubit = context.read<AuthCubit>();

    DateTime? startDate;
    DateTime? endDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text("Pausar Planes Masivamente"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Selecciona el rango de fechas para pausar TODOS los planes activos.",
                ),
                const SizedBox(height: 20),

                // fecha inicio
                ListTile(
                  title: Text(
                    startDate == null
                        ? "Fecha Inicio"
                        : DateFormat('dd/MM/yyyy').format(startDate!),
                  ),
                  leading: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() => startDate = picked);
                    }
                  },
                ),

                // fecha fin
                ListTile(
                  title: Text(
                    endDate == null
                        ? "Fecha Fin"
                        : DateFormat('dd/MM/yyyy').format(endDate!),
                  ),
                  leading: const Icon(Icons.event_busy),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: startDate ?? DateTime.now(),
                      firstDate: startDate ?? DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() => endDate = picked);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Cancelar"),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange[800],
                ),
                onPressed: (startDate == null || endDate == null)
                    ? null
                    : () {
                        final authState = authCubit.state;
                        final String adminName =
                            (authState is AuthAuthenticated)
                            ? authState.user.fullName
                            : "Admin Desconocido";

                        adminCubit.applyMassivePause(
                          startDate!,
                          endDate!,
                          adminName,
                        );

                        Navigator.pop(dialogContext);
                      },
                child: const Text("CONFIRMAR PAUSA"),
              ),
            ],
          );
        },
      ),
    );
  }

  // funcion deshacer pausas masivas
  void _showUndoPauseDialog(BuildContext context) {
    final adminCubit = context.read<AdminCubit>();
    final state = adminCubit.state;
    final Map<String, PlanPause> uniqueMassivePauses = {};

    if (state is AdminUsersLoaded) {
      for (var user in state.users) {
        if (user.activePlan == null) continue;
        for (var pause in user.activePlan!.pauses) {
          if (pause.createdBy.startsWith("MASIVA_")) {
            final tag = pause.createdBy.split(' ').first;

            if (!uniqueMassivePauses.containsKey(tag)) {
              uniqueMassivePauses[tag] = pause;
            }
          }
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Pausas Masivas Activas"),
        content: SizedBox(
          width: double.maxFinite,
          child: uniqueMassivePauses.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    "No se encontraron pausas masivas activas en los usuarios actuales.",
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: uniqueMassivePauses.length,
                  itemBuilder: (ctx, index) {
                    final pause = uniqueMassivePauses.values.elementAt(index);
                    final tag = uniqueMassivePauses.keys.elementAt(index);

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      child: ListTile(
                        leading: const Icon(
                          Icons.layers_clear,
                          color: Colors.red,
                        ),
                        title: Text(
                          "Pausa del ${DateFormat('dd/MM').format(pause.startDate)} al ${DateFormat('dd/MM').format(pause.endDate)}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text("ID: $tag"),
                        trailing: const Icon(Icons.delete_outline),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (confirmCtx) => AlertDialog(
                              title: const Text("Restaurar esta pausa?"),
                              content: Text(
                                "Se reactivarán los planes de todos los usuarios afectados por la pausa del ${DateFormat('dd/MM/yyyy').format(pause.startDate)}.",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(confirmCtx),
                                  child: const Text("Cancelar"),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  onPressed: () {
                                    adminCubit.undoMassivePause(
                                      pause.startDate,
                                    );

                                    Navigator.pop(confirmCtx);
                                    Navigator.pop(ctx);

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Restaurando pausa masiva...",
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text("Restaurar"),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  }
}
