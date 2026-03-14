import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../domain/models/waiver_model.dart';
import '../mappers/waiver_mapper.dart';

class WaiverService {
  // procesa contrato completo y sube a servidores
  Future<void> processAndSaveWaiver(WaiverModel waiver) async {
    final pdfBytes = await _generatePdf(waiver);
    final pdfUrl = await _uploadToStorage(waiver.userId, pdfBytes);
    await _updateFirestore(waiver, pdfUrl);
  }

  // genera documento pdf en memoria
  Future<Uint8List> _generatePdf(WaiverModel waiver) async {
    final pdf = pw.Document();
    pw.MemoryImage? logoImage;

    try {
      final logoData = await rootBundle.load('assets/images/waiver_oscuro.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      // ignora fallo de imagen
    }

    final signatureImage = pw.MemoryImage(waiver.signatureBytes);
    final fechaActual = DateFormat('dd/MM/yyyy').format(DateTime.now());

    const styleNormal = pw.TextStyle(fontSize: 10, lineSpacing: 1.5);
    final styleBold = pw.TextStyle(
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
      lineSpacing: 1.5,
    );
    final styleItalic = pw.TextStyle(
      fontSize: 10,
      fontStyle: pw.FontStyle.italic,
      lineSpacing: 1.5,
    );
    const styleSmall = pw.TextStyle(fontSize: 8, color: PdfColors.grey800);

    // dibuja iconos redes
    const svgFb =
        '<svg viewBox="0 0 320 512"><path d="M279.14 288l14.22-92.66h-88.91v-60.13c0-25.35 12.42-50.06 52.24-50.06h40.42V6.26S260.43 0 225.36 0c-73.22 0-121.08 44.38-121.08 124.72v70.62H22.89V288h81.39v224h100.17V288z"/></svg>';
    const svgIg =
        '<svg viewBox="0 0 448 512"><path d="M224.1 141c-63.6 0-114.9 51.3-114.9 114.9s51.3 114.9 114.9 114.9S339 319.5 339 255.9 287.7 141 224.1 141zm0 189.6c-41.1 0-74.7-33.5-74.7-74.7s33.5-74.7 74.7-74.7 74.7 33.5 74.7 74.7-33.6 74.7-74.7 74.7zm146.4-194.3c0 14.9-12 26.8-26.8 26.8-14.9 0-26.8-12-26.8-26.8s12-26.8 26.8-26.8 26.8 12 26.8 26.8zm76.1 27.2c-1.7-35.9-9.9-67.7-36.2-93.9-26.2-26.2-58-34.4-93.9-36.2-37-2.1-147.9-2.1-184.9 0-35.8 1.7-67.6 9.9-93.9 36.1s-34.4 58-36.2 93.9c-2.1 37-2.1 147.9 0 184.9 1.7 35.9 9.9 67.7 36.2 93.9s58 34.4 93.9 36.2c37 2.1 147.9 2.1 184.9 0 35.9-1.7 67.7-9.9 93.9-36.2 26.2-26.2 34.4-58 36.2-93.9 2.1-37 2.1-147.8 0-184.8zM398.8 388c-7.8 19.6-22.9 34.7-42.6 42.6-29.5 11.7-99.5 9-132.1 9s-102.7 2.6-132.1-9c-19.6-7.8-34.7-22.9-42.6-42.6-11.7-29.5-9-99.5-9-132.1s-2.6-102.7 9-132.1c7.8-19.6 22.9-34.7 42.6-42.6 29.5-11.7 99.5-9 132.1-9s102.7-2.6 132.1 9c19.6 7.8 34.7 22.9 42.6 42.6 11.7 29.5 9 99.5 9 132.1s2.7 102.7-9 132.1z"/></svg>';
    const svgYt =
        '<svg viewBox="0 0 576 512"><path d="M549.655 124.083c-6.281-23.65-24.787-42.276-48.284-48.597C458.781 64 288 64 288 64S117.22 64 74.629 75.486c-23.497 6.322-42.003 24.947-48.284 48.597-11.412 42.867-11.412 132.305-11.412 132.305s0 89.438 11.412 132.305c6.281 23.65 24.787 41.5 48.284 47.821C117.22 448 288 448 288 448s170.78 0 213.371-11.486c23.497-6.321 42.003-24.171 48.284-47.821 11.412-42.867 11.412-132.305 11.412-132.305s0-89.438-11.412-132.305zm-317.51 213.508V175.185l142.739 81.205-142.739 81.201z"/></svg>';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(50),
        build: (pw.Context context) => [
          // encabeza pdf
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "3132184502 / 3108021266 / 3132184508",
                    style: styleSmall,
                  ),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    children: [
                      pw.SvgImage(svg: svgFb, height: 9),
                      pw.SizedBox(width: 4),
                      pw.SvgImage(svg: svgIg, height: 9),
                      pw.SizedBox(width: 4),
                      pw.SvgImage(svg: svgYt, height: 9),
                      pw.SizedBox(width: 6),
                      pw.Text(
                        "PREDATOR_FIGHTCLUB",
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    "AVENIDA BOYACA 73A-42 / BOGOTA DC",
                    style: styleSmall,
                  ),
                  pw.Text(
                    "FIGHTCLUB.PREDATOR@GMAIL.COM",
                    style: styleSmall.copyWith(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              if (logoImage != null)
                pw.Container(height: 45, child: pw.Image(logoImage)),
            ],
          ),
          pw.Divider(thickness: 1.5, color: PdfColors.black),
          pw.SizedBox(height: 15),

          // titula documento
          pw.Center(
            child: pw.Text(
              "CONCENTIMIENTO INFORMADO",
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 15),

          pw.Paragraph(
            text:
                "Las Artes Marciales Mixtas (conocidas como MMA por sus siglas en inglés) son definidas por Acevedo y Cheung (2011)¹, como una disciplina de combate ecléctica, es decir que acoplan técnicas y tácticas de diversos deportes de combate así como de artes marciales.",
            style: styleNormal,
            textAlign: pw.TextAlign.justify,
          ),
          pw.Paragraph(
            text:
                "Con base en lo anterior se debe concientizar que la práctica y competencia en MMA así como de las categorías disciplinares que la componen: Grappling (lucha), Stricking (combate con golpes) y acondicionamiento físico, puede desarrollar la:",
            style: styleNormal,
            textAlign: pw.TextAlign.justify,
          ),

          // dibuja citas
          pw.Container(
            padding: const pw.EdgeInsets.only(left: 10),
            margin: const pw.EdgeInsets.only(bottom: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(color: PdfColors.red900, width: 2),
              ),
            ),
            child: pw.Text(
              "\"... fuerza absoluta de sus músculos, así como la rápida y la estática. El atleta adquiere gran cantidad de hábitos motrices especiales, así como el desarrollo de la resistencia...además, gran movilidad de los procesos nerviosos, ya que la actividad del luchador y la cantidad de movimientos posibles (ataques, defensas, contra llaves, tácticas) es muy grande, esto implica que se desarrolle en quienes lo practiquen durante mucho tiempo una gran sensibilidad propioceptiva\".",
              style: styleItalic,
              textAlign: pw.TextAlign.justify,
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.only(left: 10),
            margin: const pw.EdgeInsets.only(bottom: 15),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(color: PdfColors.red900, width: 2),
              ),
            ),
            child: pw.Text(
              "La enseñanza de los deportes de combate siempre se hará teniendo como base la educación en valores, no se puede obviar que el estudiante valora muy positivamente la práctica de estos deportes como defensa personal... el aprendizaje de las técnicas de combate parece dar confianza y seguridad a sus practicantes. (José Montero, 2009, Enfoque para el estudio del hecho histórico deportivo, con énfasis en los deportes de combate).",
              style: styleItalic,
              textAlign: pw.TextAlign.justify,
            ),
          ),

          pw.Paragraph(
            text:
                "Así también la práctica de disciplinas de combate puede conllevar lesiones osteomusculares u otros tipos de afectación a la salud debido a las técnicas que se ejecutan (golpes, proyecciones, sumisiones y/o técnicas de transición) y rutinas de entrenamiento condicional que se realizan.",
            style: styleNormal,
            textAlign: pw.TextAlign.justify,
          ),
          pw.Divider(color: PdfColors.grey400, indent: 0, endIndent: 200),
          pw.Text(
            "1 Acevedo, W. y Cheung, M. Una visión histórica de las artes marciales mixtas en China. Revista de Artes Marciales Asiáticas, 6 (2), 29-44.",
            style: styleSmall.copyWith(fontStyle: pw.FontStyle.italic),
          ),
          pw.SizedBox(height: 20),

          // dibuja previo a cuestionario
          pw.RichText(
            textAlign: pw.TextAlign.justify,
            text: pw.TextSpan(
              style: styleNormal,
              children: [
                const pw.TextSpan(
                  text:
                      "Las siguientes preguntas deben ser leídas cuidadosamente y respondidas con honestidad; el manifestar que si presenta o ha presentado alguno de los síntomas y/o diagnósticos no le excluye de la participación en el proceso de preparación física, práctica y competencia deportiva desarrollado por ",
                ),
                pw.TextSpan(text: "PREDATOR FIGHT CLUB", style: styleBold),
                const pw.TextSpan(
                  text:
                      ". No obstante, el siguiente cuestionario se asume como una declaración por parte del futuro usuario o acudiente del mismo que se encuentra en condición de iniciar un proceso de preparación física y/o entrenamiento deportivo.",
                ),
              ],
            ),
          ),
          pw.RichText(
            textAlign: pw.TextAlign.justify,
            text: pw.TextSpan(
              style: styleNormal,
              children: [
                pw.TextSpan(text: "Nota: ", style: styleBold),
                const pw.TextSpan(text: "en el apartado de "),
                pw.TextSpan(text: "Especificaciones ", style: styleBold),
                const pw.TextSpan(
                  text:
                      "por favor describa detalladamente según corresponda a la pregunta: por ejemplo, si se le pregunta si le han diagnosticado un problema cardíaco, y su respuesta es afirmativa, debe suministrar la información referente y pertinente de este (cuál es, qué contraindicaciones tiene para la actividad física, que recomendaciones tiene por parte de su médico, etc).",
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // agrupa cuestionario para evitar cortes
          pw.Wrap(
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Center(
                      child: pw.Text(
                        "CUESTIONARIO DE PRE-PARTICIPACIÓN A LA ACTIVIDAD FÍSICA (PAR-Q) SI/NO",
                        style: styleBold,
                      ),
                    ),
                    pw.SizedBox(height: 15),
                    ...waiver.answers.map((answer) {
                      final ansText = answer.answer ? "SÍ" : "NO";
                      final specText = answer.specification ?? "";
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 10),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(answer.question, style: styleNormal),
                            pw.SizedBox(height: 4),
                            // SÍ en negro
                            pw.Text(
                              "Respuesta: $ansText",
                              style: styleBold.copyWith(color: PdfColors.black),
                            ),
                            if (answer.answer)
                              pw.Text(
                                "Especificaciones: $specText",
                                style: styleItalic,
                              ),
                            pw.SizedBox(height: 5),
                            pw.Divider(color: PdfColors.grey300),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 30),

          // dibuja carta de aceptacion dinamica
          pw.Center(
            child: pw.Text(
              "Carta de Aceptación CONCENTIMIENTO INFORMADO",
              style: styleBold,
            ),
          ),
          pw.SizedBox(height: 15),

          pw.RichText(
            textAlign: pw.TextAlign.justify,
            text: pw.TextSpan(
              style: styleNormal,
              children: waiver.isGuardian
                  ? [
                      const pw.TextSpan(text: "Yo "),
                      pw.TextSpan(
                        text: waiver.signerName.toUpperCase(),
                        style: styleBold,
                      ),
                      const pw.TextSpan(
                        text: " con Cédula de identificación Número ",
                      ),
                      pw.TextSpan(text: waiver.signerId, style: styleBold),
                      const pw.TextSpan(text: " de "),
                      pw.TextSpan(
                        text: waiver.signerCity.toUpperCase(),
                        style: styleBold,
                      ),
                      const pw.TextSpan(text: " en calidad de "),
                      pw.TextSpan(text: "ACUDIENTE", style: styleBold),
                      const pw.TextSpan(text: " del menor "),
                      pw.TextSpan(
                        text: waiver.minorName?.toUpperCase() ?? "",
                        style: styleBold,
                      ),
                      const pw.TextSpan(
                        text: " identificado con tarjeta de identidad número ",
                      ),
                      pw.TextSpan(text: waiver.minorId ?? "", style: styleBold),
                      const pw.TextSpan(text: " de "),
                      pw.TextSpan(
                        text: waiver.minorCity?.toUpperCase() ?? "",
                        style: styleBold,
                      ),
                      const pw.TextSpan(text: "."),
                    ]
                  : [
                      const pw.TextSpan(text: "Yo "),
                      pw.TextSpan(
                        text: waiver.signerName.toUpperCase(),
                        style: styleBold,
                      ),
                      const pw.TextSpan(
                        text: " con Cédula de identificación Número ",
                      ),
                      pw.TextSpan(text: waiver.signerId, style: styleBold),
                      const pw.TextSpan(text: " de "),
                      pw.TextSpan(
                        text: waiver.signerCity.toUpperCase(),
                        style: styleBold,
                      ),
                      const pw.TextSpan(text: " en calidad de "),
                      pw.TextSpan(text: "USUARIO", style: styleBold),
                      const pw.TextSpan(text: "."),
                    ],
            ),
          ),
          pw.SizedBox(height: 10),

          pw.RichText(
            textAlign: pw.TextAlign.justify,
            text: pw.TextSpan(
              style: styleNormal,
              children: [
                const pw.TextSpan(
                  text:
                      "Declaro (a) que en forma voluntaria se ha decidido participar en el proceso de preparación física y/o práctica deportiva desarrollados por ",
                ),
                pw.TextSpan(text: "PREDATOR FIGHT CLUB", style: styleBold),
                const pw.TextSpan(
                  text:
                      " además me (nos) comprometo (emos) a atender las recomendaciones del equipo asesor y las siguientes observaciones:",
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),

          // dibuja lista declaracion
          _buildPdfBullet([
            const pw.TextSpan(
              text:
                  "Que la información que suministro en este documento es veraz y que toda omisión de parte del usuario puede constituir un atentado contra su integridad personal, exonerando desde ya de toda responsabilidad a ",
            ),
            pw.TextSpan(text: "PREDATOR FIGHT CLUB.", style: styleBold),
          ], styleNormal),

          _buildPdfBullet([
            const pw.TextSpan(
              text:
                  "Que se ha recibido la suficiente información sobre los beneficios y la naturaleza de los procedimientos, así como de los riesgos ocasionados por incumplimiento de las recomendaciones del equipo de entrenadores y profesionales asociados a ",
            ),
            pw.TextSpan(text: "PREDATOR FIGHT CLUB.", style: styleBold),
          ], styleNormal),

          _buildPdfBullet([
            const pw.TextSpan(
              text:
                  "Asumo todos los riesgos asociados con la participación en los procesos de preparación física, práctica deportiva y eventos desarrollados por ",
            ),
            pw.TextSpan(text: "PREDATOR FIGHT CLUB", style: styleBold),
            const pw.TextSpan(
              text:
                  "; no limitados a lesiones, enfermedades y/o accidentes, también por el contacto con otros participantes, las consecuencias del clima (incluyendo temperatura y/o humedad) y en general todo riesgo que declaro ser conocidos y valorados por mí (nosotros). En el caso de menores de edad (18 años) la responsabilidad por los riesgos mencionados anteriormente es asumidos por el acudiente del menor con el diligenciamiento de este documento.",
            ),
          ], styleNormal),

          _buildPdfBullet([
            const pw.TextSpan(text: "Autorizo a "),
            pw.TextSpan(text: "PREDATOR FIGHT CLUB", style: styleBold),
            const pw.TextSpan(
              text:
                  " el uso de fotografías, películas, videos, grabaciones, y cualquier otro medio de registro realizado en sus instalaciones o eventos para cualquier uso legítimo sin compensación económica alguna.",
            ),
          ], styleNormal),

          pw.SizedBox(height: 40),

          // agrupa firmas
          pw.Wrap(
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "Nombre: ${waiver.isGuardian ? waiver.minorName?.toUpperCase() : waiver.signerName.toUpperCase()}",
                    style: styleBold,
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    "CC: ${waiver.isGuardian ? waiver.minorId : waiver.signerId}",
                    style: styleBold,
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text("Fecha: $fechaActual", style: styleBold),
                  pw.SizedBox(height: 15),
                  pw.Text("Firma:", style: styleBold),
                  pw.SizedBox(height: 5),
                  pw.Container(
                    height: 120, // altura expandida
                    width: 250,
                    padding: const pw.EdgeInsets.all(5),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey),
                    ),
                    // ajusta aspecto interno de imagen
                    child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // dibuja viñetas exactas evadiendo caracteres rotos
  pw.Widget _buildPdfBullet(List<pw.TextSpan> spans, pw.TextStyle baseStyle) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 4, right: 6),
            width: 3,
            height: 3,
            decoration: const pw.BoxDecoration(
              color: PdfColors.black,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.Expanded(
            child: pw.RichText(
              textAlign: pw.TextAlign.justify,
              text: pw.TextSpan(style: baseStyle, children: spans),
            ),
          ),
        ],
      ),
    );
  }

  // sube archivo storage
  Future<String> _uploadToStorage(String userId, Uint8List pdfBytes) async {
    final storageRef = FirebaseStorage.instance.ref().child(
      'waivers/$userId.pdf',
    );
    await storageRef.putData(
      pdfBytes,
      SettableMetadata(contentType: 'application/pdf'),
    );
    return await storageRef.getDownloadURL();
  }

  // actualiza base datos a traves de mapper
  Future<void> _updateFirestore(WaiverModel waiver, String pdfUrl) async {
    final mapData = WaiverMapper.toMap(waiver, pdfUrl);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(waiver.userId)
        .set(mapData, SetOptions(merge: true));
  }
}
