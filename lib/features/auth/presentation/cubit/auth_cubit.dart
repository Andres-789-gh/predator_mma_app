import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/auth_repository.dart';
import '../../domain/models/user_model.dart';
import 'auth_state.dart';
import 'package:flutter/foundation.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;

  AuthCubit(this._authRepository) : super(const AuthInitial());

  // normaliza el documento para usarlo como contraseña
  String _normalizePassword(String documentId) {
    if (documentId.length < 6) {
      return documentId.padRight(6, '0');
    }
    return documentId;
  }

  // verifica el estado actual de la sesión
  Future<void> checkAuthStatus({bool silent = false}) async {
    try {
      if (!silent) emit(const AuthLoading());
      
      final user = await _authRepository.getCurrentUser();
      
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      debugPrint('Error verificando sesión: $e'); 
      emit(const AuthUnauthenticated());
    }
  }

  // inicia sesión con correo y contraseña
  Future<void> signIn({required String email, required String password}) async {
    try {
      emit(const AuthLoading());

      await _authRepository.signIn(email: email, password: password);
      
      await checkAuthStatus(silent: true); 
      
    } on FirebaseAuthException catch (e) {
      String message = 'Error de autenticación';
      
      switch (e.code) {
        case 'user-not-found':
          message = 'Usuario no registrado.';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Credenciales incorrectas.';
          break;
        case 'invalid-email':
          message = 'El formato del correo no es válido.';
          break;
        case 'user-disabled':
          message = 'Esta cuenta ha sido deshabilitada.';
          break;
        case 'too-many-requests':
          message = 'Demasiados intentos. Intenta más tarde.';
          break;
        default:
          message = 'Error: ${e.message}';
      }
      emit(AuthError(message)); 
    } catch (e) {
      emit(const AuthError('Ocurrió un error inesperado. Intenta nuevamente.'));
    }
  }

  // registra un nuevo usuario
  Future<void> signUp({
    required String email,
    required String documentId,
    required String accessKey,
    required UserModel userModel,
  }) async {
    try {
      emit(const AuthLoading());

      // valida clave de acceso del gym
      final isValidKey = await _authRepository.verifyRegistrationKey(accessKey);
      
      if (!isValidKey) {
        throw InvalidAccessKeyException(); 
      }

      final firebasePassword = _normalizePassword(documentId);

      await _authRepository.signUp(
        email: email,
        password: firebasePassword, 
        userModel: userModel,
      );

      await checkAuthStatus(silent: true);

    } on InvalidAccessKeyException {
       emit(const AuthError('El código de acceso es incorrecto.'));

    } on FirebaseAuthException catch (e) {
       String message = 'Error en el registro';
       if (e.code == 'email-already-in-use') {
         message = 'El correo o documento ya está registrado.';
       } else if (e.code == 'weak-password') {
         message = 'La contraseña es muy débil.';
       }
       emit(AuthError(message));
       
    } catch (e) {
      final cleanMessage = e.toString().replaceAll('Exception: ', '');
      
      emit(AuthError(cleanMessage));
    }
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    emit(const AuthUnauthenticated());
  }
}

class InvalidAccessKeyException implements Exception {}