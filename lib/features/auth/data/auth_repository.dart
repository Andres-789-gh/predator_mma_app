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

  // obtiene usuario actual
  Future<UserModel?> getCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      return await getUserData(user.uid);
    }
    return null;
  }

  // autentica usuario
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final userData = await getUserData(userCredential.user!.uid);

    if (userData == null) {
      throw Exception(
        'El usuario existe en Auth pero no tiene datos en Firestore.',
      );
    }

    return userData;
  }

  // registra usuario nuevo
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

  // cierra sesion
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  // valida clave de registro
  Future<bool> verifyRegistrationKey(String key) async {
    try {
      final doc = await _firestore
          .collection('gym_config')
          .doc('general_settings')
          .get();

      if (doc.exists) {
        final currentKey = doc.data()?['registration_key'] as String?;
        return key.trim() == currentKey?.trim();
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // extrae datos de usuario y limpia historial
  Future<UserModel?> getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      final user = UserMapper.fromMap(doc.data()!, doc.id);
      return await _autoCleanExpiredPlans(user);
    }
    return null;
  }

  // verifica duplicidad de documento
  Future<bool> _checkDocumentExists(String documentId) async {
    final query = await _firestore
        .collection('users')
        .where('personal_info.document_id', isEqualTo: documentId)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  // obtiene instructores
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
      return [];
    }
  }

  // obtiene todos los usuarios
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

  // actualiza datos usuario y envia vencidos al historial
  Future<void> updateUser(UserModel user) async {
    try {
      final now = DateTime.now();
      final expiredPlans = user.currentPlans
          .where((p) => p.isExpired(now))
          .toList();
      final validPlans = user.currentPlans
          .where((p) => !p.isExpired(now))
          .toList();

      final batch = _firestore.batch();
      final userRef = _firestore.collection('users').doc(user.userId);

      final userToSave = user.copyWith(currentPlans: validPlans);
      batch.update(userRef, UserMapper.toMap(userToSave));

      for (var plan in expiredPlans) {
        final historyRef = userRef
            .collection('plan_history')
            .doc(plan.subscriptionId);
        batch.set(historyRef, UserPlanMapper.toMap(plan));
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Error actualizando usuario: $e');
    }
  }

  // traslada planes vencidos a subcoleccion
  Future<UserModel> _autoCleanExpiredPlans(UserModel user) async {
    final now = DateTime.now();
    final expiredPlans = user.currentPlans
        .where((p) => p.isExpired(now))
        .toList();

    if (expiredPlans.isEmpty) return user;

    final validPlans = user.currentPlans
        .where((p) => !p.isExpired(now))
        .toList();
    final cleanedUser = user.copyWith(currentPlans: validPlans);

    final batch = _firestore.batch();
    final userRef = _firestore.collection('users').doc(user.userId);

    batch.update(userRef, {
      'current_plans': validPlans.map((p) => UserPlanMapper.toMap(p)).toList(),
    });

    for (var plan in expiredPlans) {
      final historyRef = userRef
          .collection('plan_history')
          .doc(plan.subscriptionId);
      batch.set(historyRef, UserPlanMapper.toMap(plan));
    }

    await batch.commit();
    return cleanedUser;
  }

  // pausa global
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

        if (userData.currentPlans.isNotEmpty) {
          bool userModified = false;

          final updatedPlans = userData.currentPlans.map((plan) {
            if (plan.isActive(DateTime.now())) {
              userModified = true;
              final newPause = PlanPause(
                startDate: startDate,
                endDate: endDate,
                createdBy: 'Global: $adminName',
              );

              final updatedPauses = List<PlanPause>.from(plan.pauses)
                ..add(newPause);
              return plan.copyWith(pauses: updatedPauses);
            }
            return plan;
          }).toList();

          if (userModified) {
            final updatedUser = userData.copyWith(currentPlans: updatedPlans);
            batch.update(doc.reference, UserMapper.toMap(updatedUser));
            count++;
          }
        }
      }

      if (count > 0) await batch.commit();
      return count;
    } catch (e) {
      throw Exception('error en pausa masiva: $e');
    }
  }
}
