import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewWaiverDialog extends StatelessWidget {
  final String userId;

  const ViewWaiverDialog({super.key, required this.userId});

  Future<Map<String, dynamic>?> _fetchWaiverData() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      if (data['legal']?['is_signed'] == true) {
        return {
          'responses': data['waiver_responses'],
          'personalInfo': data['waiver_personal_info'],
          'signature': data['legal']['signature_base64'],
        };
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _fetchWaiverData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(40.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text("Descargando documento legal..."),
                ],
              ),
            );
          }

          final data = snapshot.data;

          if (data == null) {
            return const Padding(
              padding: EdgeInsets.all(30.0),
              child: Text(
                "No se encontró el documento de exoneración firmado.",
              ),
            );
          }

          final responses = data['responses'] as Map<String, dynamic>? ?? {};
          final signatureBase64 = data['signature'] as String?;

          return Container(
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              children: [
                AppBar(
                  title: const Text(
                    "Exoneración Firmada",
                    style: TextStyle(fontSize: 16),
                  ),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text(
                        "CUESTIONARIO",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...responses.entries.map((entry) {
                        final answerData = entry.value as Map<String, dynamic>;
                        final question = answerData['question'] ?? '';
                        final answer = answerData['answer'] == true
                            ? 'SÍ'
                            : 'NO';
                        final spec = answerData['specification'];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                question,
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Respuesta: $answer",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: answer == 'SÍ'
                                      ? Colors.red
                                      : Colors.green,
                                ),
                              ),
                              if (spec != null && spec.toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    "Detalle: $spec",
                                    style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: 40),
                      const Text(
                        "FIRMA REGISTRADA",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (signatureBase64 != null)
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            color: Colors.white,
                          ),
                          child: Image.memory(
                            base64Decode(signatureBase64),
                            fit: BoxFit.contain,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
