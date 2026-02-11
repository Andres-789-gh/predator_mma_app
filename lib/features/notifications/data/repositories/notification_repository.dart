import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/notification_model.dart';
import '../mappers/notification_mapper.dart';
import '../../../../core/constants/enums.dart';

abstract class NotificationRepository {
  Future<void> sendNotification(NotificationModel notification);
  Stream<List<NotificationModel>> getNotificationsStream(String role);
  Future<void> markAsRead(String notificationId);
  Future<void> updateStatus(String notificationId, NotificationStatus status);
}

class NotificationRepositoryImpl implements NotificationRepository {
  final FirebaseFirestore _firestore;

  NotificationRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> sendNotification(NotificationModel notification) async {
    try {
      final docRef = notification.id.isEmpty
          ? _firestore.collection('notifications').doc()
          : _firestore.collection('notifications').doc(notification.id);

      await docRef.set(NotificationMapper.toMap(notification));
    } catch (e) {
      throw Exception('error enviando notificacion: $e');
    }
  }

  @override
  Stream<List<NotificationModel>> getNotificationsStream(String role) {
    return _firestore
        .collection('notifications')
        .where('to_role', isEqualTo: role)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NotificationMapper.fromFirestore(doc))
              .toList(),
        );
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'is_read': true,
      });
    } catch (e) {
      throw Exception('error marcando leido: $e');
    }
  }

  @override
  Future<void> updateStatus(
    String notificationId,
    NotificationStatus status,
  ) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'status': status.toString(),
        'resolved_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('error actualizando estado: $e');
    }
  }
}
