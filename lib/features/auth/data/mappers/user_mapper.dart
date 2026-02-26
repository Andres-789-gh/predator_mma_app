import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/user_model.dart';
import '../../domain/models/access_exception_model.dart';
import '../../../../core/constants/enums.dart';
import 'access_exception_mapper.dart';
import '../../../plans/data/mappers/plan_mapper.dart';

class UserMapper {
  static UserModel fromMap(Map<String, dynamic> map, String docId) {
    final birthDate = _getDateSafe(map['personal_info']?['birth_date']);
    final rawExceptions = map['access_exceptions'];
    final safeExceptions = rawExceptions is List
        ? rawExceptions
              .whereType<Map<String, dynamic>>()
              .map((x) => AccessExceptionMapper.fromMap(x))
              .toList()
        : <AccessExceptionModel>[];

    final roleString = (map['role'] ?? 'client')
        .toString()
        .trim()
        .toLowerCase();

    final safeRole = UserRole.values.firstWhere(
      (e) => e.name.toLowerCase() == roleString,
      orElse: () => UserRole.client,
    );

    List<UserPlan> parsedPlans = [];
    if (map['current_plans'] != null && map['current_plans'] is List) {
      parsedPlans = (map['current_plans'] as List)
          .map((x) => UserPlanMapper.fromMap(x as Map<String, dynamic>))
          .toList();
    } else if (map['current_plan'] != null && map['current_plan'] is Map) {
      parsedPlans = [UserPlanMapper.fromMap(map['current_plan'])];
    }

    return UserModel(
      userId: docId,
      email: map['email'] ?? '',
      firstName: map['personal_info']?['first_name'] ?? '',
      lastName: map['personal_info']?['last_name'] ?? '',
      documentId: map['personal_info']?['document_id'] ?? 'Sin Documento',
      phoneNumber: map['personal_info']?['phone_number'] ?? 'Sin Teléfono',
      address: map['personal_info']?['address'] ?? 'Sin Dirección',
      birthDate: birthDate,
      role: safeRole,
      isInstructor: map['is_instructor'] ?? false,
      isLegacyUser: map['is_legacy_user'] ?? false,
      notificationToken: map['notification_token'],
      isWaiverSigned: map['legal']?['is_signed'] ?? false,
      waiverSignedAt: map['legal']?['signed_at'] != null
          ? _getDateSafe(map['legal']['signed_at'])
          : null,
      waiverSignatureUrl: map['legal']?['signature_url'],
      currentPlans: parsedPlans,
      emergencyContact: map['emergency_contact'] ?? '',
      accessExceptions: safeExceptions,
    );
  }

  static Map<String, dynamic> toMap(UserModel user) {
    return {
      'email': user.email,
      'role': user.role.name,
      'is_instructor': user.isInstructor,
      'is_legacy_user': user.isLegacyUser,
      'notification_token': user.notificationToken,

      'personal_info': {
        'first_name': user.firstName,
        'last_name': user.lastName,
        'document_id': user.documentId,
        'phone_number': user.phoneNumber,
        'address': user.address,
        'birth_date': Timestamp.fromDate(user.birthDate),
      },

      'legal': {
        'is_signed': user.isWaiverSigned,
        'signed_at': user.waiverSignedAt != null
            ? Timestamp.fromDate(user.waiverSignedAt!)
            : null,
        'signature_url': user.waiverSignatureUrl,
      },

      'current_plans': user.currentPlans
          .map((x) => UserPlanMapper.toMap(x))
          .toList(),

      'emergency_contact': user.emergencyContact,

      'access_exceptions': user.accessExceptions
          .map((x) => AccessExceptionMapper.toMap(x))
          .toList(),
    };
  }

  static DateTime _getDateSafe(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}

class UserPlanMapper {
  static UserPlan fromMap(Map<String, dynamic> map) {
    return UserPlan(
      subscriptionId: map['subscription_id'] ?? map['plan_id'] ?? 'unknown_sub',
      planId: map['plan_id'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      consumptionType: PlanConsumptionType.values.firstWhere(
        (e) => e.name == (map['consumption_type'] ?? 'limitedDaily'),
        orElse: () => PlanConsumptionType.limitedDaily,
      ),
      dailyLimit: map['daily_limit'] as int?,
      scheduleRules:
          (map['schedule_rules'] as List<dynamic>?)
              ?.map((x) => ScheduleRuleMapper.fromMap(x))
              .toList() ??
          [],
      startDate: UserMapper._getDateSafe(map['start_date']),
      endDate: UserMapper._getDateSafe(map['end_date']),
      remainingClasses: map['remaining_classes'] as int?,
      pauses:
          (map['pauses'] as List<dynamic>?)
              ?.map((x) => PlanPauseMapper.fromMap(x))
              .toList() ??
          [],
    );
  }

  static Map<String, dynamic> toMap(UserPlan plan) {
    return {
      'subscription_id': plan.subscriptionId,
      'plan_id': plan.planId,
      'name': plan.name,
      'price': plan.price,
      'consumption_type': plan.consumptionType.name,
      'daily_limit': plan.dailyLimit,
      'schedule_rules': plan.scheduleRules
          .map((x) => ScheduleRuleMapper.toMap(x))
          .toList(),
      'start_date': Timestamp.fromDate(plan.startDate),
      'end_date': Timestamp.fromDate(plan.endDate),
      'remaining_classes': plan.remainingClasses,
      'pauses': plan.pauses.map((e) => PlanPauseMapper.toMap(e)).toList(),
    };
  }
}

class PlanPauseMapper {
  static PlanPause fromMap(Map<String, dynamic> map) {
    return PlanPause(
      startDate: UserMapper._getDateSafe(map['start_date']),
      endDate: UserMapper._getDateSafe(map['end_date']),
      createdBy: map['created_by'] ?? '',
    );
  }

  static Map<String, dynamic> toMap(PlanPause pause) {
    return {
      'start_date': Timestamp.fromDate(pause.startDate),
      'end_date': Timestamp.fromDate(pause.endDate),
      'created_by': pause.createdBy,
    };
  }
}
