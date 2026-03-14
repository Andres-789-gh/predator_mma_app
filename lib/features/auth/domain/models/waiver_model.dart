import 'dart:typed_data';

class WaiverAnswer {
  final String question;
  final bool answer;
  final String? specification;

  const WaiverAnswer({
    required this.question,
    required this.answer,
    this.specification,
  });

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'answer': answer,
      'specification': specification,
    };
  }
}

class WaiverModel {
  final String userId;
  final bool isGuardian;
  final String signerName;
  final String signerId;
  final String signerCity;
  final String? minorName;
  final String? minorId;
  final String? minorCity;
  final List<WaiverAnswer> answers;
  final Uint8List signatureBytes;

  const WaiverModel({
    required this.userId,
    required this.isGuardian,
    required this.signerName,
    required this.signerId,
    required this.signerCity,
    this.minorName,
    this.minorId,
    this.minorCity,
    required this.answers,
    required this.signatureBytes,
  });
}
