import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../auth/domain/models/access_exception_model.dart';
import '../../../plans/domain/models/plan_model.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../widgets/user_profile_header.dart';
import '../tabs/user_subscriptions_tab.dart';
import '../tabs/user_tickets_tab.dart';
import '../widgets/dialogs/assign_plan_dialog.dart';
import '../widgets/dialogs/pause_plan_dialog.dart';
import '../widgets/dialogs/add_ticket_dialog.dart';
import '../widgets/dialogs/ticket_detail_dialog.dart';

class AdminUserDetailScreen extends StatefulWidget {
  final UserModel user;
  final List<PlanModel> availablePlans;
  final Function(UserModel) onSave;

  const AdminUserDetailScreen({
    super.key,
    required this.user,
    required this.availablePlans,
    required this.onSave,
  });

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen>
    with SingleTickerProviderStateMixin {
  late UserModel _editedUser;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _editedUser = widget.user;
    _tabController = TabController(length: 2, vsync: this);
  }

  // comparar si hubo cambios
  bool get _hasChanges {
    final u1 = widget.user;
    final u2 = _editedUser;

    bool planChanged = false;
    if (u1.activePlan == null && u2.activePlan != null) planChanged = true;
    if (u1.activePlan != null && u2.activePlan == null) planChanged = true;
    if (u1.activePlan != null && u2.activePlan != null) {
      planChanged = u1.activePlan!.planId != u2.activePlan!.planId ||
          u1.activePlan!.effectiveEndDate != u2.activePlan!.effectiveEndDate ||
          u1.activePlan!.pauses.length != u2.activePlan!.pauses.length;
    }

    return u1.firstName != u2.firstName ||
        u1.lastName != u2.lastName ||
        u1.documentId != u2.documentId ||
        u1.phoneNumber != u2.phoneNumber ||
        u1.accessExceptions.length != u2.accessExceptions.length ||
        u1.isLegacyUser != u2.isLegacyUser ||
        planChanged;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _showExitConfirmation();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Perfil de Usuario"),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: TextButton.icon(
                onPressed: _hasChanges ? _confirmSave : null,
                icon: const Icon(Icons.save, size: 20),
                label: const Text(
                  "GUARDAR",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: _hasChanges ? Colors.blue : Colors.grey,
                  backgroundColor:
                      _hasChanges ? Colors.blue.withValues(alpha: 0.1) : null,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // header del perfil
            UserProfileHeader(
              user: _editedUser,
              onToggleLegacyStatus: () {
                setState(() {
                  _editedUser = _editedUser.copyWith(
                    isLegacyUser: !_editedUser.isLegacyUser,
                  );
                });
              },
            ),

            TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: "PLANES"),
                Tab(text: "INGRESOS EXTRAS"),
              ],
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // tab de suscripciones
                  UserSubscriptionsTab(
                    activePlan: _editedUser.activePlan,
                    onAssignNewPlan: _showAssignPlanDialog,
                    onResumePlan: _resumePlan,
                    onPausePlan: _showPauseDialog,
                    onCancelPlan: _showCancelPlanDialog,
                  ),
                  // tab de tickets
                  UserTicketsTab(
                    tickets: _editedUser.accessExceptions,
                    onAddTicket: _showAddTicketDialog,
                    onTicketTap: (ticket) => _showTicketDetailDialog(ticket),
                    onRemoveTicket: (index) {
                      setState(() {
                        final newList = List<AccessExceptionModel>.from(
                          _editedUser.accessExceptions,
                        );
                        newList.removeAt(index);
                        _editedUser = _editedUser.copyWith(
                          accessExceptions: newList,
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // funciones logicas de plan

  void _showAssignPlanDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AssignPlanDialog(
        availablePlans: widget.availablePlans,
        onPlanAssigned: (UserPlan newPlan) {
          setState(() {
            _editedUser = _editedUser.copyWith(
              activePlan: newPlan,
            );
          });
        },
      ),
    );
  }

  void _showPauseDialog() {
    final authState = context.read<AuthCubit>().state;
    final String currentAdminName = (authState is AuthAuthenticated)
        ? authState.user.fullName
        : 'Admin';

    showDialog(
      context: context,
      builder: (ctx) => PausePlanDialog(
        currentAdminName: currentAdminName,
        onPauseConfirmed: (PlanPause newPause) {
          if (_editedUser.activePlan == null) return;
          final currentPlan = _editedUser.activePlan!;
          final updatedPauses = List<PlanPause>.from(currentPlan.pauses)
            ..add(newPause);

          setState(() {
            _editedUser = _editedUser.copyWith(
              activePlan: currentPlan.copyWith(pauses: updatedPauses),
            );
          });
        },
      ),
    );
  }

  void _resumePlan() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Reanudar Plan?"),
        content: const Text(
          "Esto eliminará la pausa actual y el plan volverá a estar activo.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Reanudar Plan"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (_editedUser.activePlan == null) return;
      final activePlan = _editedUser.activePlan!;
      final now = DateTime.now();

      final updatedPauses = activePlan.pauses.where((p) {
        final isCurrent = now.isAfter(p.startDate) && now.isBefore(p.endDate);
        return !isCurrent;
      }).toList();

      setState(() {
        _editedUser = _editedUser.copyWith(
          activePlan: activePlan.copyWith(pauses: updatedPauses),
        );
      });
    }
  }

  // cancela plan expirando la fecha
  Future<void> _showCancelPlanDialog() async {
    if (_editedUser.activePlan == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Cancelar Plan Actual?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Esta acción terminará el plan inmediatamente."),
            const SizedBox(height: 10),
            Text(
              "El plan pasará a estado 'Vencido' con fecha de ayer.",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Volver"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sí, Cancelar Plan"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        // expira el plan a ayer
        final expiredPlan = _editedUser.activePlan!.copyWith(
          endDate: DateTime.now().subtract(const Duration(days: 1)),
        );
        _editedUser = _editedUser.copyWith(activePlan: expiredPlan);
      });
    }
  }

  // funciones logicas de tickets

  void _showAddTicketDialog() {
    final authState = context.read<AuthCubit>().state;
    final String currentAdminName = (authState is AuthAuthenticated)
        ? authState.user.fullName
        : "Admin Desconocido";

    showDialog(
      context: context,
      builder: (ctx) => AddTicketDialog(
        availablePlans: widget.availablePlans,
        currentAdminName: currentAdminName,
        onTicketAdded: (AccessExceptionModel newTicket) {
          setState(() {
            final newList = List<AccessExceptionModel>.from(
              _editedUser.accessExceptions,
            )..add(newTicket);

            _editedUser = _editedUser.copyWith(
              accessExceptions: newList,
            );
          });
        },
      ),
    );
  }

  void _showTicketDetailDialog(AccessExceptionModel ticket) {
    showDialog(
      context: context,
      builder: (ctx) => TicketDetailDialog(ticket: ticket),
    );
  }

  // funciones de guardado

  Future<void> _showExitConfirmation() async {
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Salir sin guardar?"),
        content: const Text("Tienes cambios pendientes."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, false);
              Navigator.of(context).pop();
            },
            child: const Text(
              "Descartar",
              style: TextStyle(color: Colors.red),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Guardar"),
          ),
        ],
      ),
    );

    if (shouldSave == true) {
      _saveChanges();
    }
  }

  Future<void> _confirmSave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Guardar cambios?"),
        content: const Text(
          "Vas a actualizar la información de este usuario. ¿Estás seguro?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sí, Guardar"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _saveChanges();
    }
  }

  void _saveChanges() {
    widget.onSave(_editedUser);
    Navigator.pop(context);
  }
}