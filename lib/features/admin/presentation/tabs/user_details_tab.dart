import 'package:flutter/material.dart';
import '../../../../core/constants/enums.dart';
import '../../../auth/domain/models/user_model.dart';
import '../widgets/dialogs/hold_to_confirm_button.dart';
import '../widgets/dialogs/view_waiver_dialog.dart';
import 'package:intl/intl.dart';

class UserDetailsTab extends StatelessWidget {
  final UserModel user;
  final Function(UserModel) onUpdate;

  const UserDetailsTab({super.key, required this.user, required this.onUpdate});

  // cambio rol
  Future<void> _handleToggleRole(BuildContext context) async {
    final isCurrentlyCoach = user.role == UserRole.coach || user.isInstructor;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isCurrentlyCoach
              ? "¿Revocar acceso de Instructor?"
              : "¿Otorgar acceso de Instructor?",
        ),
        content: Text(
          isCurrentlyCoach
              ? "Esta acción convertira al usuario a cliente. Perderá inmediatamente el acceso al panel de profesores."
              : "Este usuario se convertirá en instructor. Tendrá privilegios para ver listas de asistencia y gestionar clases.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isCurrentlyCoach ? Colors.red : Colors.blue,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isCurrentlyCoach
                  ? "Asignar como cliente"
                  : "Asignar como instructor",
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      onUpdate(
        user.copyWith(
          role: isCurrentlyCoach ? UserRole.client : UserRole.coach,
          isInstructor: !isCurrentlyCoach,
        ),
      );
    }
  }

  // desactivacion
  void _handleDeactivate(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar Usuario?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "El usuario no podrá ingresar y no aparecerá en las listas, pero su historial y reportes financieros se mantendrán intactos.",
            ),
            const SizedBox(height: 20),
            HoldToConfirmButton(
              onConfirm: () {
                Navigator.pop(ctx);
                onUpdate(
                  user.copyWith(isActive: false, deletedAt: DateTime.now()),
                );
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final age = DateTime.now().year - user.birthDate.year;
    final birthStr = DateFormat('dd/MM/yyyy').format(user.birthDate);

    String roleString = "CLIENTE";
    Color roleColor = Colors.green;
    if (user.role == UserRole.admin) {
      roleString = "ADMINISTRADOR";
      roleColor = Colors.purple;
    } else if (user.role == UserRole.coach || user.isInstructor) {
      roleString = "INSTRUCTOR";
      roleColor = Colors.blue;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // tarjeta info personal
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Información Personal",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 15),
                _buildInfoRow("Nombre Completo", user.fullName, Icons.person),
                _buildInfoRow(
                  "Documento de Identidad",
                  user.documentId,
                  Icons.badge,
                ),
                _buildInfoRow(
                  "Fecha de Nacimiento",
                  "$birthStr ($age años)",
                  Icons.date_range,
                ),
                _buildInfoRow("Dirección", user.address, Icons.home),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // tarjeta contacto
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Contacto",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 15),
                _buildInfoRow(
                  "Teléfono Celular",
                  user.phoneNumber,
                  Icons.phone,
                ),
                _buildInfoRow("Correo Electrónico", user.email, Icons.email),
                _buildInfoRow(
                  "Contacto de Emergencia",
                  user.emergencyContact,
                  Icons.health_and_safety,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Waiver
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Documentación Legal",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Icon(
                      user.isWaiverSigned ? Icons.check_circle : Icons.cancel,
                      color: user.isWaiverSigned ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        user.isWaiverSigned
                            ? "Exoneración Firmada"
                            : "Exoneración Pendiente",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (user.isWaiverSigned)
                      TextButton.icon(
                        icon: const Icon(Icons.remove_red_eye, size: 16),
                        label: const Text("Ver Documento"),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) =>
                                ViewWaiverDialog(userId: user.userId),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 25),

        // panel administrativo
        const Text(
          "Administrar Usuario",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 10),

        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          tileColor: roleColor.withValues(alpha: 0.1),
          leading: Icon(Icons.shield, color: roleColor),
          title: const Text(
            "Rol del Usuario",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          subtitle: Text(
            roleString,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: roleColor,
              fontSize: 16,
            ),
          ),
          trailing: user.role != UserRole.admin ? const Icon(Icons.change_circle) : null,
          onTap: user.role != UserRole.admin
              ? () => _handleToggleRole(context)
              : null,
        ),

        const SizedBox(height: 10),

        if (user.isActive && user.role != UserRole.admin)
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            tileColor: Colors.red.withValues(alpha: 0.1),
            leading: const Icon(Icons.person_off, color: Colors.red),
            title: const Text(
              "Eliminar Usuario",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            onTap: () => _handleDeactivate(context),
          ),
      ],
    );
  }
}
