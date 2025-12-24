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
      return await _getUserData(user.uid);
    }
    return null;
  }

  // login
  Future<UserModel> signIn({required String email, required String password}) async {
    // Auth de Firebase
    final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Buscar datos en Firestore
    final userData = await _getUserData(userCredential.user!.uid);
    
    if (userData == null) {
      throw Exception('El usuario existe en Auth pero no tiene datos en Firestore.');
    }
    
    return userData;
  }

  // registro
  Future<UserModel> signUp({
    required String email,
    required String password,
    required UserModel userModel,
  }) async {
    // Crear en Auth
    final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Actualizar ID en el modelo
    final newUser = userModel.copyWith(userId: userCredential.user!.uid);
    
    // Guardar en Firestore
    await _firestore
        .collection('users')
        .doc(newUser.userId)
        .set(UserMapper.toMap(newUser));

    return newUser;
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  Future<bool> verifyRegistrationKey(String key) async {
    const validKey = "PREDATOR2026"; 
    return key == validKey; 
  }

  // Helper privado
  Future<UserModel?> _getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserMapper.fromMap(doc.data()!, doc.id); 
    }
    return null;
  }
}