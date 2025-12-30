import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:signature/signature.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class WaiverScreen extends StatefulWidget {
  const WaiverScreen({super.key});

  @override
  State<WaiverScreen> createState() => _WaiverScreenState();
}

class _WaiverScreenState extends State<WaiverScreen> {
  // Controlador de firma
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.transparent,
  );

  // Estado del formulario
  bool _isLoading = false;
  final Map<int, bool> _answers = {}; // Índice de pregunta -> SI/NO
  final Map<int, TextEditingController> _specsControllers = {}; // Especificaciones

  // Preguntas del documento
  final List<String> _questions = [
    "1. ¿Alguna vez su doctor le ha diagnosticado problemas cardíacos?",
    "2. ¿Tiene dolores en el pecho con frecuencia?",
    "3. ¿Tiende a perder el conocimiento o equilibrio como resultados de mareos?",
    "4. ¿Alguna vez le han diagnosticado que tiene la tensión arterial demasiado alta?",
    "5. ¿Hay algún problema osteo-articular o muscular que puede agravarse con la realización de actividad física y/o práctica deportiva de combate?",
    "6. ¿Tiene conocimiento, por experiencia propia o debido al consejo de un médico, de cualquier otra razón que le impida hacer actividad física y/o práctica deportiva de combate?",
  ];

  @override
  void dispose() {
    _signatureController.dispose();
    for (var c in _specsControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // Lógica de guardado
  Future<void> _submitWaiver(String userId) async {
    // 1. Validaciones
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes firmar el documento al final.')),
      );
      return;
    }

    if (_answers.length < _questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor responde todas las preguntas del cuestionario.')),
      );
      return;
    }

    // Validar especificaciones obligatorias
    for (int i = 0; i < _questions.length; i++) {
      if (_answers[i] == true) {
        if (_specsControllers[i]?.text.trim().isEmpty ?? true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Debes especificar tu respuesta en la pregunta ${i + 1}.')),
          );
          return;
        }
      }
    }

    setState(() => _isLoading = true);

    try {
      // 2. Convertir firma a imagen
      final Uint8List? data = await _signatureController.toPngBytes();
      if (data == null) throw Exception('Error al procesar la firma');

      // 3. Subir a Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('waivers')
          .child(userId)
          .child('signature_${DateTime.now().millisecondsSinceEpoch}.png');

      await storageRef.putData(data);
      final signatureUrl = await storageRef.getDownloadURL();

      // 4. Preparar datos del cuestionario
      Map<String, dynamic> medicalData = {};
      for (int i = 0; i < _questions.length; i++) {
        medicalData['q${i + 1}'] = {
          'question': _questions[i],
          'answer': _answers[i],
          'specification': _answers[i] == true ? _specsControllers[i]?.text.trim() : null,
        };
      }

      // 5. Actualizar Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'legal.is_signed': true,
        'legal.signature_url': signatureUrl,
        'legal.signed_at': FieldValue.serverTimestamp(),
        'medical_history': medicalData, // Guardamos las respuestas médicas por seguridad
      });

      if (mounted) {
        // Recargar AuthCubit para que la app sepa que ya firmó
        context.read<AuthCubit>().checkAuthStatus();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Documento firmado exitosamente! Bienvenido.')),
        );
        Navigator.pop(context); // Volver al Home (que ahora estará desbloqueado)
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error guardando firma: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.select((AuthCubit c) {
      final state = c.state;
      return (state is AuthAuthenticated) ? state.user.userId : null;
    });
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    if (userId == null) return const Scaffold(body: Center(child: Text("Error de usuario")));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Exoneración Legal", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      backgroundColor: bgColor,
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  
                  // --- 1. ENCABEZADO MODIFICADO (HORIZONTAL) ---
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // COLUMNA IZQUIERDA: INFORMACIÓN
                        Expanded(
                          flex: 7, 
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "PREDATOR FIGHTCLUB", 
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textColor)
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "3132184502 / 3132184504 / 3132184500\nAVENIDA BOYACA # 73A - 42 / BOGOTA DC", 
                                style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.8), height: 1.3)
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "FIGHTCLUB.PREDATOR@GMAIL.COM", 
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor)
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(width: 10),

                        // COLUMNA DERECHA: LOGO
                        Expanded(
                          flex: 3, 
                          child: Image.asset(
                            'assets/images/logo_predator.png',
                            fit: BoxFit.contain,
                            height: 80, // Control de altura para que no explote
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.shield, size: 50, color: Colors.red);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(thickness: 2, height: 30),

                  // --- TEXTO INTRODUCTORIO LITERAL  ---
                  Text(
                    "CONSENTIMIENTO INFORMADO",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Las Artes Marciales Mixtas (conocidas como MMA por sus siglas en inglés) son definidas por Acevedo y Cheung (2011), como una disciplina de combate ecléctica, es decir que acoplan técnicas y tácticas de diversos deportes de combate así como de artes marciales.\n\n"
                    "Con base en lo anterior se debe concientizar que la práctica y competencia en MMA así como de las categorías disciplinares que la componen: Grappling (lucha), Stricking (combate con golpes) y acondicionamiento físico, puede desarrollar la fuerza absoluta de sus músculos, así como la rápida y la estática... Además, gran movilidad de los procesos nerviosos, ya que la actividad del luchador implica una gran cantidad de movimientos posibles (ataques, defensas, contra llaves, tácticas).\n\n"
                    "Así también la práctica de disciplinas de combate puede conllevar lesiones osteomusculares u otros tipos de afectación a la salud debido a las técnicas que se ejecutan (golpes, proyecciones, sumisiones) y rutinas de entrenamiento condicional.",
                    style: TextStyle(fontSize: 13, height: 1.4, color: textColor.withValues(alpha: 0.8)),
                    textAlign: TextAlign.justify,
                  ),
                  const SizedBox(height: 20),

                  // --- CUESTIONARIO PAR-Q ---
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "CUESTIONARIO DE PRE-PARTICIPACIÓN (PAR-Q)",
                          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Responda con honestidad. Si marca SÍ, debe especificar.",
                          style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.6)),
                        ),
                        const SizedBox(height: 10),
                        ...List.generate(_questions.length, (index) {
                          return _buildQuestionItem(index, textColor);
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- DECLARACIÓN FINAL LITERAL  ---
                  Text(
                    "DECLARACIÓN Y ACEPTACIÓN",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "1. Declaro que voluntariamente he decidido participar en el proceso de preparación física y práctica deportiva desarrollados por PREDATOR FIGHT CLUB.\n\n"
                    "2. Que la información suministrada en este documento es veraz y toda omisión puede constituir un atentado contra mi integridad personal, exonerando de toda responsabilidad a PREDATOR FIGHT CLUB.\n\n"
                    "3. Asumo todos los riesgos asociados con la participación, no limitados a lesiones, enfermedades y/o accidentes, contacto con otros participantes y consecuencias del clima.\n\n"
                    "4. Autorizo a PREDATOR FIGHT CLUB el uso de fotografías, videos y grabaciones realizados en sus instalaciones para cualquier uso legítimo sin compensación económica.",
                    style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.8), fontStyle: FontStyle.italic),
                  ),

                  const SizedBox(height: 20),

                  // --- PAD DE FIRMA ---
                  Text("FIRMA DEL USUARIO", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 5),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white, // Fondo blanco para que la firma se vea bien
                    ),
                    child: Signature(
                      controller: _signatureController,
                      height: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _signatureController.clear(),
                        icon: const Icon(Icons.refresh, size: 16, color: Colors.grey),
                        label: const Text("Borrar Firma", style: TextStyle(color: Colors.grey)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // --- BOTÓN FINAL ---
                  SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[900],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _submitWaiver(userId),
                      child: const Text(
                        "ACEPTAR Y FIRMAR CONTRATO",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // Widget auxiliar para cada pregunta
  Widget _buildQuestionItem(int index, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_questions[index], style: TextStyle(fontWeight: FontWeight.w500, color: textColor)),
          Row(
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  title: Text("NO", style: TextStyle(fontSize: 14, color: textColor)),
                  value: false,
                  groupValue: _answers[index],
                  activeColor: Colors.green,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    setState(() {
                      _answers[index] = val!;
                      _specsControllers[index]?.clear(); // Limpiar si cambia a NO
                    });
                  },
                ),
              ),
              Expanded(
                child: RadioListTile<bool>(
                  title: Text("SÍ", style: TextStyle(fontSize: 14, color: textColor)),
                  value: true,
                  groupValue: _answers[index],
                  activeColor: Colors.red,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    setState(() {
                      _answers[index] = val!;
                      _specsControllers.putIfAbsent(index, () => TextEditingController());
                    });
                  },
                ),
              ),
            ],
          ),
          // Campo de especificaciones si marca SÍ 
          if (_answers[index] == true)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: TextField(
                controller: _specsControllers[index],
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: "Especifique (Obligatorio)",
                  labelStyle: const TextStyle(color: Colors.red),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3))),
                ),
              ),
            ),
          Divider(color: Colors.grey.withValues(alpha: 0.2)),
        ],
      ),
    );
  }
}