import '../../../../core/constants/enums.dart';

class NotificationModel {
  final String id;
  final NotificationType type;
  final NotificationStatus status;
  final String fromUserId;
  final String fromUserName;
  final String toRole;
  final String? toUserId;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final Map<String, dynamic> payload;
  final List<String> hiddenFor;

  NotificationModel({
    required this.id,
    required this.type,
    required this.status,
    required this.fromUserId,
    required this.fromUserName,
    required this.toRole,
    this.toUserId,
    this.title = '',
    this.body = '',
    required this.isRead,
    required this.createdAt,
    this.resolvedAt,
    required this.payload,
    this.hiddenFor = const [],
  });

  NotificationModel copyWith({
    String? id,
    NotificationType? type,
    NotificationStatus? status,
    String? fromUserId,
    String? fromUserName,
    String? toRole,
    String? toUserId,
    String? title,
    String? body,
    bool? isRead,
    DateTime? createdAt,
    DateTime? resolvedAt,
    Map<String, dynamic>? payload,
    List<String>? hiddenFor,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      fromUserId: fromUserId ?? this.fromUserId,
      fromUserName: fromUserName ?? this.fromUserName,
      toRole: toRole ?? this.toRole,
      toUserId: toUserId ?? this.toUserId,
      title: title ?? this.title,
      body: body ?? this.body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      payload: payload ?? this.payload,
      hiddenFor: hiddenFor ?? this.hiddenFor,
    );
  }
}
