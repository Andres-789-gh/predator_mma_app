import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../features/auth/domain/models/user_model.dart';
import '../../../../features/sales/domain/entities/sale_entity.dart';
import '../../../../features/sales/data/repositories/sales_repository.dart';

class AssignPlanAndRecordSaleUseCase {
  final FirebaseFirestore _firestore;
  final SalesRepository _salesRepository;

  AssignPlanAndRecordSaleUseCase({
    FirebaseFirestore? firestore,
    required SalesRepository salesRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _salesRepository = salesRepository;

  // ejecuta transaccion atomica
  Future<void> execute({
    required UserModel user,
    required UserPlan newPlan,
    required String paymentMethod,
    String? note,
  }) async {
    if (newPlan.price < 0) throw Exception('El precio no puede ser negativo');

    final saleEntity = SaleEntity(
      id: '',
      productId: newPlan.planId,
      productName: newPlan.name,
      productUnitPrice: newPlan.price,
      productUnitCost: 0,
      quantity: 1,
      totalPrice: newPlan.price,
      buyerId: user.userId,
      buyerName: user.fullName,
      paymentMethod: paymentMethod,
      saleDate: DateTime.now(),
      note: note ?? 'Asignación de plan',
    );

    try {
      await _salesRepository.registerServiceSale(saleEntity);
      final userRef = _firestore.collection('users').doc(user.userId);

      final planMap = {
        'subscription_id': newPlan.subscriptionId,
        'plan_id': newPlan.planId,
        'name': newPlan.name,
        'price': newPlan.price,
        'consumption_type': newPlan.consumptionType.toString().split('.').last,
        'schedule_rules': newPlan.scheduleRules
            .map(
              (e) => {
                'allowed_days': e.allowedDays,
                'start_minute': e.startMinute,
                'end_minute': e.endMinute,
                'allowed_categories': e.allowedCategories
                    .map((c) => c.toString())
                    .toList(),
              },
            )
            .toList(),
        'start_date': Timestamp.fromDate(newPlan.startDate),
        'end_date': Timestamp.fromDate(newPlan.endDate),
        'remaining_classes': newPlan.remainingClasses,
        'daily_limit': newPlan.dailyLimit,
        'pauses': [],
      };

      await userRef.update({
        'current_plans': FieldValue.arrayUnion([planMap]),
      });
    } catch (e) {
      throw Exception('Fallo asignación: $e');
    }
  }
}
