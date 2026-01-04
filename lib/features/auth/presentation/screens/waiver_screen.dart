import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:signature/signature.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class WaiverScreen extends StatefulWidget {
  const WaiverScreen({super.key});

  @override
  State<WaiverScreen> createState() => _WaiverScreenState();
}

class _WaiverScreenState extends State<WaiverScreen> {
  // controla el panel de firma
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.transparent,
  );

  // controladores datos personales
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  // controladores datos menor
  final TextEditingController _minorNameController = TextEditingController();
  final TextEditingController _minorIdController = TextEditingController();
  final TextEditingController _minorCityController = TextEditingController();

  // estado
  bool _isLoading = false;
  bool _isGuardian = false;
  final Map<int, bool> _answers = {};
  final Map<int, TextEditingController> _specsControllers = {};

  // preguntas textuales pdf
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
    _nameController.dispose();
    _idController.dispose();
    _cityController.dispose();
    _minorNameController.dispose();
    _minorIdController.dispose();
    _minorCityController.dispose();
    for (var c in _specsControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // enviar formulario
  Future<void> _submitWaiver(String userId) async {
    // valida campos personales
    if (_nameController.text.trim().isEmpty ||
        _idController.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor diligencia todos los campos de la Carta de Aceptación.')),
      );
      return;
    }

    // valida campos menor
    if (_isGuardian) {
      if (_minorNameController.text.trim().isEmpty ||
          _minorIdController.text.trim().isEmpty ||
          _minorCityController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debe diligenciar los datos del menor (Nombre, Tarjeta Identidad, Ciudad).')),
        );
        return;
      }
    }

    // valida cuestionario
    if (_answers.length < _questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor responde todas las preguntas del cuestionario.')),
      );
      return;
    }

    // valida especificaciones
    for (int i = 0; i < _questions.length; i++) {
      if (_answers[i] == true) {
        if (_specsControllers[i]?.text.trim().isEmpty ?? true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Especifique su respuesta en la pregunta ${i + 1}.')),
          );
          return;
        }
      }
    }

    // valida firma
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falta la firma al final del documento.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final Uint8List? data = await _signatureController.toPngBytes();
      if (data == null) throw Exception('Error procesando firma');
      final String base64Signature = base64Encode(data);

      Map<String, dynamic> questionnaireData = {};
      for (int i = 0; i < _questions.length; i++) {
        questionnaireData['q${i + 1}'] = {
          'question': _questions[i],
          'answer': _answers[i],
          'specification': _answers[i] == true ? _specsControllers[i]?.text.trim() : null,
        };
      }

      Map<String, dynamic> personalInfo = {
        'signer_name': _nameController.text.trim(),
        'signer_id': _idController.text.trim(),
        'signer_city': _cityController.text.trim(),
        'role': _isGuardian ? 'Acudiente' : 'Usuario',
        'minor_name': _isGuardian ? _minorNameController.text.trim() : null,
        'minor_id': _isGuardian ? _minorIdController.text.trim() : null,
        'minor_city': _isGuardian ? _minorCityController.text.trim() : null,
      };

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'legal.is_signed': true,
        'legal.signature_base64': base64Signature,
        'legal.signed_at': FieldValue.serverTimestamp(),
        'waiver_responses': questionnaireData,
        'waiver_personal_info': personalInfo,
      });

      if (mounted) {
        context.read<AuthCubit>().checkAuthStatus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Documento firmado exitosamente! Bienvenido.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error guardando: $e')),
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

    final TextStyle docStyle = TextStyle(
      fontSize: 12,
      height: 1.3,
      color: textColor.withValues(alpha: 0.9),
      fontFamily: 'Roboto',
    );

    if (userId == null) return const Scaffold(body: Center(child: Text("Error de usuario")));

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Exoneración Legal", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: bgColor,
          foregroundColor: textColor,
          elevation: 0,
          scrolledUnderElevation: 0,
      ),
        backgroundColor: bgColor,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.red))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    
                  // encabezado
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("3132184502 / 3132184504 / 3132184508", style: docStyle.copyWith(fontSize: 10)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.public, size: 12, color: textColor),
                                const SizedBox(width: 4),
                                Icon(Icons.camera_alt, size: 12, color: textColor),
                                const SizedBox(width: 4),
                                Icon(Icons.play_circle_filled, size: 12, color: textColor),
                                const SizedBox(width: 6),
                                Text("PREDATOR_FIGHTCLUB", style: docStyle.copyWith(fontWeight: FontWeight.w900, fontSize: 13)),
                              ],
                            ),
                            Text("AVENIDA BOYACA 73A-42 / BOGOTA DC", style: docStyle.copyWith(fontSize: 10)),
                            Text("FIGHTCLUB.PREDATOR@GMAIL.COM", style: docStyle.copyWith(fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Image.asset(
                          'assets/images/predator_waiver_logo.png',
                          fit: BoxFit.contain,
                          height: 70,
                          errorBuilder: (c, e, s) => const Icon(Icons.shield, size: 50, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                    const Divider(thickness: 2),
                    const SizedBox(height: 10),

                    // titulo
                    Text(
                      "CONCENTIMIENTO INFORMADO",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 15),

                    // parrafos intro
                    RichText(
                      textAlign: TextAlign.justify,
                      text: TextSpan(
                        style: docStyle,
                        children: [
                          const TextSpan(text: "Las Artes Marciales Mixtas (conocidas como MMA por sus siglas en inglés) son definidas por Acevedo y Cheung (2011)"),
                          WidgetSpan(
                            child: Transform.translate(
                              offset: const Offset(0, -4),
                              child: const Text("1", style: TextStyle(fontSize: 9)),
                            ),
                          ),
                          const TextSpan(text: ", como una disciplina de combate ecléctica, es decir que acoplan técnicas y tácticas de diversos deportes de combate así como de artes marciales."),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Con base en lo anterior se debe concientizar que la práctica y competencia en MMA así como de las categorías disciplinares que la componen: Grappling (lucha), Stricking (combate con golpes) y acondicionamiento físico, puede desarrollar la:",
                      style: docStyle,
                      textAlign: TextAlign.justify,
                    ),
                    const SizedBox(height: 10),

                    // cita 1
                    _buildQuoteBlock(
                      "\"... fuerza absoluta de sus músculos, así como la rápida y la estática. El atleta adquiere gran cantidad de hábitos motrices especiales, así como el desarrollo de la resistencia...además, gran movilidad de los procesos nerviosos, ya que la actividad del luchador y la cantidad de movimientos posibles (ataques, defensas, contra llaves, tácticas) es muy grande, esto implica que se desarrolle en quienes lo practiquen durante mucho tiempo una gran sensibilidad propioceptiva\".",
                      docStyle,
                    ),
                    const SizedBox(height: 10),

                    // cita 2
                    _buildQuoteBlock(
                      "La enseñanza de los deportes de combate siempre se hará teniendo como base la educación en valores, no se puede obviar que el estudiante valora muy positivamente la práctica de estos deportes como defensa personal... el aprendizaje de las técnicas de combate parece dar confianza y seguridad a sus practicantes. (José Montero, 2009, Enfoque para el estudio del hecho histórico deportivo, con énfasis en los deportes de combate).",
                      docStyle,
                    ),
                    const SizedBox(height: 10),

                    Text(
                      "Así también la práctica de disciplinas de combate puede conllevar lesiones osteomusculares u otros tipos de afectación a la salud debido a las técnicas que se ejecutan (golpes, proyecciones, sumisiones y/o técnicas de transición) y rutinas de entrenamiento condicional que se realizan.",
                      style: docStyle,
                      textAlign: TextAlign.justify,
                    ),
                    const SizedBox(height: 10),

                    Divider(color: textColor, thickness: 1, endIndent: 200),
                    
                    // nota
                    RichText(
                      text: TextSpan(
                        style: docStyle.copyWith(fontSize: 10, color: textColor.withValues(alpha: 0.7)),
                        children: const [
                          TextSpan(text: "1 Acevedo, W. y Cheung, M. Una visión histórica de las artes marciales mixtas en China. "),
                          TextSpan(text: "Revista de Artes Marciales Asiáticas", style: TextStyle(fontStyle: FontStyle.italic)),
                          TextSpan(text: ", 6 (2), 29-44."),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // txt previo cuestionario
                    Text(
                      "Las siguientes preguntas deben ser leídas cuidadosamente y respondidas con honestidad; el manifestar que si presenta o ha presentado alguno de los síntomas y/o diagnósticos no le excluye de la participación en el proceso de preparación física, práctica y competencia deportiva desarrollado por PREDATOR FIGHT CLUB. No obstante, el siguiente cuestionario se asume como una declaración por parte del futuro usuario o acudiente del mismo que se encuentra en condición de iniciar un proceso de preparación física y/o entrenamiento deportivo.",
                      style: docStyle,
                      textAlign: TextAlign.justify,
                    ),
                    const SizedBox(height: 10),
                    
                    // nota
                    RichText(
                      textAlign: TextAlign.justify,
                      text: TextSpan(
                        style: docStyle,
                        children: const [
                          TextSpan(text: "Nota: ", style: TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: "en el apartado de "),
                          TextSpan(text: "Especificaciones ", style: TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: "por favor describa detalladamente según corresponda a la pregunta: por ejemplo, si se le pregunta si le han diagnosticado un problema cardíaco, y su respuesta es afirmativa, debe suministrar la información referente y pertinente de este (cuál es, qué contraindicaciones tiene para la actividad física, que recomendaciones tiene por parte de su médico, etc)."),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // cuestionario par-q
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: textColor.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "CUESTIONARIO DE PRE-PARTICIPACIÓN A LA ACTIVIDAD FÍSICA (PAR-Q) SI/NO",
                            style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 15),
                          ...List.generate(_questions.length, (index) => _buildQuestionItem(index, textColor)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // carta de aceptacion
                  Text(
                    "Carta de Aceptación CONCENTIMIENTO INFORMADO",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // formulario yo...
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      Text("Yo ", style: TextStyle(color: textColor, fontSize: 13)),
                      _buildInlineTextField(_nameController, "Nombre completo", 180, textColor),
                      Text(" con Cédula de identificación Número ", style: TextStyle(color: textColor, fontSize: 13)),
                      _buildInlineTextField(_idController, "No. Documento", 110, textColor),
                      Text(" de ", style: TextStyle(color: textColor, fontSize: 13)),
                      _buildInlineTextField(_cityController, "Ciudad", 90, textColor),
                      Text(" en calidad de:", style: TextStyle(color: textColor, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // seleccion rol
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("USUARIO ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Transform.scale(
                        scale: 0.9,
                        child: Radio<bool>(
                          value: false,
                          groupValue: _isGuardian,
                          activeColor: Colors.red,
                          visualDensity: VisualDensity.compact,
                          onChanged: (val) => setState(() => _isGuardian = val!),
                        ),
                      ),
                      const SizedBox(width: 15),
                      const Text("y/o", style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 15),
                      const Text("ACUDIENTE ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Transform.scale(
                        scale: 0.9,
                        child: Radio<bool>(
                          value: true,
                          groupValue: _isGuardian,
                          activeColor: Colors.red,
                          visualDensity: VisualDensity.compact,
                          onChanged: (val) => setState(() => _isGuardian = val!),
                        ),
                      ),
                    ],
                  ),

                  // campos menor
                  if (_isGuardian)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          Text("del menor ", style: TextStyle(color: textColor, fontSize: 13)),
                          _buildInlineTextField(_minorNameController, "Nombre completo del menor", 180, textColor),
                          Text(" identificado con tarjeta de identidad número ", style: TextStyle(color: textColor, fontSize: 13)),
                          _buildInlineTextField(_minorIdController, "No. Documento", 110, textColor),
                          Text(" de ", style: TextStyle(color: textColor, fontSize: 13)),
                          _buildInlineTextField(_minorCityController, "Ciudad", 90, textColor),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                    // declaracion final
                    Text(
                      "Declaro (a) que en forma voluntaria se ha decidido participar en el proceso de preparación física y/o práctica deportiva desarrollados por PREDATOR FIGHT CLUB además me (nos) comprometo (emos) a atender las recomendaciones del equipo asesor y las siguientes observaciones:",
                      style: docStyle,
                      textAlign: TextAlign.justify,
                    ),
                    const SizedBox(height: 10),

                    // puntos declaracion
                    _buildDeclarationPoint("Que la información que suministro en este documento es veraz y que toda omisión de parte del usuario puede constituir un atentado contra su integridad personal, exonerando desde ya de toda responsabilidad a ", "PREDATOR FIGHT CLUB.", textColor),
                    _buildDeclarationPoint("Que se ha recibido la suficiente información sobre los beneficios y la naturaleza de los procedimientos, así como de los riesgos ocasionados por incumplimiento de las recomendaciones del equipo de entrenadores y profesionales asociados a ", "PREDATOR FIGHT CLUB.", textColor),
                    _buildDeclarationPoint("Asumo todos los riesgos asociados con la participación en los procesos de preparación física, práctica deportiva y eventos desarrollados por ", "PREDATOR FIGHT CLUB; no limitados a lesiones, enfermedades y/o accidentes, también por el contacto con otros participantes, las consecuencias del clima (incluyendo temperatura y/o humedad) y en general todo riesgo que declaro ser conocidos y valorados por mí (nosotros). En el caso de menores de edad (18 años) la responsabilidad por los riesgos mencionados anteriormente es asumidos por el acudiente del menor con el diligenciamiento de este documento.", textColor, boldPrefix: "PREDATOR FIGHT CLUB"),
                    _buildDeclarationPoint("Autorizo a ", "PREDATOR FIGHT CLUB el uso de fotografías, películas, videos, grabaciones, y cualquier otro medio de registro realizado en sus instalaciones o eventos para cualquier uso legítimo sin compensación económica alguna.", textColor, boldSuffix: "PREDATOR FIGHT CLUB"),

                    const SizedBox(height: 30),

                    // footer de datos
                    Container(
                      padding: const EdgeInsets.only(top: 10, bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ValueListenableBuilder(
                            valueListenable: _nameController,
                            builder: (context, value, child) => Text("Nombre: ${value.text.toUpperCase()}", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 5),
                          ValueListenableBuilder(
                            valueListenable: _idController,
                            builder: (context, value, child) => Text("CC: ${value.text}", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 5),
                          Text("Fecha: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),

                    // pad de firma
                    Text("Firma:", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 5),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(5),
                        color: Colors.white,
                      ),
                      child: Signature(
                        controller: _signatureController,
                        height: 150,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _signatureController.clear(),
                        icon: const Icon(Icons.refresh, size: 16, color: Colors.grey),
                        label: const Text("Borrar Firma", style: TextStyle(color: Colors.grey)),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // btn
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
      ),
    );
  }

  // widgets auxiliares
  Widget _buildQuoteBlock(String text, TextStyle style) {
    return Container(
      padding: const EdgeInsets.only(left: 10),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Colors.red, width: 3)),
      ),
      child: Text(text, style: style.copyWith(fontStyle: FontStyle.italic), textAlign: TextAlign.justify),
    );
  }

  Widget _buildDeclarationPoint(String prefix, String suffix, Color textColor, {String? boldPrefix, String? boldSuffix}) {
    if (boldPrefix != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("• ", style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: RichText(
                textAlign: TextAlign.justify,
                text: TextSpan(
                  style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.9), height: 1.3, fontFamily: 'Roboto'),
                  children: [
                    TextSpan(text: prefix),
                    TextSpan(text: boldPrefix, style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: suffix.replaceAll(boldPrefix, "")),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (boldSuffix != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("• ", style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: RichText(
                textAlign: TextAlign.justify,
                text: TextSpan(
                  style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.9), height: 1.3, fontFamily: 'Roboto'),
                  children: [
                    TextSpan(text: prefix),
                    TextSpan(text: boldSuffix, style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: suffix.replaceAll(boldSuffix, "")),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• ", style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: RichText(
              textAlign: TextAlign.justify,
              text: TextSpan(
                style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.9), height: 1.3, fontFamily: 'Roboto'),
                children: [
                  TextSpan(text: prefix),
                  TextSpan(text: suffix, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineTextField(TextEditingController controller, String hint, double width, Color textColor) {
    return Container(
      width: width,
      padding: EdgeInsets.zero,
      child: TextField(
        controller: controller,
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.normal),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textColor.withValues(alpha: 0.5))),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red)),
        ),
      ),
    );
  }

  Widget _buildQuestionItem(int index, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_questions[index], style: TextStyle(fontWeight: FontWeight.w500, color: textColor, fontSize: 13)),
          Row(
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  title: Text("SÍ", style: TextStyle(fontSize: 13, color: textColor)),
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
              Expanded(
                child: RadioListTile<bool>(
                  title: Text("NO", style: TextStyle(fontSize: 13, color: textColor)),
                  value: false,
                  groupValue: _answers[index],
                  activeColor: Colors.green,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    setState(() {
                      _answers[index] = val!;
                      _specsControllers[index]?.clear();
                    });
                  },
                ),
              ),
            ],
          ),
          if (_answers[index] == true)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: TextField(
                controller: _specsControllers[index],
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: "Especificaciones:",
                  labelStyle: TextStyle(color: textColor.withValues(alpha: 0.7)),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3))),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                ),
              ),
            ),
          Divider(color: Colors.grey.withValues(alpha: 0.2)),
        ],
      ),
    );
  }
}