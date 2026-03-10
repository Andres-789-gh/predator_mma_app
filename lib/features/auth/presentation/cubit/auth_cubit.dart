import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../data/auth_repository.dart';
import '../../domain/models/user_model.dart';
import 'auth_state.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

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

  // verifica sesion activa y actualiza token push
  Future<void> checkAuthStatus({bool silent = false}) async {
    try {
      if (!silent) emit(const AuthLoading());

      final user = await _authRepository.getCurrentUser();
      if (isClosed) return;

      if (user != null) {
        _handleFcmToken(user);
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

  // limpia token push y cierra sesion
  Future<void> signOut() async {
    if (state is AuthAuthenticated) {
      final currentUser = (state as AuthAuthenticated).user;
      await _removeFcmToken(currentUser);
    }

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

  // obtencion y guardado de token
  Future<void> _handleFcmToken(UserModel user) async {
    try {
      debugPrint('--- inicia captura de token fcm ---');
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await messaging.getToken();

        if (token != null && token != user.notificationToken) {
          await _authRepository.updateNotificationToken(
            userId: user.userId,
            token: token,
          );
          debugPrint(
            'token guardado en base de datos con exito (actualizacion parcial).',
          );
        } else {
          debugPrint('token repetido o nulo. se ignora guardado.');
        }
      }
    } catch (e) {
      debugPrint('error critico gestionando fcm token: $e');
    }
  }

  // borra rastro de dispositivo en cierre de sesion
  Future<void> _removeFcmToken(UserModel user) async {
    try {
      await FirebaseMessaging.instance.deleteToken();
      await _authRepository.updateNotificationToken(
        userId: user.userId,
        token: "",
      );
    } catch (e) {
      debugPrint('Error borrando FCM Token: $e');
    }
  }

  // actualiza telefono o contacto de emergencia
  Future<void> updatePhoneFields({
    required String fieldName,
    required String newValue,
  }) async {
    if (state is! AuthAuthenticated) return;

    final currentState = state as AuthAuthenticated;
    final user = currentState.user;

    try {
      await _authRepository.updatePartialField(
        userId: user.userId,
        field: fieldName,
        value: newValue,
      );

      UserModel updatedUser;
      if (fieldName == 'personal_info.phone_number') {
        updatedUser = user.copyWith(phoneNumber: newValue);
      } else if (fieldName == 'emergency_contact') {
        updatedUser = user.copyWith(emergencyContact: newValue);
      } else {
        updatedUser = user;
      }

      emit(AuthAuthenticated(updatedUser));
    } catch (e) {
      debugPrint('Error actualizando campo: $e');
    }
  }

  // subida de foto
  Future<void> updateProfilePicture() async {
    if (state is! AuthAuthenticated) return;

    final currentState = state as AuthAuthenticated;
    final user = currentState.user;

    try {
      // abre galeria y comprime imagen
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 800,
      );

      if (pickedFile == null) return;

      emit(const AuthLoading());

      final file = File(pickedFile.path);

      // archivo a storage
      final downloadUrl = await _authRepository.uploadProfilePicture(
        user.userId,
        file,
      );

      // actualiza url en firestore
      await _authRepository.updatePartialField(
        userId: user.userId,
        field: 'profile_picture_url',
        value: downloadUrl,
      );

      final updatedUser = user.copyWith(profilePictureUrl: downloadUrl);
      emit(AuthAuthenticated(updatedUser));
    } catch (e) {
      debugPrint('error actualizando foto: $e');
      emit(currentState);
    }
  }
}

class InvalidAccessKeyException implements Exception {}
