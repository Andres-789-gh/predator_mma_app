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
  final bool isInstructor;
  final bool isLegacyUser;
  final String? notificationToken;
  final bool isWaiverSigned;
  final DateTime? waiverSignedAt;
  final String? waiverSignatureUrl;
  final UserPlan? activePlan;
  final String emergencyContact;
  final List<AccessExceptionModel> accessExceptions;

  UserModel({
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.documentId,
    required this.phoneNumber,
    required this.address,
    required this.birthDate,
    this.role = UserRole.client,
    this.isInstructor = false,
    this.isLegacyUser = false,
    this.notificationToken,
    this.isWaiverSigned = false,
    this.waiverSignedAt,
    this.waiverSignatureUrl,
    this.activePlan,
    required this.emergencyContact,
    List<AccessExceptionModel> accessExceptions = const [],
  }) : accessExceptions = List.unmodifiable(accessExceptions);

  String get fullName => '$firstName $lastName';
  
  UserModel copyWith({
    String? userId,
    String? email,
    String? firstName,
    String? lastName,
    String? documentId,
    String? phoneNumber,
    String? address,
    DateTime? birthDate,
    UserRole? role,
    bool? isInstructor,
    bool? isLegacyUser,
    String? notificationToken,
    bool? isWaiverSigned,
    DateTime? waiverSignedAt,
    String? waiverSignatureUrl,
    UserPlan? activePlan,
    String? emergencyContact,
    List<AccessExceptionModel>? accessExceptions,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      documentId: documentId ?? this.documentId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      birthDate: birthDate ?? this.birthDate,
      role: role ?? this.role,
      isInstructor: isInstructor ?? this.isInstructor, // nuevo
      isLegacyUser: isLegacyUser ?? this.isLegacyUser,
      notificationToken: notificationToken ?? this.notificationToken,
      isWaiverSigned: isWaiverSigned ?? this.isWaiverSigned,
      waiverSignedAt: waiverSignedAt ?? this.waiverSignedAt,
      waiverSignatureUrl: waiverSignatureUrl ?? this.waiverSignatureUrl,
      activePlan: activePlan ?? this.activePlan,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      accessExceptions: accessExceptions ?? this.accessExceptions,
    );
  }
}

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

  DateTime get effectiveEndDate {
    if (pauses.isEmpty) return endDate;
    
    int totalPausedDays = 0;
    for (final pause in pauses) {
      final days = pause.endDate.difference(pause.startDate).inDays;
      totalPausedDays += (days > 0 ? days : 0); 
    }
    
    return endDate.add(Duration(days: totalPausedDays));
  }

  bool isActive(DateTime now) {
    if (now.isAfter(effectiveEndDate)) return false;
    if (isPaused(now)) return false;
    return true;
  }

  bool isPaused(DateTime date) {
    if (pauses.isEmpty) return false;
    for (final pause in pauses) {
      if ((date.isAfter(pause.startDate) && date.isBefore(pause.endDate)) ||
          date.isAtSameMomentAs(pause.startDate) ||
          date.isAtSameMomentAs(pause.endDate)) {
        return true;
      }
    }
    return false;
  }

  UserPlan copyWith({
    PlanType? type,
    DateTime? startDate,
    DateTime? endDate,
    int? remainingClasses,
    List<PlanPause>? pauses,
  }) {
    return UserPlan(
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      remainingClasses: remainingClasses ?? this.remainingClasses,
      pauses: pauses ?? this.pauses,
    );
  }
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

  PlanPause copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? createdBy,
  }) {
    return PlanPause(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}