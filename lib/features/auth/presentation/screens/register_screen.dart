import 'package:flutter/material.dart';
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
  // Variable para fecha
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

  // Función pa' abrir el calendario
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.red,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro de Alumno')),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
          if (state is AuthAuthenticated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('¡Registro Exitoso!'), backgroundColor: Colors.green),
            );
            Navigator.pop(context);
          }
        },
        builder: (context, state) {
          if (state is AuthLoading) {
             return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Text(
                    'Únete a Predator MMA',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  const SizedBox(height: 30),

                  // cod acceso
                  TextFormField(
                    controller: _accessKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Código de Acceso',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.vpn_key, color: Colors.red),
                    ),
                    validator: (v) => v!.isEmpty ? 'Obligatorio' : null,
                  ),
                  const SizedBox(height: 20),
                  
                  // datos name
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstNameController,
                          decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
                          validator: (v) => v!.isEmpty ? 'Obligatorio' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _lastNameController,
                          decoration: const InputDecoration(labelText: 'Apellido', border: OutlineInputBorder()),
                          validator: (v) => v!.isEmpty ? 'Obligatorio' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // dob
                  InkWell(
                    onTap: () => _selectDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha de Nacimiento',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _selectedBirthDate == null
                            ? 'Seleccionar Fecha'
                            : '${_selectedBirthDate!.day}/${_selectedBirthDate!.month}/${_selectedBirthDate!.year}',
                        style: TextStyle(
                          color: _selectedBirthDate == null ? Colors.grey : Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // doc
                  TextFormField(
                    controller: _documentController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Documento (Será tu contraseña)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                    validator: (v) => v!.isEmpty ? 'Obligatorio' : null,
                  ),
                  const SizedBox(height: 15),

                  // email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Correo', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                    validator: (v) {
                       if (v == null || v.isEmpty) return 'Obligatorio';
                       final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                       if (!emailRegex.hasMatch(v)) return 'Correo inválido';
                       return null;
                    },
                  ),

                  // tel.
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Celular', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                    validator: (v) => v!.isEmpty ? 'Obligatorio' : null,
                  ),
                  const SizedBox(height: 15),

                  // direccion
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'Dirección', border: OutlineInputBorder(), prefixIcon: Icon(Icons.home)),
                    validator: (v) => v!.isEmpty ? 'Obligatorio' : null,
                  ),
                  const SizedBox(height: 15),

                  // contacto emergencia
                  TextFormField(
                    controller: _emergencyController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Contacto de Emergencia',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.contact_phone, color: Colors.red),
                    ),
                    validator: (v) => v!.isEmpty ? 'Obligatorio (Por seguridad)' : null,
                  ),
                  const SizedBox(height: 30),

                  // btn registrar
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      // Bloquea btn si está cargando
                      onPressed: state is AuthLoading 
                            ? null 
                            : () {
                              if (_formKey.currentState!.validate()) {
                                
                                // Validar fecha
                                if (_selectedBirthDate == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Selecciona tu fecha de nacimiento')),
                                  );
                                  return;
                                }

                                final newUserModel = UserModel(
                                  userId: '',
                                  email: _emailController.text.trim(),
                                  firstName: _firstNameController.text.trim(),
                                  lastName: _lastNameController.text.trim(),
                                  documentId: _documentController.text.trim(),
                                  phoneNumber: _phoneController.text.trim(),
                                  address: _addressController.text.trim(),
                                  birthDate: _selectedBirthDate!,
                                  emergencyContact: _emergencyController.text.trim(), // Contacto emergencia
                                  
                                  accessExceptions: [],
                                );

                                context.read<AuthCubit>().signUp(
                                      email: _emailController.text.trim(),
                                      documentId: _documentController.text.trim(),
                                      accessKey: _accessKeyController.text.trim(),
                                      userModel: newUserModel,
                                    );
                              }
                            },
                      child: const Text('CREAR CUENTA'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}