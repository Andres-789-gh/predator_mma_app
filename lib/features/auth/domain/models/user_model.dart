import '../../../../core/constants/enums.dart';
import 'access_exception_model.dart';
import '../../../../features/plans/domain/models/plan_model.dart';

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
  final String? profilePictureUrl;
  final List<UserPlan> currentPlans;
  final String emergencyContact;
  final List<AccessExceptionModel> accessExceptions;
  final bool isActive;
  final DateTime? deletedAt;
  final String? deletedBy;

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
    this.profilePictureUrl,
    this.currentPlans = const [],
    required this.emergencyContact,
    List<AccessExceptionModel> accessExceptions = const [],
    this.isActive = true,
    this.deletedAt,
    this.deletedBy,
  }) : accessExceptions = List.unmodifiable(accessExceptions);

  String get fullName {
    final baseName = '$firstName $lastName';
    return isActive ? baseName : '$baseName (Eliminado)';
  }

  List<UserPlan> get validPlans {
    final now = DateTime.now();
    return currentPlans.where((p) => !p.isExpired(now)).toList();
  }

  bool get hasActivePlan {
    final now = DateTime.now();
    return currentPlans.any((p) => p.isActive(now));
  }

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
    String? profilePictureUrl,
    List<UserPlan>? currentPlans,
    String? emergencyContact,
    List<AccessExceptionModel>? accessExceptions,
    bool? isActive,
    DateTime? deletedAt,
    String? deletedBy,
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
      isInstructor: isInstructor ?? this.isInstructor,
      isLegacyUser: isLegacyUser ?? this.isLegacyUser,
      notificationToken: notificationToken ?? this.notificationToken,
      isWaiverSigned: isWaiverSigned ?? this.isWaiverSigned,
      waiverSignedAt: waiverSignedAt ?? this.waiverSignedAt,
      waiverSignatureUrl: waiverSignatureUrl ?? this.waiverSignatureUrl,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      currentPlans: currentPlans ?? this.currentPlans,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      accessExceptions: accessExceptions ?? this.accessExceptions,
      isActive: isActive ?? this.isActive,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
    );
  }
}

class UserPlan {
  final String subscriptionId;
  final DateTime startDate;
  final DateTime endDate;
  final int? remainingClasses;
  final List<PlanPause> pauses;
  final String planId;
  final String name;
  final double price;
  final PlanConsumptionType consumptionType;
  final List<ScheduleRule> scheduleRules;
  final int? dailyLimit;
  final bool notifiedExpiration;

  const UserPlan({
    required this.subscriptionId,
    required this.planId,
    required this.name,
    required this.price,
    required this.consumptionType,
    required this.scheduleRules,
    required this.startDate,
    required this.endDate,
    this.remainingClasses,
    this.pauses = const [],
    this.dailyLimit,
    this.notifiedExpiration = false,
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
    if (isExpired(now)) return false;
    if (isPaused(now)) return false;
    return true;
  }

  bool isExpired(DateTime now) {
    return now.isAfter(effectiveEndDate);
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
    String? subscriptionId,
    String? planId,
    String? name,
    double? price,
    PlanConsumptionType? consumptionType,
    List<ScheduleRule>? scheduleRules,
    DateTime? startDate,
    DateTime? endDate,
    int? remainingClasses,
    List<PlanPause>? pauses,
    int? dailyLimit,
    bool? notifiedExpiration,
  }) {
    return UserPlan(
      subscriptionId: subscriptionId ?? this.subscriptionId,
      planId: planId ?? this.planId,
      name: name ?? this.name,
      price: price ?? this.price,
      consumptionType: consumptionType ?? this.consumptionType,
      scheduleRules: scheduleRules ?? this.scheduleRules,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      remainingClasses: remainingClasses ?? this.remainingClasses,
      pauses: pauses ?? this.pauses,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      notifiedExpiration: notifiedExpiration ?? this.notifiedExpiration,
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
