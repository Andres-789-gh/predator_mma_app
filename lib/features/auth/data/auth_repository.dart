import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/user_model.dart';
import 'mappers/user_mapper.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _firebaseAuth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  // Obtener usuario actual
  Future<UserModel?> getCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      return await getUserData(user.uid);
    }
    return null;
  }

  // login
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    // Auth de Firebase
    final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Buscar datos en Firestore
    final userData = await getUserData(userCredential.user!.uid);

    if (userData == null) {
      throw Exception(
        'El usuario existe en Auth pero no tiene datos en Firestore.',
      );
    }

    return userData;
  }

  // registro
  Future<UserModel> signUp({
    required String email,
    required String password,
    required UserModel userModel,
  }) async {
    const String genericError =
        'El correo electrónico o el documento de identidad ya están registrados.';

    try {
      final documentExists = await _checkDocumentExists(userModel.documentId);

      if (documentExists) {
        throw Exception(genericError);
      }

      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final newUser = userModel.copyWith(userId: userCredential.user!.uid);

      await _firestore
          .collection('users')
          .doc(newUser.userId)
          .set(UserMapper.toMap(newUser));

      return newUser;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception(genericError);
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  Future<bool> verifyRegistrationKey(String key) async {
    try {
      final doc = await _firestore
          .collection('gym_config')
          .doc('general_settings')
          .get();

      if (doc.exists) {
        final currentKey = doc.data()?['registration_key'] as String?;
        // Compara clave ingresada con la de bd
        return key.trim() == currentKey?.trim();
      }

      // si no hay config en la BD, nadie entra
      return false;
    } catch (e) {
      return false; // Si falla la conexión, deniega el acceso por seguridad
    }
  }

  // Helper privado
  Future<UserModel?> getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserMapper.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  // Doble documento
  Future<bool> _checkDocumentExists(String documentId) async {
    final query = await _firestore
        .collection('users')
        .where('personal_info.document_id', isEqualTo: documentId)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  Future<List<UserModel>> getInstructors() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('is_instructor', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => UserMapper.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error obteniendo instructores: $e');
      return [];
    }
  }

  // GESTION USUARIOS ADMIN:
  // Traer todos los usuarios
  Future<List<UserModel>> getAllUsers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .orderBy('personal_info.first_name')
          .get();

      return snapshot.docs
          .map((doc) => UserMapper.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error cargando usuarios: $e');
    }
  }

  // Actualizar usuario
  Future<void> updateUser(UserModel user) async {
    try {
      await _firestore
          .collection('users')
          .doc(user.userId)
          .update(UserMapper.toMap(user));
    } catch (e) {
      throw Exception('Error actualizando usuario: $e');
    }
  }

  // Pausa Masiva
  Future<int> applyGlobalPause({
    required DateTime startDate,
    required DateTime endDate,
    required String adminName,
  }) async {
    try {
      final snapshot = await _firestore.collection('users').get();

      final batch = _firestore.batch();
      int count = 0;

      for (var doc in snapshot.docs) {
        final userData = UserMapper.fromMap(doc.data(), doc.id);

        if (userData.activePlan != null &&
            userData.activePlan!.isActive(DateTime.now())) {
          final newPause = PlanPause(
            startDate: startDate,
            endDate: endDate,
            createdBy: 'Global: $adminName',
          );

          final updatedPauses = List<PlanPause>.from(
            userData.activePlan!.pauses,
          )..add(newPause);

          final updatedPlan = userData.activePlan!.copyWith(
            pauses: updatedPauses,
          );
          final updatedUser = userData.copyWith(activePlan: updatedPlan);

          batch.update(doc.reference, UserMapper.toMap(updatedUser));
          count++;
        }
      }

      if (count > 0) await batch.commit();
      return count;
    } catch (e) {
      throw Exception('Error en pausa masiva: $e');
    }
  }
}
