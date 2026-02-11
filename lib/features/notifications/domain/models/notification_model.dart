import '../../../../core/constants/enums.dart';

class NotificationModel {
  final String id;
  final String fromUserId;
  final String fromUserName;
  final String toRole;
  final NotificationType type;
  final NotificationStatus status;
  final Map<String, dynamic> payload;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const NotificationModel({
    required this.id,
    required this.fromUserId,
    required this.fromUserName,
    this.toRole = 'admin',
    required this.type,
    this.status = NotificationStatus.pending,
    required this.payload,
    this.isRead = false,
    required this.createdAt,
    this.resolvedAt,
  });

  NotificationModel copyWith({
    String? id,
    NotificationStatus? status,
    bool? isRead,
    DateTime? resolvedAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      fromUserId: fromUserId,
      fromUserName: fromUserName,
      toRole: toRole,
      type: type,
      status: status ?? this.status,
      payload: payload,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}
