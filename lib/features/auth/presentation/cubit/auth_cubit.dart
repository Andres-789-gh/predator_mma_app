import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/auth_repository.dart';
import '../../domain/models/user_model.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;

  // Inyectamos el repositorio en el constructor
  AuthCubit(this._authRepository) : super(AuthInitial());

  // ---------------------------------------------------------------------------
  // VERIFICAR SESION AL INICIAR APP
  // ---------------------------------------------------------------------------
  Future<void> checkAuthStatus() async {
    try {
      // No emitimos Loading aqui para no mostrar spinner apenas abre la app
      // simplemente verificamos rapido
      final user = await _authRepository.getCurrentUser();
      
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      // Si falla la verificacion silenciosa, mandamos al login
      emit(AuthUnauthenticated());
    }
  }

  // ---------------------------------------------------------------------------
  // INICIAR SESION (LOGIN)
  // ---------------------------------------------------------------------------
  Future<void> signIn({required String email, required String password}) async {
    try {
      emit(AuthLoading()); // 1. Ponemos a cargar la pantalla

      // 2. Llamamos al repositorio (Backend)
      final user = await _authRepository.signIn(email: email, password: password);

      emit(AuthAuthenticated(user)); // 3. Exito!
    } catch (e) {
      // El repositorio ya nos da el mensaje de error limpio (sin "Exception: ...")
      // pero por seguridad limpiamos el string si viene sucio
      final cleanMessage = e.toString().replaceAll('Exception: ', '');
      emit(AuthError(cleanMessage)); // 4. Fallo
    }
  }

  // ---------------------------------------------------------------------------
  // REGISTRARSE
  // ---------------------------------------------------------------------------
  Future<void> signUp({
    required String email, 
    required String password, 
    required UserModel userModel
  }) async {
    try {
      emit(AuthLoading());

      final newUser = await _authRepository.signUp(
        email: email, 
        password: password, 
        userModel: userModel
      );

      emit(AuthAuthenticated(newUser));
    } catch (e) {
      final cleanMessage = e.toString().replaceAll('Exception: ', '');
      emit(AuthError(cleanMessage));
    }
  }

  // ---------------------------------------------------------------------------
  // CERRAR SESION
  // ---------------------------------------------------------------------------
  Future<void> signOut() async {
    await _authRepository.signOut();
    emit(AuthUnauthenticated());
  }
}