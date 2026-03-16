import 'package:flutter/material.dart';

class CustomSnackBar {
  // exito (verde)
  static void showSuccess(BuildContext context, String message) {
    _show(context, message, Colors.green.shade700, Icons.check_circle_outline);
  }

  // error (rojo)
  static void showError(BuildContext context, String message) {
    _show(context, message, Colors.red.shade800, Icons.error_outline);
  }

  // informacion/advertencia (naranja)
  static void showWarning(BuildContext context, String message) {
    _show(
      context,
      message,
      Colors.orange.shade800,
      Icons.warning_amber_rounded,
    );
  }

  // constructor base privado
  static void _show(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
  ) {
    // oculta alerta anterior si hay una en pantalla para que no se acumulen
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final screenHeight = MediaQuery.of(context).size.height;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(
          bottom:
              screenHeight -
              122,
          left: 20,
          right: 20,
        ),
        elevation: 6,
        duration: const Duration(seconds: 4),
        dismissDirection: DismissDirection
            .up, 
      ),
    );
  }
}
