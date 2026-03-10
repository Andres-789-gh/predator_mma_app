// importa dependencias
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/widgets/smart_avatar.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;

    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = state.user;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text(
              'Mi Perfil',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: textColor,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // avatar editable
                Center(
                  child: Stack(
                    children: [
                      SmartAvatar(
                        photoUrl: user.profilePictureUrl,
                        name: user.firstName,
                        radius: 60,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            // abre galeria
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // nombre principal
                Text(
                  user.fullName,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  user.role.name.toUpperCase(),
                  style: const TextStyle(color: Colors.grey, letterSpacing: 1),
                ),
                const SizedBox(height: 40),

                // datos inmutables
                _buildInfoRow(
                  context,
                  'Correo Electrónico',
                  user.email,
                  isDark,
                  false,
                ),
                if (user.role == UserRole.client)
                  _buildInfoRow(
                    context,
                    'No. Documento',
                    user.documentId,
                    isDark,
                    false,
                  ),

                // datos editables
                _buildInfoRow(
                  context,
                  'Teléfono',
                  user.phoneNumber,
                  isDark,
                  true,
                ),
                if (user.role == UserRole.client)
                  _buildInfoRow(
                    context,
                    'Contacto Emergencia',
                    user.emergencyContact,
                    isDark,
                    true,
                  ),

                const SizedBox(height: 40),

                // historial cliente
                if (user.role == UserRole.client) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // navega a historial
                      },
                      icon: const Icon(Icons.history, color: Colors.red),
                      label: const Text(
                        'VER HISTORIAL DE PLANES',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // btn salida
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => _showLogoutDialog(context),
                    icon: const Icon(Icons.logout, color: Colors.white),
                    label: const Text(
                      'CERRAR SESIÓN',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[900],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    bool isDark,
    bool isEditable,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              if (isEditable)
                GestureDetector(
                  onTap: () {
                    final firestoreField = label.toLowerCase() == 'teléfono'
                        ? 'personal_info.phone_number'
                        : 'emergency_contact';

                    _showEditPhoneDialog(context, label, firestoreField, value);
                  },
                  child: const Icon(Icons.edit, size: 18, color: Colors.grey),
                ),
            ],
          ),
          if (isEditable) const Divider(),
          if (!isEditable) const SizedBox(height: 10),
        ],
      ),
    );
  }

  void _showEditPhoneDialog(
    BuildContext context,
    String title,
    String fieldName,
    String currentValue,
  ) {
    final TextEditingController controller = TextEditingController(
      text: currentValue,
    );
    final formKey = GlobalKey<FormState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Editar $title',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  maxLength: 15,
                  buildCounter:
                      (
                        context, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) {
                        return Text(
                          '$currentLength/$maxLength',
                          style: TextStyle(
                            color: currentLength < 7 ? Colors.red : Colors.grey,
                            fontSize: 12,
                          ),
                        );
                      },
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ej: 3000000000',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.phone, color: Colors.red),
                    filled: true,
                    fillColor: isDark ? Colors.black26 : Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El número es requerido';
                    }

                    final regex = RegExp(r'^[0-9]{7,15}$');
                    final cleanValue = value
                        .replaceAll(' ', '')
                        .replaceAll('-', '');

                    if (!regex.hasMatch(cleanValue)) {
                      return 'Usa solo números, sin símbolos (7 a 15 dígitos)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[900],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        final cleanNumber = controller.text.trim();
                        context.read<AuthCubit>().updatePhoneFields(
                          fieldName: fieldName,
                          newValue: cleanNumber,
                        );
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text(
                      'GUARDAR',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text(
            'Cerrar Sesión',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: Text(
            '¿Estás seguro de que quieres salir?',
            style: TextStyle(color: isDark ? Colors.grey : Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
                context.read<AuthCubit>().signOut();
              },
              child: const Text(
                'Salir',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
