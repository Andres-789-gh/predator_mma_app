import '../../../../core/constants/enums.dart';
import '../../../../core/utils/date_utils.dart';
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

  Future<void> executeApprove(NotificationModel notification) async {
    if (notification.status != NotificationStatus.pending) {
      throw Exception('la solicitud no está pendiente');
    }

    final payload = notification.payload;
    final userId = notification.fromUserId;
    final planId = payload['plan_id'];

    if (userId.isEmpty || planId == null) {
      throw Exception('datos de notificación corruptos');
    }

    try {
      final user = await _authRepository.getUserData(userId);
      if (user == null) throw Exception('el usuario ya no existe');

      final planModel = await _planRepository.getPlanById(planId);
      if (planModel == null) throw Exception('el plan solicitado ya no existe');

      final startDate = DateTime.now();
      DateTime endDate;

      if (planModel.consumptionType == PlanConsumptionType.pack) {
        endDate = startDate.add(const Duration(days: 30));
      } else {
        endDate = AppDateUtils.calculateGymEndDate(startDate, 1);
      }

      final planToAssign = UserPlan(
        subscriptionId:
            payload['subscription_id'] ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        planId: planModel.id,
        name: planModel.name,
        price: planModel
            .price,
        consumptionType: planModel.consumptionType,
        scheduleRules:
            planModel.scheduleRules,
        startDate: startDate,
        endDate: endDate,
        dailyLimit: planModel.dailyLimit,
        remainingClasses: planModel.consumptionType == PlanConsumptionType.pack
            ? planModel.packClassesQuantity
            : null,
      );

      // ejecuta venta y asignacion
      await _assignPlanUseCase.execute(
        user: user,
        newPlan: planToAssign,
        paymentMethod: payload['payment_method'] ?? 'Solicitud App',
        note: 'Aprobado desde Notificaciones',
      );

      // cerrar notificacion
      await _notificationRepository.updateStatus(
        notification.id,
        NotificationStatus.approved,
      );
    } catch (e) {
      throw Exception('error aprobando solicitud: $e');
    }
  }

  Future<void> executeReject(String notificationId) async {
    await _notificationRepository.updateStatus(
      notificationId,
      NotificationStatus.rejected,
    );
  }
}
