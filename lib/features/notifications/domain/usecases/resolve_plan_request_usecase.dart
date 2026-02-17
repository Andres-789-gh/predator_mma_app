import '../../../../core/constants/enums.dart';
import '../../../../features/auth/domain/models/user_model.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../../../features/plans/domain/usecases/assign_plan_and_record_sale_usecase.dart';
import '../../../../features/plans/data/plan_repository.dart';
import '../models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';

class ResolvePlanRequestUseCase {
  final NotificationRepository _notificationRepository;
  final AssignPlanAndRecordSaleUseCase _assignPlanUseCase;
  final AuthRepository _authRepository;
  final PlanRepository _planRepository;

  ResolvePlanRequestUseCase({
    required NotificationRepository notificationRepository,
    required AssignPlanAndRecordSaleUseCase assignPlanUseCase,
    required AuthRepository authRepository,
    required PlanRepository planRepository,
  }) : _notificationRepository = notificationRepository,
       _assignPlanUseCase = assignPlanUseCase,
       _authRepository = authRepository,
       _planRepository = planRepository;

  Future<void> executeApprove({
    required NotificationModel notification,
    required double finalPrice,
    required DateTime startDate,
    required DateTime endDate,
    required String paymentMethod,
    String? adminNote,
  }) async {
    if (notification.status != NotificationStatus.pending) {
      throw Exception('La solicitud no está pendiente');
    }

    final payload = notification.payload;
    final userId = notification.fromUserId;
    final planId = payload['plan_id'];

    if (userId.isEmpty || planId == null) {
      throw Exception('Datos de notificación corruptos');
    }

    try {
      final user = await _authRepository.getUserData(userId);
      if (user == null) throw Exception('El usuario ya no existe');

      final planModel = await _planRepository.getPlanById(planId);
      if (planModel == null) throw Exception('El plan base ya no existe');

      final planToAssign = UserPlan(
        subscriptionId:
            payload['subscription_id'] ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        planId: planModel.id,
        name: planModel.name,
        price: finalPrice,
        consumptionType: planModel.consumptionType,
        scheduleRules: planModel.scheduleRules,
        startDate: startDate,
        endDate: endDate,
        dailyLimit: planModel.dailyLimit,
        remainingClasses: planModel.consumptionType == PlanConsumptionType.pack
            ? planModel.packClassesQuantity
            : null,
      );

      await _assignPlanUseCase.execute(
        user: user,
        newPlan: planToAssign,
        paymentMethod: paymentMethod,
        note: adminNote ?? 'Aprobado desde Notificaciones',
      );

      await _notificationRepository.updateStatus(
        notification.id,
        NotificationStatus.approved,
        note: adminNote,
      );

      final responseNotification = NotificationModel(
        id: '',
        type: NotificationType.planRequest,
        status: NotificationStatus.approved,
        fromUserId: 'admin',
        fromUserName: 'Administrador',
        toUserId: userId,
        toRole: 'client',
        title: 'Solicitud Aprobada',
        body: 'Tu plan ${planModel.name} ha sido activado exitosamente.',
        isRead: false,
        createdAt: DateTime.now(),
        payload: {
          'plan_name': planModel.name,
          'resolution_note': adminNote,
          'related_request_id': notification.id,
        },
      );

      await _notificationRepository.sendNotification(responseNotification);
    } catch (e) {
      throw Exception('Error aprobando solicitud: $e');
    }
  }

  Future<void> executeReject({
    required NotificationModel notification,
    required String reason,
  }) async {
    try {
      await _notificationRepository.updateStatus(
        notification.id,
        NotificationStatus.rejected,
        note: reason,
      );

      final planName = notification.payload['plan_name'] ?? 'Plan solicitado';

      final responseNotification = NotificationModel(
        id: '',
        type: NotificationType.planRequest,
        status: NotificationStatus.rejected,
        fromUserId: 'admin',
        fromUserName: 'Administrador',
        toUserId: notification.fromUserId,
        toRole: 'client',
        title: 'Solicitud Rechazada',
        body: 'No pudimos activar tu plan $planName.',
        isRead: false,
        createdAt: DateTime.now(),
        payload: {
          'plan_name': planName,
          'resolution_note': reason,
          'related_request_id': notification.id,
        },
      );

      await _notificationRepository.sendNotification(responseNotification);
    } catch (e) {
      throw Exception('Error rechazando solicitud: $e');
    }
  }

  Future<void> executeArchive(String notificationId) async {
    await _notificationRepository.updateStatus(
      notificationId,
      NotificationStatus.archived,
    );
  }
}
