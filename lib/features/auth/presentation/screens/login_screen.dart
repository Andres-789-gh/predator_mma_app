import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';
import 'register_screen.dart';
import '../../../home/presentation/screens/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary; 
    final textColor = theme.colorScheme.onSurface; 
    final subTextColor = isDark ? Colors.grey : Colors.grey[700];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor, 
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: BlocConsumer<AuthCubit, AuthState>(
            listener: (context, state) {
            if (state is AuthError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: Theme.of(context).colorScheme.error),
              );
            }
            if (state is AuthAuthenticated) {
               ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Bienvenido ${state.user.firstName}'), backgroundColor: Colors.green),
              );
            }
          },
            builder: (context, state) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: isDark ? 0.5 : 0.1, 
                      child: Image.asset(
                        'assets/images/login_bg.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(color: theme.scaffoldBackgroundColor);
                        },
                      ),
                    ),
                  ),
      
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isDark 
                            ? [
                                Colors.black.withOpacity(0.3), 
                                Colors.black.withOpacity(0.8),
                                Colors.black, 
                              ]
                            : [
                                Colors.white.withOpacity(0.3), 
                                Colors.white.withOpacity(0.8),
                                Colors.white, 
                              ],
                        ),
                      ),
                    ),
                  ),
      
                  // Contenido form
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 30.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: [
                            // logo
                            Center(
                              child: SizedBox(
                                height: 125,
                                width: 125,
                                child: Image.asset(
                                  'assets/images/logo_predator.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // txts
                            Center(
                              child: Text(
                                'PREDATOR',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: Text(
                                'Bienvenido',
                                style: TextStyle(color: subTextColor, fontSize: 16),
                              ),
                            ),
                            const SizedBox(height: 40),
      
                            // input email
                            Text('CORREO ELECTRÓNICO', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              style: TextStyle(color: textColor),
                              keyboardType: TextInputType.emailAddress,
                              decoration: _buildInputDecoration('ejemplo@correo.com', Icons.email_outlined, context),
                              validator: (v) {
                                 if (v == null || v.isEmpty) return 'Requerido';
                                 final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                                 if (!emailRegex.hasMatch(v)) return 'Correo inválido';
                                 return null;
                              },
                            ),
                            const SizedBox(height: 20),
      
                            // input password
                            Text('CONTRASEÑA', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              style: TextStyle(color: textColor),
                              decoration: _buildInputDecoration('Ingresa tu contraseña', Icons.lock_outline, context).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                ),
                              ),
                              validator: (v) => v!.isEmpty ? 'Requerido' : null,
                            ),
                            
                            const SizedBox(height: 40),
      
                            // btn login
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 8,
                                  shadowColor: primaryColor.withOpacity(0.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: state is AuthLoading 
                                  ? null 
                                  : () {
                                    if (_formKey.currentState!.validate()) {
                                      context.read<AuthCubit>().signIn(
                                        email: _emailController.text.trim(),
                                        password: _passwordController.text.trim(),
                                      );
                                    }
                                  },
                                child: state is AuthLoading
                                    ? const SizedBox(
                                        width: 24, 
                                        height: 24, 
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                      )
                                    : const Text(
                                        'INGRESAR',
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                                      ),
                              ),
                            ),
      
                            const SizedBox(height: 24),
      
                            // link registro
                            Center(
                              child: TextButton(
                                onPressed: () {
                                   Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                                },
                                child: RichText(
                                  text: TextSpan(
                                    text: '¿No tienes cuenta? ',
                                    style: const TextStyle(color: Colors.grey),
                                    children: [
                                      TextSpan(
                                        text: 'Regístrate aquí',
                                        style: TextStyle(color: isDark ? Colors.red : primaryColor, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon, BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return InputDecoration(
      filled: true,
      fillColor: theme.inputDecorationTheme.fillColor ?? (isDark ? const Color(0xFF1E1E1E) : Colors.grey[200]),
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[600]),
      prefixIcon: Icon(icon, color: primaryColor),
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
        borderSide: BorderSide(color: theme.colorScheme.error),
      ),
    );
  }
}