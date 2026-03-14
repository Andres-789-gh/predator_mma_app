import '../../domain/models/waiver_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WaiverMapper {
  static Map<String, dynamic> toMap(WaiverModel waiver, String pdfUrl) {
    Map<String, dynamic> questionnaireData = {};
    for (int i = 0; i < waiver.answers.length; i++) {
      questionnaireData['q${i + 1}'] = waiver.answers[i].toMap();
    }

    Map<String, dynamic> personalInfo = {
      'signer_name': waiver.signerName,
      'signer_id': waiver.signerId,
      'signer_city': waiver.signerCity,
      'role': waiver.isGuardian ? 'Acudiente' : 'Usuario',
      'minor_name': waiver.minorName,
      'minor_id': waiver.minorId,
      'minor_city': waiver.minorCity,
    };

    return {
      'legal': {
        'is_signed': true,
        'signature_url': pdfUrl,
        'signed_at': FieldValue.serverTimestamp(),
      },
      'waiver_responses': questionnaireData,
      'waiver_personal_info': personalInfo,
    };
  }
}