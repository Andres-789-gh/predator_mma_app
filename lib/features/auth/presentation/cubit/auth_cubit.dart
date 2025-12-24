import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/auth_repository.dart';
import '../../domain/models/user_model.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;

  AuthCubit(this._authRepository) : super(const AuthInitial());

  String _normalizePassword(String documentId) {
    if (documentId.length < 6) {
      return documentId.padRight(6, '0');
    }
    return documentId;
  }

  Future<void> checkAuthStatus() async {
    try {
      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      emit(const AuthUnauthenticated());
    }
  }

  // login
  Future<void> signIn({required String email, required String password}) async {
    try {
      emit(const AuthLoading());

      final user = await _authRepository.signIn(email: email, password: password);

      emit(AuthAuthenticated(user));
    } on FirebaseAuthException catch (e) {
      // Captura errores de Firebase especificos
      String message = 'Error de autenticación';
      
      // Traducion de error
      switch (e.code) {
        case 'user-not-found':
        case 'invalid-email':
        case 'invalid-credential':
          message = 'Usuario no encontrado o datos incorrectos.';
          break;
        case 'wrong-password':
          message = 'Contraseña incorrecta.';
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
      // otro error
      emit(AuthError('Ocurrió un error inesperado: $e'));
    }
  }

  // registro
  Future<void> signUp({
    required String email,
    required String documentId,
    required String accessKey,
    required UserModel userModel,
  }) async {
    try {
      emit(const AuthLoading());

      final isValidKey = await _authRepository.verifyRegistrationKey(accessKey);
      
      if (!isValidKey) {
        throw Exception('El código de acceso es incorrecto.');
      }

      final firebasePassword = _normalizePassword(documentId);

      final newUser = await _authRepository.signUp(
        email: email,
        password: firebasePassword, 
        userModel: userModel,
      );

      emit(AuthAuthenticated(newUser));
    } on FirebaseAuthException catch (e) {
       String message = 'Error en el registro';
       if (e.code == 'email-already-in-use') {
         message = 'El correo ya está registrado.';
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