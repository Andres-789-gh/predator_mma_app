import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/user_model.dart';
import '../../domain/models/access_exception_model.dart';
import '../../../../core/constants/enums.dart';
import 'access_exception_mapper.dart';

class UserMapper {
  
  static UserModel fromMap(Map<String, dynamic> map, String docId) {
    final birthDateTs = map['personal_info']?['birth_date'];
    
    if (birthDateTs == null) {
      throw Exception('error critico: el usuario $docId no tiene fecha de nacimiento');
    }
    if (birthDateTs is! Timestamp) {
      throw Exception('error critico: formato de fecha invalido para usuario $docId');
    }

    final rawExceptions = map['access_exceptions'];
    final safeExceptions = rawExceptions is List
        ? rawExceptions
            .whereType<Map<String, dynamic>>() 
            .map((x) => AccessExceptionMapper.fromMap(x)) 
            .toList()
        : <AccessExceptionModel>[]; 

    return UserModel(
      userId: docId,
      email: map['email'] ?? '',
      firstName: map['personal_info']?['first_name'] ?? '',
      lastName: map['personal_info']?['last_name'] ?? '',
      documentId: map['personal_info']?['document_id'] ?? 'Sin Documento', 
      phoneNumber: map['personal_info']?['phone_number'] ?? 'Sin Teléfono',
      address: map['personal_info']?['address'] ?? 'Sin Dirección',
      birthDate: birthDateTs.toDate(),

      role: UserRole.values.firstWhere(
        (e) => e.name == (map['role'] ?? 'client'),
        orElse: () => UserRole.client,
      ),
      
      isLegacyUser: map['is_legacy_user'] ?? false,
      notificationToken: map['notification_token'],
      isWaiverSigned: map['legal']?['is_signed'] ?? false,
      waiverSignedAt: (map['legal']?['signed_at'] as Timestamp?)?.toDate(),
      waiverSignatureUrl: map['legal']?['signature_url'],
      
      activePlan: (map['active_plan'] is Map<String, dynamic>)
          ? _UserPlanMapper.fromMap(map['active_plan']) 
          : null,
      
      emergencyContact: map['emergency_contact'] ?? '',

      accessExceptions: safeExceptions,
    );
  }

  static Map<String, dynamic> toMap(UserModel user) {
    return {
      'email': user.email,
      'role': user.role.name,
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
      
      'active_plan': user.activePlan != null 
          ? _UserPlanMapper.toMap(user.activePlan!) 
          : null,
          
      'emergency_contact': user.emergencyContact,
      
      'access_exceptions': user.accessExceptions
          .map((x) => AccessExceptionMapper.toMap(x))
          .toList(),
    };
  }
}

class _UserPlanMapper {
  static UserPlan fromMap(Map<String, dynamic> map) {
    return UserPlan(
      type: PlanType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'full'),
        orElse: () => PlanType.full,
      ),
      startDate: (map['start_date'] as Timestamp).toDate(),
      endDate: (map['end_date'] as Timestamp).toDate(),
      
      remainingClasses: map['remaining_classes'] as int?,
      
      pauses: (map['pauses'] as List<dynamic>?)
          ?.map((x) => _PlanPauseMapper.fromMap(x))
          .toList() ?? [],
    );
  }

  static Map<String, dynamic> toMap(UserPlan plan) {
    return {
      'type': plan.type.name,
      'start_date': Timestamp.fromDate(plan.startDate),
      'end_date': Timestamp.fromDate(plan.endDate),
      'remaining_classes': plan.remainingClasses,
      'pauses': plan.pauses.map((e) => _PlanPauseMapper.toMap(e)).toList(),
    };
  }
}

class _PlanPauseMapper {
  static PlanPause fromMap(Map<String, dynamic> map) {
    return PlanPause(
      startDate: (map['start_date'] as Timestamp).toDate(),
      endDate: (map['end_date'] as Timestamp).toDate(),
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