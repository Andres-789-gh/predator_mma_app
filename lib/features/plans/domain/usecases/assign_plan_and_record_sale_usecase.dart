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
    if (newPlan.price < 0) throw Exception('el precio no puede ser negativo');

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
        'subscriptionId': newPlan.subscriptionId,
        'planId': newPlan.planId,
        'name': newPlan.name,
        'price': newPlan.price,
        'consumptionType': newPlan.consumptionType.toString(),
        'scheduleRules': newPlan.scheduleRules
            .map(
              (e) => {
                'allowedDays': e.allowedDays,
                'startMinute': e.startMinute,
                'endMinute': e.endMinute,
                'allowedCategories': e.allowedCategories
                    .map((c) => c.toString())
                    .toList(),
              },
            )
            .toList(),
        'startDate': Timestamp.fromDate(newPlan.startDate),
        'endDate': Timestamp.fromDate(newPlan.endDate),
        'remainingClasses': newPlan.remainingClasses,
        'dailyLimit': newPlan.dailyLimit,
        'pauses': [],
      };

      await userRef.update({
        'active_plans': FieldValue.arrayUnion([planMap]),
      });
    } catch (e) {
      throw Exception('fallo asignacion y venta: $e');
    }
  }
}
