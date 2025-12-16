import 'package:cloud_firestore/cloud_firestore.dart';
// importamos el archivo donde definimos los roles y planes
import '../../../../core/constants/enums.dart';

class UserModel {
  final String userId;
  final String email; // correo electronico
  final String firstName; // primer nombre
  final String lastName; // apellidos
  final String documentId; // numero documento de identificacion
  final String phoneNumber; // numero de telefono
  final String address; // direccion de residencia
  final DateTime birthDate; // fecha de nacimiento
  final UserRole role; // rol de usuario
  final bool isLegacyUser; // usuario antiguo?
  final String? notificationToken; // codigo tecnico para enviar notificaciones al celular

  // control legal (exoneracion de responsabilidad)
  final bool isWaiverSigned; // ya firmo el documento de exoneracion del gimnasio?
  final DateTime? waiverSignedAt; // fecha y hora exacta en que firmo
  final String? waiverSignatureUrl; // link de internet donde esta guardada la imagen de la firma del doc

  // datos complejos (sub-modelos)
  final UserPlan? activePlan; // informacion del plan actual, si tiene uno (fechas, tipo)
  final EmergencyContact? emergencyContact; // contacto de emergencia

  // Constructor
  const UserModel({
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.documentId,
    required this.phoneNumber,
    required this.address,
    required this.birthDate,
    this.role = UserRole.client, // si no se especifica el rol, por defecto sera cliente
    this.isLegacyUser = false, // por defecto un usuario nuevo no es antiguo
    this.notificationToken, // puede ser null porque al registrarse aun no se tiene el token
    this.isWaiverSigned = false, // por defecto no ha firmado nada al registrarse
    this.waiverSignedAt,
    this.waiverSignatureUrl,
    this.activePlan,
    this.emergencyContact,
  });

  // unir nombre y apellido
  String get fullName => '$firstName $lastName';

  // funcion (factory): toma los datos desordenados de firebase (map)
  // y los convierte en el obj usermodel ordenado
  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    return UserModel(
      userId: docId,
      // si el email viene vacio, ponemos texto vacio '' para que no falle
      email: map['email'] ?? '',
      // busca dentro de la carpeta personal_info
      firstName: map['personal_info']?['first_name'] ?? '',
      lastName: map['personal_info']?['last_name'] ?? '',
      documentId: map['personal_info']?['document_id'] ?? '',
      phoneNumber: map['personal_info']?['phone_number'] ?? '',
      address: map['personal_info']?['address'] ?? '',
      
      // manejo seguro de fechas. si viene nulo, lanza error o pone fecha actual
      // (aqui usa fecha actual por seguridad momentanea)
      birthDate: (map['personal_info']?['birth_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      
      // convertir el texto de firebase al enum de roles de dart
      role: UserRole.values.firstWhere(
        (e) => e.name == (map['role'] ?? 'client'),
        orElse: () => UserRole.client,
      ),
      
      isLegacyUser: map['is_legacy_user'] ?? false,
      notificationToken: map['notification_token'],

      // datos legales
      isWaiverSigned: map['legal']?['is_signed'] ?? false,
      waiverSignedAt: (map['legal']?['signed_at'] as Timestamp?)?.toDate(),
      waiverSignatureUrl: map['legal']?['signature_url'],

      // si tiene plan, usa el sub-modelo userplan para convertirlo
      activePlan: map['active_plan'] != null 
          ? UserPlan.fromMap(map['active_plan']) 
          : null,
      
      // igual para el contacto de emergencia
      emergencyContact: map['emergency_contact'] != null
          ? EmergencyContact.fromMap(map['emergency_contact'])
          : null,
    );
  }

  // esta funcion hace lo contrario: toma el obj y lo vuelve un mapa para poder guardarlo en firebase
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role.name, // guarda "client" o "admin" como texto
      'is_legacy_user': isLegacyUser,
      'notification_token': notificationToken,
      // agrupa datos personales para orden en la bd
      'personal_info': {
        'first_name': firstName,
        'last_name': lastName,
        'document_id': documentId,
        'phone_number': phoneNumber,
        'address': address,
        // convierte la fecha de dart a timestamp de firebase
        'birth_date': Timestamp.fromDate(birthDate),
      },
      'legal': {
        'is_signed': isWaiverSigned,
        'signed_at': waiverSignedAt != null ? Timestamp.fromDate(waiverSignedAt!) : null,
        'signature_url': waiverSignatureUrl,
      },
      // llama al tomap de los sub-objetos
      'active_plan': activePlan?.toMap(),
      'emergency_contact': emergencyContact?.toMap(),
    };
  }
}

// Clases pequeñas (sub-modelos)

class UserPlan {
  final PlanType type; // tipo de plan
  final DateTime startDate; // cuando inicia el plan
  final DateTime endDate; // cuando se vence el plan
  final int? remainingClasses; // clases restantes para planes personalizados (4, 8, 12)
  final List<PlanPause> pauses; // lista de pausas o congelamientos

  const UserPlan({
    required this.type,
    required this.startDate,
    required this.endDate,
    this.remainingClasses,
    this.pauses = const [], // si no hay pausas, arranca con lista vacia
  });

  factory UserPlan.fromMap(Map<String, dynamic> map) {
    return UserPlan(
      type: PlanType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'full'),
        orElse: () => PlanType.full,
      ),
      startDate: (map['start_date'] as Timestamp).toDate(),
      endDate: (map['end_date'] as Timestamp).toDate(),
      remainingClasses: map['remaining_classes'],

      // convierte la lista de pausas de firebase a dart
      pauses: (map['pauses'] as List<dynamic>?)
          ?.map((x) => PlanPause.fromMap(x))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'start_date': Timestamp.fromDate(startDate),
    'end_date': Timestamp.fromDate(endDate),
    'remaining_classes': remainingClasses,
    'pauses': pauses.map((e) => e.toMap()).toList(),
  };
}

class EmergencyContact {
  final String name;
  final String phone;

  const EmergencyContact({required this.name, required this.phone});

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'phone': phone,
  };
}

class PlanPause {
  final DateTime startDate; // cuando inicia la pausa
  final DateTime endDate; // cuando termina la pausa
  final String createdBy; // id del admin que creo la pausa

  const PlanPause({
    required this.startDate,
    required this.endDate,
    required this.createdBy,
  });

  factory PlanPause.fromMap(Map<String, dynamic> map) {
    return PlanPause(
      startDate: (map['start_date'] as Timestamp).toDate(),
      endDate: (map['end_date'] as Timestamp).toDate(),
      createdBy: map['created_by'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'start_date': Timestamp.fromDate(startDate),
    'end_date': Timestamp.fromDate(endDate),
    'created_by': createdBy,
  };
}