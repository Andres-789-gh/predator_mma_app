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

  // Compara si hubo cambios
  bool get _hasChanges {
    final u1 = widget.user;
    final u2 = _editedUser;

    if (u1.activePlans.length != u2.activePlans.length) return true;

    bool plansContentChanged = false;
    for (int i = 0; i < u1.activePlans.length; i++) {
      final p1 = u1.activePlans[i];
      final p2 = u2.activePlans[i];

      if (p1.planId != p2.planId ||
          p1.effectiveEndDate != p2.effectiveEndDate ||
          p1.pauses.length != p2.pauses.length) {
        plansContentChanged = true;
        break;
      }
    }

    if (plansContentChanged) return true;

    return u1.firstName != u2.firstName ||
        u1.lastName != u2.lastName ||
        u1.documentId != u2.documentId ||
        u1.phoneNumber != u2.phoneNumber ||
        u1.accessExceptions.length != u2.accessExceptions.length ||
        u1.isLegacyUser != u2.isLegacyUser;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _showExitConfirmation();
        if (shouldExit == true && context.mounted) {
          Navigator.of(context).pop();
        }
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
                  backgroundColor: _hasChanges
                      ? Colors.blue.withValues(alpha: 0.1)
                      : null,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Header del perfil
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
                  // Tab Suscripciones
                  UserSubscriptionsTab(
                    activePlans: _editedUser.validPlans,
                    onAssignNewPlan: _showAssignPlanDialog,
                    onResumePlan: (plan) => _resumePlan(plan),
                    onPausePlan: (plan) => _showPauseDialog(plan),
                    onCancelPlan: (plan) => _showCancelPlanDialog(plan),
                  ),
                  // Tab Tickets
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

  // LÓGICA PLANES
  void _showAssignPlanDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AssignPlanDialog(
        availablePlans: widget.availablePlans,
        onPlanAssigned: (UserPlan newPlan, String paymentMethod, String? note) {
          setState(() {
            final updatedPlans = List<UserPlan>.from(_editedUser.activePlans)
              ..add(newPlan);

            _editedUser = _editedUser.copyWith(activePlans: updatedPlans);
          });
        },
      ),
    );
  }

  void _showPauseDialog(UserPlan targetPlan) {
    final authState = context.read<AuthCubit>().state;
    final String currentAdminName = (authState is AuthAuthenticated)
        ? authState.user.fullName
        : 'Admin';

    showDialog(
      context: context,
      builder: (ctx) => PausePlanDialog(
        currentAdminName: currentAdminName,
        onPauseConfirmed: (PlanPause newPause) {
          final updatedPauses = List<PlanPause>.from(targetPlan.pauses)
            ..add(newPause);
          final updatedPlan = targetPlan.copyWith(pauses: updatedPauses);

          final updatedList = _editedUser.activePlans.map((p) {
            return p.subscriptionId == targetPlan.subscriptionId
                ? updatedPlan
                : p;
          }).toList();

          setState(() {
            _editedUser = _editedUser.copyWith(activePlans: updatedList);
          });
        },
      ),
    );
  }

  Future<void> _resumePlan(UserPlan targetPlan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Reanudar Plan?"),
        content: Text("Se reactivará el plan '${targetPlan.name}'."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Reanudar"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final now = DateTime.now();
      final updatedPauses = targetPlan.pauses.where((p) {
        final isCurrent = now.isAfter(p.startDate) && now.isBefore(p.endDate);
        return !isCurrent;
      }).toList();

      final updatedPlan = targetPlan.copyWith(pauses: updatedPauses);

      final updatedList = _editedUser.activePlans.map((p) {
        return p.subscriptionId == targetPlan.subscriptionId ? updatedPlan : p;
      }).toList();

      setState(() {
        _editedUser = _editedUser.copyWith(activePlans: updatedList);
      });
    }
  }

  Future<void> _showCancelPlanDialog(UserPlan targetPlan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("¿Cancelar '${targetPlan.name}'?"),
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
            child: const Text("Sí, Cancelar"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        final expiredPlan = targetPlan.copyWith(
          endDate: DateTime.now().subtract(const Duration(days: 1)),
        );

        final updatedList = _editedUser.activePlans.map((p) {
          return p.subscriptionId == targetPlan.subscriptionId
              ? expiredPlan
              : p;
        }).toList();

        _editedUser = _editedUser.copyWith(activePlans: updatedList);
      });
    }
  }

  // LÓGICA TICKETS
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

            _editedUser = _editedUser.copyWith(accessExceptions: newList);
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

  // GUARDADO Y SALIDA
  Future<bool> _showExitConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("¿Salir sin guardar?"),
            content: const Text("Tienes cambios pendientes."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancelar"),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Salir y Descartar"),
              ),
            ],
          ),
        ) ??
        false;
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
