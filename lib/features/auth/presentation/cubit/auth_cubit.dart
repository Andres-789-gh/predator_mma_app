import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../data/auth_repository.dart';
import '../../domain/models/user_model.dart';
import 'auth_state.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  AuthCubit(this._authRepository) : super(const AuthInitial()) {
    _listenToTokenRefreshes();
  }

  // captura token generado en segundo plano y actualiza bd
  void _listenToTokenRefreshes() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      if (state is AuthAuthenticated) {
        final currentUser = (state as AuthAuthenticated).user;
        try {
          await _authRepository.updateNotificationToken(
            userId: currentUser.userId,
            token: newToken,
          );
          debugPrint('token actualizado en segundo plano por firebase.');
        } catch (e) {
          debugPrint('error guardando token en segundo plano: $e');
        }
      }
    });
  }

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
        if (!user.isActive) {
          await _authRepository.signOut();
          if (isClosed) return;
          emit(
            const AuthError(
              'Tu cuenta ha sido desactivada por un administrador.',
            ),
          );
          return;
        }

        emit(AuthAuthenticated(user));

        // vigila cambios del usuario en tiempo real
        _listenToUserChanges(user.userId);

        // delega captura de token a hilo secundario
        unawaited(_handleFcmToken(user));
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

      final user = await _authRepository
          .signIn(email: email, password: password)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException(
              'La conexión tardó demasiado. Revisa tu internet.',
            ),
          );

      if (isClosed) return;

      if (!user.isActive) {
        await _authRepository.signOut();
        if (isClosed) return;
        emit(const AuthError('Tu cuenta ha sido desactivada.'));
        return;
      }

      await checkAuthStatus(silent: true);
    } on TimeoutException catch (e) {
      if (isClosed) return;
      emit(AuthError(e.message ?? 'Tiempo de espera agotado.'));
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

      final isValidKey = await _authRepository
          .verifyRegistrationKey(accessKey)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException(
              'No se pudo verificar el código. Intenta de nuevo.',
            ),
          );

      if (isClosed) return;

      if (!isValidKey) {
        throw InvalidAccessKeyException();
      }

      final firebasePassword = _normalizePassword(documentId);

      await _authRepository
          .signUp(
            email: email,
            password: firebasePassword,
            userModel: userModel,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException(
              'La creación de cuenta tardó demasiado.',
            ),
          );

      if (isClosed) return;

      await checkAuthStatus(silent: true);
    } on TimeoutException catch (e) {
      if (isClosed) return;
      emit(AuthError(e.message ?? 'Tiempo de espera agotado.'));
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

  // limpia token push, cancela vigilancia y cierra sesion
  Future<void> signOut() async {
    _userSubscription?.cancel();

    if (state is AuthAuthenticated) {
      final currentUser = (state as AuthAuthenticated).user;
      await _removeFcmToken(currentUser);
    }

    await _authRepository.signOut();
    if (isClosed) return;
    emit(const AuthUnauthenticated());
  }

  // vigila documento de usuario en tiempo real
  void _listenToUserChanges(String userId) {
    _userSubscription?.cancel();

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
          if (!snapshot.exists) {
            signOut();
            return;
          }

          final data = snapshot.data();
          if (data != null) {
            final isActive = data['is_active'] ?? true;
            if (!isActive) {
              // detecta desactivacion y expulsa al usuario
              signOut();
              if (!isClosed) {
                emit(
                  const AuthError(
                    'Tu sesión expiró porque la cuenta fue desactivada.',
                  ),
                );
              }
            }
          }
        });
  }

  // actualiza datos manualmente
  Future<void> refreshUser() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;

      if (firebaseUser != null) {
        final freshUserData = await _authRepository.getUserData(
          firebaseUser.uid,
        );
        if (isClosed) return;

        if (freshUserData != null) {
          if (!freshUserData.isActive) {
            await signOut();
            if (isClosed) return;
            emit(const AuthError('Tu cuenta ha sido desactivada.'));
            return;
          }
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
        // solicita token protegiendo hilo principal con timeout
        final token = await messaging.getToken().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint(
              'timeout: google play services lento. reintentando en background...',
            );
            _retryFetchToken(user);
            return null;
          },
        );

        if (token != null && token != user.notificationToken) {
          await _authRepository.updateNotificationToken(
            userId: user.userId,
            token: token,
          );
          debugPrint('token fcm guardado con exito.');
        }
      }
    } catch (e) {
      debugPrint('error gestionando fcm token: $e');
    }
  }

  // reintenta obtener token progresivamente
  void _retryFetchToken(UserModel user, {int attempt = 1}) async {
    if (attempt > 5) {
      debugPrint('fcm retry: abortado despues de 5 intentos.');
      return;
    }

    // espera progresiva en hilo secundario
    await Future.delayed(Duration(seconds: 15 * attempt));

    try {
      debugPrint('fcm retry: intento $attempt...');
      final token = await FirebaseMessaging.instance.getToken();

      if (token != null && token != user.notificationToken) {
        await _authRepository.updateNotificationToken(
          userId: user.userId,
          token: token,
        );
        debugPrint(
          'fcm retry: token guardado exitosamente en intento $attempt',
        );
      }
    } catch (e) {
      debugPrint(
        'fcm retry: fallo en intento $attempt. programando siguiente...',
      );
      _retryFetchToken(user, attempt: attempt + 1);
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

  // actualiza campo de perfil
  Future<void> updateProfileField({
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

      if (isClosed) return;

      UserModel updatedUser;
      if (fieldName == 'personal_info.phone_number') {
        updatedUser = user.copyWith(phoneNumber: newValue);
      } else if (fieldName == 'emergency_contact') {
        updatedUser = user.copyWith(emergencyContact: newValue);
      } else if (fieldName == 'personal_info.address') {
        updatedUser = user.copyWith(address: newValue);
      } else {
        updatedUser = user;
      }

      emit(AuthAuthenticated(updatedUser));
    } catch (e) {
      if (isClosed) return;
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

      if (isClosed) return;
      emit(const AuthLoading());

      final file = File(pickedFile.path);

      // envia archivo a storage
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

      if (isClosed) return;

      final updatedUser = user.copyWith(profilePictureUrl: downloadUrl);
      emit(AuthAuthenticated(updatedUser));
    } catch (e) {
      if (isClosed) return;
      debugPrint('error actualizando foto: $e');
      emit(currentState);
    }
  }

  @override
  Future<void> close() {
    _userSubscription?.cancel();
    return super.close();
  }

  // envia correo recuperacion de contraseña
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _authRepository.sendPasswordResetEmail(email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('No hay ningún usuario registrado con este correo.');
      } else if (e.code == 'invalid-email') {
        throw Exception('El formato del correo no es válido.');
      }
      throw Exception('Error al enviar el correo de recuperación.');
    } catch (e) {
      throw Exception('Ocurrió un error inesperado. Intenta nuevamente.');
    }
  }
}

class InvalidAccessKeyException implements Exception {}
