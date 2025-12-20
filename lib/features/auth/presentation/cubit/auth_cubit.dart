import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/auth_repository.dart';
import '../../domain/models/user_model.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;

  AuthCubit(this._authRepository) : super(const AuthInitial());

  // Rellena con ceros si el documento es muy corto
  // (para que Firebase no rechace la creación de la cuenta)
  String _normalizePassword(String documentId) {
    if (documentId.length < 6) {
      return documentId.padRight(6, '0');
    }
    return documentId;
  }

  // Verificar sesión
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

  // Login
  Future<void> signIn({required String email, required String password}) async {
    try {
      emit(const AuthLoading()); 

      final user = await _authRepository.signIn(email: email, password: password);

      emit(AuthAuthenticated(user));
    } catch (e) {
      final cleanMessage = e.toString().replaceAll('Exception: ', '');
      emit(AuthError(cleanMessage));
    }
  }

  // Registro
  Future<void> signUp({
    required String email,
    required String documentId,
    required String accessKey,
    required UserModel userModel,
  }) async {
    try {
      emit(const AuthLoading());

      // validar clave profe
      final isValidKey = await _authRepository.verifyRegistrationKey(accessKey);
      
      if (!isValidKey) {
        throw Exception('El código de acceso del gimnasio es incorrecto.');
      }

      // normalizar password
      final firebasePassword = _normalizePassword(documentId);

      // crear user
      final newUser = await _authRepository.signUp(
        email: email,
        password: firebasePassword, 
        userModel: userModel,
      );

      emit(AuthAuthenticated(newUser));
    } catch (e) {
      final cleanMessage = e.toString().replaceAll('Exception: ', '');
      emit(AuthError(cleanMessage));
    }
  }

  // Logout
  Future<void> signOut() async {
    await _authRepository.signOut();
    emit(const AuthUnauthenticated());
  }
}