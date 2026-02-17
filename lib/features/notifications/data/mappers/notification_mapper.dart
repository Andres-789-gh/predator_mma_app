import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/enums.dart';
import '../../domain/models/notification_model.dart';

class NotificationMapper {
  static NotificationModel fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return NotificationModel(
      id: doc.id,
      fromUserId: data['from_user_id'] ?? '',
      fromUserName: data['from_user_name'] ?? 'Desconocido',
      toRole: data['to_role'] ?? 'admin',
      toUserId: data['to_user_id'],
      title: data['title'] ?? '',
      body: data['body'] ?? '',

      type: NotificationType.values.firstWhere(
        (e) => e.toString() == data['type'],
        orElse: () => NotificationType.systemInfo,
      ),
      status: NotificationStatus.values.firstWhere(
        (e) => e.toString() == data['status'],
        orElse: () => NotificationStatus.pending,
      ),
      payload: Map<String, dynamic>.from(data['payload'] ?? {}),
      isRead: data['is_read'] ?? false,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (data['resolved_at'] as Timestamp?)?.toDate(),
    );
  }

  static Map<String, dynamic> toMap(NotificationModel notification) {
    return {
      'from_user_id': notification.fromUserId,
      'from_user_name': notification.fromUserName,
      'to_role': notification.toRole,
      'to_user_id': notification.toUserId,
      'title': notification.title,
      'body': notification.body,
      'type': notification.type.toString(),
      'status': notification.status.toString(),
      'payload': notification.payload,
      'is_read': notification.isRead,
      'created_at': Timestamp.fromDate(notification.createdAt),
      'resolved_at': notification.resolvedAt != null
          ? Timestamp.fromDate(notification.resolvedAt!)
          : null,
    };
  }
}
