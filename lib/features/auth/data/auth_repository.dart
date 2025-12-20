import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../domain/models/user_model.dart';
import 'mappers/user_mapper.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  // funcion registro
  Future<UserModel> signUp({
    required String email,
    required String password,
    required UserModel userModel,
  }) async {
    
    if (email != userModel.email) {
      throw Exception('error de integridad: el email de registro no coincide con el del perfil');
    }

    UserCredential? userCredential;
    
    try {
      // crea usuario en firebase auth
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception('error tecnico: firebase no genero usuario');
      }

      final String uid = userCredential.user!.uid;

      // prepara el modelo id real
      final newUser = UserModel(
        userId: uid,
        email: email,
        firstName: userModel.firstName,
        lastName: userModel.lastName,
        documentId: userModel.documentId,
        phoneNumber: userModel.phoneNumber,
        address: userModel.address,
        birthDate: userModel.birthDate,
        role: userModel.role,
        isLegacyUser: userModel.isLegacyUser,
        notificationToken: userModel.notificationToken,
        isWaiverSigned: userModel.isWaiverSigned,
        waiverSignedAt: userModel.waiverSignedAt,
        waiverSignatureUrl: userModel.waiverSignatureUrl,
        activePlan: userModel.activePlan,
        emergencyContact: userModel.emergencyContact,
        // accessExceptions viene vacio por defecto
      );

      // guarda perfil en firestore
      try {
        // mapper: convierte objeto dart -> mapa firebase
        await _firestore.collection('users').doc(uid).set(UserMapper.toMap(newUser));
      } catch (dbError) {
        // rollback: intenta borrar usuario de auth si falla la bd
        try {
          await userCredential.user!.delete();
          debugPrint('usuario eliminado por fallo en base de datos');
        } catch (deleteError) {
          debugPrint('alerta: no se pudo eliminar usuario zombie: $deleteError');
        }
        
        throw Exception('fallo al guardar perfil: $dbError');
      }

      return newUser;

    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        throw Exception('la contraseña es muy debil');
      } else if (e.code == 'email-already-in-use') {
        throw Exception('este correo ya esta registrado');
      }
      throw Exception('error de autenticacion: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  // funcion de inicio de sesion
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception('no se pudo obtener usuario');
      }

      final uid = userCredential.user!.uid;
      
      final docSnapshot = await _firestore.collection('users').doc(uid).get();

      if (!docSnapshot.exists) {
        throw Exception('usuario sin perfil de datos');
      }

      // mapper: convierte mapa firebase -> objeto dart
      return UserMapper.fromMap(docSnapshot.data()!, uid);

    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('no existe usuario con ese correo');
      } else if (e.code == 'wrong-password') {
        throw Exception('contraseña incorrecta');
      } else if (e.code == 'invalid-credential') {
        throw Exception('credenciales invalidas');
      }
      throw Exception('error de acceso: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  // funcion de cerrar sesion
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // funcion para recuperar contraseña
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('error al enviar correo: $e');
    }
  }

  // funcion para obtener usuario actual
  Future<UserModel?> getCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    try {
      final docSnapshot = await _firestore
          .collection('users')
          .doc(firebaseUser.uid) // usa firebaseUser.uid en vez de uid suelto
          .get();

      if (!docSnapshot.exists) {
        debugPrint('alerta: usuario sin datos en firestore');
        return null; 
      }

      // Mapper:
      return UserMapper.fromMap(docSnapshot.data()!, firebaseUser.uid);
    } catch (e) {
      debugPrint('error obteniendo usuario: $e');
      return null;
    }
  }

  // validar clave (del profe)
  Future<bool> verifyRegistrationKey(String candidateKey) async {
    try {
      final doc = await _firestore
          .collection('gym_config')
          .doc('general_settings')
          .get();

      if (!doc.exists) {
        // Si no hay config, asume bloqueo por seguridad
        throw Exception('Error de configuración del sistema. Contacte al admin.');
      }

      final realKey = doc.data()?['registration_key'] ?? '';
      
      // Compara lo que escribio el usuario con lo que hay en base de datos
      return candidateKey.trim() == realKey;
    } catch (e) {
      throw Exception('Error validando clave de acceso: $e');
    }
  }
}