import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../../domain/models/notification_model.dart';
import '../mappers/notification_mapper.dart';
import '../../../../core/constants/enums.dart';

abstract class NotificationRepository {
  Future<void> sendNotification(NotificationModel notification);
  Stream<List<NotificationModel>> getNotificationsStream(
    String role, {
    String? userId,
  });
  Future<void> markAsRead(String notificationId);
  Future<void> markBatchAsRead(List<String> notificationIds);
  Future<void> updateStatus(
    String notificationId,
    NotificationStatus status, {
    String? note,
  });
  Future<void> hideNotification(String notificationId, String userId);
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
  Stream<List<NotificationModel>> getNotificationsStream(
    String role, {
    String? userId,
  }) {
    // por rol
    final roleStream = _firestore
        .collection('notifications')
        .where('to_role', isEqualTo: role)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NotificationMapper.fromFirestore(doc))
              .toList(),
        );

    // admin solo rol
    if (userId == null || userId.isEmpty) return roleStream;

    // notificaciónes personales
    final userStream = _firestore
        .collection('notifications')
        .where('to_user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NotificationMapper.fromFirestore(doc))
              .toList(),
        );

    return Rx.combineLatest2<
      List<NotificationModel>,
      List<NotificationModel>,
      List<NotificationModel>
    >(roleStream, userStream, (roleList, userList) {
      final combined = [...roleList, ...userList];
      final unique = {for (var n in combined) n.id: n}.values.toList();
      unique.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return unique;
    });
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
  Future<void> markBatchAsRead(List<String> notificationIds) async {
    if (notificationIds.isEmpty) return;
    try {
      final batch = _firestore.batch();
      for (final id in notificationIds) {
        final ref = _firestore.collection('notifications').doc(id);
        batch.update(ref, {'is_read': true});
      }
      await batch.commit();
    } catch (e) {
      throw Exception('error en lectura por lote: $e');
    }
  }

  @override
  Future<void> updateStatus(
    String notificationId,
    NotificationStatus status, {
    String? note,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'status': status.toString(),
        'resolved_at': FieldValue.serverTimestamp(),
      };
      if (note != null && note.isNotEmpty) {
        data['resolution_note'] = note;
      }
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update(data);
    } catch (e) {
      throw Exception('error actualizando estado: $e');
    }
  }

  @override
  Future<void> hideNotification(String notificationId, String userId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'hidden_for': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      throw Exception('error ocultando notificacion: $e');
    }
  }
}
