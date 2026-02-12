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
    } catch (e) {
      throw Exception('Error aprobando solicitud: $e');
    }
  }

  Future<void> executeReject(String notificationId, String reason) async {
    await _notificationRepository.updateStatus(
      notificationId,
      NotificationStatus.rejected,
      note: reason,
    );
  }

  Future<void> executeArchive(String notificationId) async {
    await _notificationRepository.updateStatus(
      notificationId,
      NotificationStatus.archived,
    );
  }
}
