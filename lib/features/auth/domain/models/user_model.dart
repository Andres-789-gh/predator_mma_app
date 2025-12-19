import '../../../../core/constants/enums.dart';
import 'access_exception_model.dart';

class UserModel {
  final String userId;
  final String email;
  final String firstName;
  final String lastName;
  final String documentId;
  final String phoneNumber;
  final String address;
  final DateTime birthDate; 
  
  final UserRole role;
  final bool isLegacyUser;
  final String? notificationToken;
  
  final bool isWaiverSigned; //antiguo?
  final DateTime? waiverSignedAt;
  final String? waiverSignatureUrl;

  final UserPlan? activePlan;
  final EmergencyContact? emergencyContact;

  final List<AccessExceptionModel> accessExceptions;

  // Constructor
  UserModel({
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.documentId = '',
    this.phoneNumber = '',
    this.address = '',
    required this.birthDate,
    this.role = UserRole.client, 
    this.isLegacyUser = false, 
    this.notificationToken, 
    this.isWaiverSigned = false, 
    this.waiverSignedAt,
    this.waiverSignatureUrl,
    this.activePlan,
    this.emergencyContact,
    List<AccessExceptionModel> accessExceptions = const [], 
  }) : accessExceptions = List.unmodifiable(accessExceptions);

  String get fullName => '$firstName $lastName';
}

// sub-modelos

class UserPlan {
  final PlanType type;
  final DateTime startDate;
  final DateTime endDate;
  final int? remainingClasses;
  final List<PlanPause> pauses;

  const UserPlan({
    required this.type,
    required this.startDate,
    required this.endDate,
    this.remainingClasses,
    this.pauses = const [],
  });
}

class EmergencyContact {
  final String name;
  final String phone;

  const EmergencyContact({required this.name, required this.phone});
}

class PlanPause {
  final DateTime startDate;
  final DateTime endDate;
  final String createdBy;

  const PlanPause({
    required this.startDate,
    required this.endDate,
    required this.createdBy,
  });
}