import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/models/user_model.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores
  final _accessKeyController = TextEditingController();
  final _emailController = TextEditingController();
  final _documentController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyController = TextEditingController();

  // Variable para la fecha
  DateTime? _selectedBirthDate;

  @override
  void dispose() {
    _accessKeyController.dispose();
    _emailController.dispose();
    _documentController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emergencyController.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(BuildContext context) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: theme.colorScheme.primary,
                    onPrimary: Colors.white,
                    surface: const Color(0xFF1E1E1E),
                    onSurface: Colors.white,
                  )
                : ColorScheme.light(
                    primary: theme.colorScheme.primary,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black,
                  ),
            dialogTheme: DialogThemeData(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onSurface;
    final subTextColor = isDark ? Colors.grey : Colors.grey[700];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Registro', style: TextStyle(color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark
              ? Brightness.dark
              : Brightness.light, // iOS
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is AuthError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: theme.colorScheme.error,
                ),
              );
            }
            if (state is AuthAuthenticated) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('¡Registro Exitoso!'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.of(context).pop();
            }
          },
          builder: (context, state) {
            return Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [
                                Colors.black.withValues(alpha: 0.8),
                                Colors.black,
                              ]
                            : [Colors.white, Colors.grey[100]!],
                      ),
                    ),
                  ),
                ),

                // Form
                SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Únete a Predator',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ingresa tus datos para comenzar.',
                          style: TextStyle(color: subTextColor, fontSize: 16),
                        ),
                        const SizedBox(height: 30),

                        // cod acceso
                        _buildLabel('CÓDIGO DE ACCESO', context),
                        TextFormField(
                          controller: _accessKeyController,
                          style: TextStyle(color: textColor),
                          decoration: _buildInputDecoration(
                            'Digita el código de acceso',
                            Icons.vpn_key,
                            context,
                          ),
                          validator: (v) => v!.isEmpty ? 'Obligatorio' : null,
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Colors.grey),
                        const SizedBox(height: 20),

                        // nombre y apellido
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('NOMBRE', context),
                                  TextFormField(
                                    controller: _firstNameController,
                                    style: TextStyle(color: textColor),
                                    decoration: _buildInputDecoration(
                                      'Tu nombre',
                                      Icons.person_outline,
                                      context,
                                    ),
                                    validator: (v) =>
                                        v!.isEmpty ? 'Obligatorio' : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('APELLIDO', context),
                                  TextFormField(
                                    controller: _lastNameController,
                                    style: TextStyle(color: textColor),
                                    decoration: _buildInputDecoration(
                                      'Tu apellido',
                                      Icons.person_outline,
                                      context,
                                    ),
                                    validator: (v) =>
                                        v!.isEmpty ? 'Obligatorio' : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        _buildLabel('FECHA DE NACIMIENTO', context),
                        FormField<DateTime>(
                          validator: (value) {
                            if (_selectedBirthDate == null) {
                              return 'Obligatorio';
                            }
                            return null;
                          },
                          builder: (FormFieldState<DateTime> state) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: () async {
                                    final picked = await _pickDate(context);
                                    if (picked != null) {
                                      setState(() {
                                        _selectedBirthDate = picked;
                                      });
                                      state.didChange(picked);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                      horizontal: 20,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          theme
                                              .inputDecorationTheme
                                              .fillColor ??
                                          (isDark
                                              ? const Color(0xFF1E1E1E)
                                              : Colors.grey[200]),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: state.hasError
                                            ? Colors.red
                                            : Colors.transparent,
                                        width: state.hasError ? 1.0 : 0.0,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          color: state.hasError
                                              ? Colors.red
                                              : primaryColor,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          _selectedBirthDate == null
                                              ? 'Seleccionar Fecha'
                                              : '${_selectedBirthDate!.day}/${_selectedBirthDate!.month}/${_selectedBirthDate!.year}',
                                          style: TextStyle(
                                            color: _selectedBirthDate == null
                                                ? Colors.grey[600]
                                                : textColor,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (state.hasError)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 8.0,
                                      left: 12.0,
                                    ),
                                    child: Text(
                                      state.errorText ?? '',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // doc
                        _buildLabel('DOCUMENTO DE IDENTIDAD', context),
                        TextFormField(
                          controller: _documentController,
                          style: TextStyle(color: textColor),
                          decoration: _buildInputDecoration(
                            'Número de documento',
                            Icons.badge_outlined,
                            context,
                          ),
                          validator: (v) => v!.isEmpty ? 'Obligatorio' : null,
                        ),
                        const SizedBox(height: 20),

                        // email
                        _buildLabel('CORREO ELECTRÓNICO', context),
                        TextFormField(
                          controller: _emailController,
                          style: TextStyle(color: textColor),
                          keyboardType: TextInputType.emailAddress,
                          decoration: _buildInputDecoration(
                            'ejemplo@correo.com',
                            Icons.email_outlined,
                            context,
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Obligatorio';
                            final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                            if (!emailRegex.hasMatch(v)) {
                              return 'Correo inválido';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // tel
                        _buildLabel('TELÉFONO', context),
                        TextFormField(
                          controller: _phoneController,
                          style: TextStyle(color: textColor),
                          keyboardType: TextInputType.phone,
                          decoration: _buildInputDecoration(
                            'Número de contacto',
                            Icons.phone_outlined,
                            context,
                          ),
                          validator: (v) => v!.isEmpty ? 'Obligatorio' : null,
                        ),
                        const SizedBox(height: 20),

                        // dirreccion
                        _buildLabel('DIRECCIÓN', context),
                        TextFormField(
                          controller: _addressController,
                          style: TextStyle(color: textColor),
                          decoration: _buildInputDecoration(
                            'Dirección de residencia',
                            Icons.home_outlined,
                            context,
                          ),
                          validator: (v) => v!.isEmpty ? 'Obligatorio' : null,
                        ),
                        const SizedBox(height: 20),

                        // contacto emergencia
                        _buildLabel(
                          'CONTACTO DE EMERGENCIA',
                          context,
                          isUrgent: true,
                        ),
                        TextFormField(
                          controller: _emergencyController,
                          style: TextStyle(color: textColor),
                          keyboardType: TextInputType.phone,
                          decoration: _buildInputDecoration(
                            'Número de un familiar/amigo',
                            Icons.contact_phone_outlined,
                            context,
                            isUrgent: true,
                          ),
                          validator: (v) => v!.isEmpty ? 'Obligatorio' : null,
                        ),
                        const SizedBox(height: 40),

                        // btn registrar
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: primaryColor.withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: state is AuthLoading
                                ? null
                                : () {
                                    if (_formKey.currentState!.validate()) {
                                      final newUserModel = UserModel(
                                        userId: '',
                                        email: _emailController.text
                                            .trim()
                                            .toLowerCase(),
                                        firstName: _firstNameController.text
                                            .trim(),
                                        lastName: _lastNameController.text
                                            .trim(),
                                        documentId: _documentController.text
                                            .trim(),
                                        phoneNumber: _phoneController.text
                                            .trim(),
                                        address: _addressController.text.trim(),
                                        birthDate: _selectedBirthDate!,
                                        emergencyContact: _emergencyController
                                            .text
                                            .trim(),
                                        accessExceptions: [],
                                      );

                                      context.read<AuthCubit>().signUp(
                                        email: _emailController.text
                                            .trim()
                                            .toLowerCase(),
                                        documentId: _documentController.text
                                            .trim(),
                                        accessKey: _accessKeyController.text
                                            .trim(),
                                        userModel: newUserModel,
                                      );
                                    }
                                  },
                            child: state is AuthLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'CREAR CUENTA',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLabel(
    String text,
    BuildContext context, {
    bool isUrgent = false,
  }) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface.withValues(alpha: 0.7);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(
    String hint,
    IconData icon,
    BuildContext context, {
    bool isUrgent = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = theme.colorScheme.primary;
    final iconColor = isUrgent ? Colors.red : primaryColor;

    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        (isDark ? const Color(0xFF1E1E1E) : Colors.grey[200]);

    return InputDecoration(
      filled: true,
      fillColor: fillColor,
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[600]),
      prefixIcon: Icon(icon, color: iconColor),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }
}
