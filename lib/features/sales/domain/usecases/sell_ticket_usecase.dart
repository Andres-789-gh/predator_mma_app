import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../auth/domain/models/access_exception_model.dart';
import '../../../auth/data/mappers/access_exception_mapper.dart';
import '../../../plans/domain/models/plan_model.dart';
import '../../domain/entities/sale_entity.dart';
import '../../data/repositories/sales_repository.dart';

class SellTicketUseCase {
  final FirebaseFirestore _firestore;
  final SalesRepository _salesRepository;

  SellTicketUseCase({
    FirebaseFirestore? firestore,
    required SalesRepository salesRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _salesRepository = salesRepository;

  Future<void> execute({
    required UserModel user,
    required int quantity,
    required double price,
    required String paymentMethod,
    required String adminName,
    required List<ScheduleRule> scheduleRules,
    required String originalPlanName,
    required DateTime validUntil,
    String? note,
  }) async {
    final saleEntity = SaleEntity(
      id: '',
      productId: 'ticket_pack',
      productName: 'Paquete de $quantity Ingresos Extra',
      productUnitPrice: price,
      productUnitCost: 0,
      quantity: 1,
      totalPrice: price,
      buyerId: user.userId,
      buyerName: user.fullName,
      paymentMethod: paymentMethod,
      saleDate: DateTime.now(),
      note: note ?? 'Sin observaciones',
      isService: true,
    );

    try {
      await _salesRepository.registerServiceSale(saleEntity);

      final newTicket = AccessExceptionModel(
        id: const Uuid().v4(),
        validUntil: validUntil,
        reason: note ?? 'Sin observaciones',
        quantity: quantity,
        originalPlanName: originalPlanName,
        grantedAt: DateTime.now(),
        grantedBy: adminName,
        price: price,
        scheduleRules: scheduleRules,
      );

      final ticketMap = AccessExceptionMapper.toMap(newTicket);

      await _firestore.collection('users').doc(user.userId).update({
        'access_exceptions': FieldValue.arrayUnion([ticketMap]),
      });
    } catch (e) {
      throw Exception('Fallo venta de ticket: $e');
    }
  }
}
