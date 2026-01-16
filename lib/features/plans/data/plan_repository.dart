import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/plan_model.dart';
import 'mappers/plan_mapper.dart'; 

class PlanRepository {
  final FirebaseFirestore _firestore;

  PlanRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> createPlan(PlanModel plan) async {
    try {
      final docRef = _firestore.collection('plans').doc(); 
      await docRef.set(PlanMapper.toMap(plan));
    } catch (e) {
      throw Exception('Error creando plan: $e');
    }
  }

  // leer
  Future<List<PlanModel>> getActivePlans() async {
    try {
      final snapshot = await _firestore
          .collection('plans')
          .where('is_active', isEqualTo: true)
          .get();
      
      return snapshot.docs
          .map((doc) => PlanMapper.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error cargando planes: $e');
    }
  }

  Future<void> updatePlan(PlanModel plan) async {
    try {
      await _firestore.collection('plans').doc(plan.id).update(PlanMapper.toMap(plan));
    } catch (e) {
      throw Exception('Error actualizando plan: $e');
    }
  }

  Future<void> deletePlan(String planId) async {
    try {
      await _firestore.collection('plans').doc(planId).update({'is_active': false});
    } catch (e) {
      throw Exception('Error eliminando plan: $e');
    }
  }
}