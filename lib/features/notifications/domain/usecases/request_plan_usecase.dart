import '../../../../core/constants/enums.dart';
import '../../../../features/auth/domain/models/user_model.dart';
import '../../../../features/plans/domain/models/plan_model.dart';
import '../models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';

class RequestPlanUseCase {
  final NotificationRepository _notificationRepository;

  RequestPlanUseCase(this._notificationRepository);

  Future<void> execute({
    required UserModel user,
    required PlanModel plan,
  }) async {
    final payload = {
      'plan_id': plan.id,
      'plan_name': plan.name,
      'plan_price': plan.price,
      'consumption_type': plan.consumptionType.toString(),
      'user_document': user.documentId,
      'daily_limit': plan.dailyLimit,
      'pack_classes_quantity': plan.packClassesQuantity,
      'subscription_id': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    final notification = NotificationModel(
      id: '',
      fromUserId: user.userId,
      fromUserName: user.fullName,
      toRole: 'admin',
      type: NotificationType.planRequest,
      status: NotificationStatus.pending,
      payload: payload,
      createdAt: DateTime.now(),
    );

    await _notificationRepository.sendNotification(notification);
  }
}
