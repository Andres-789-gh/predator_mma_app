import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/auth_repository.dart';
import '../../domain/models/user_model.dart';
import 'auth_state.dart';
import 'package:flutter/foundation.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;

  AuthCubit(this._authRepository) : super(const AuthInitial());

  // normaliza documento como contraseña
  String _normalizePassword(String documentId) {
    if (documentId.length < 6) {
      return documentId.padRight(6, '0');
    }
    return documentId;
  }

  // verifica sesion activa
  Future<void> checkAuthStatus({bool silent = false}) async {
    try {
      if (!silent) emit(const AuthLoading());

      final user = await _authRepository.getCurrentUser();
      if (isClosed) return;

      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      if (isClosed) return;
      debugPrint('Error verificando sesión: $e');
      emit(const AuthUnauthenticated());
    }
  }

  // procesa ingreso
  Future<void> signIn({required String email, required String password}) async {
    try {
      emit(const AuthLoading());

      await _authRepository.signIn(email: email, password: password);
      if (isClosed) return;

      await checkAuthStatus(silent: true);
    } on FirebaseAuthException catch (e) {
      if (isClosed) return;
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
      if (isClosed) return;
      emit(const AuthError('Ocurrió un error inesperado. Intenta nuevamente.'));
    }
  }

  // procesa registro
  Future<void> signUp({
    required String email,
    required String documentId,
    required String accessKey,
    required UserModel userModel,
  }) async {
    try {
      emit(const AuthLoading());

      final isValidKey = await _authRepository.verifyRegistrationKey(accessKey);
      if (isClosed) return;

      if (!isValidKey) {
        throw InvalidAccessKeyException();
      }

      final firebasePassword = _normalizePassword(documentId);

      await _authRepository.signUp(
        email: email,
        password: firebasePassword,
        userModel: userModel,
      );
      if (isClosed) return;

      await checkAuthStatus(silent: true);
    } on InvalidAccessKeyException {
      if (isClosed) return;
      emit(const AuthError('El código de acceso es incorrecto.'));
    } on FirebaseAuthException catch (e) {
      if (isClosed) return;
      String message = 'Error en el registro';
      if (e.code == 'email-already-in-use') {
        message = 'El correo o documento ya está registrado.';
      } else if (e.code == 'weak-password') {
        message = 'La contraseña es muy débil.';
      }
      emit(AuthError(message));
    } catch (e) {
      if (isClosed) return;
      final cleanMessage = e.toString().replaceAll('Exception: ', '');
      emit(AuthError(cleanMessage));
    }
  }

  // cierra sesion
  Future<void> signOut() async {
    await _authRepository.signOut();
    if (isClosed) return;
    emit(const AuthUnauthenticated());
  }

  // actualiza datos
  Future<void> refreshUser() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;

      if (firebaseUser != null) {
        final freshUserData = await _authRepository.getUserData(
          firebaseUser.uid,
        );
        if (isClosed) return;

        if (freshUserData != null) {
          emit(AuthAuthenticated(freshUserData));
        }
      }
    } catch (e) {
      debugPrint("Error refrescando usuario: $e");
    }
  }
}

class InvalidAccessKeyException implements Exception {}
