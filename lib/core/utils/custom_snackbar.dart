import 'package:flutter/material.dart';
import 'package:bot_toast/bot_toast.dart';

class CustomSnackBar {
  // alerta exito
  static void showSuccess(BuildContext context, String message) {
    _show(message, Colors.green.shade700, Icons.check_circle_outline);
  }

  // alerta error
  static void showError(BuildContext context, String message) {
    _show(message, Colors.red.shade800, Icons.error_outline);
  }

  // alerta advertencia
  static void showWarning(BuildContext context, String message) {
    _show(message, Colors.orange.shade800, Icons.warning_amber_rounded);
  }

  static void _show(String message, Color color, IconData icon) {
    BotToast.showCustomNotification(
      toastBuilder: (cancelFunc) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
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
                GestureDetector(
                  onTap: cancelFunc,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.close, color: Colors.white70, size: 20),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      duration: const Duration(seconds: 4),
      onlyOne: true,
      crossPage: true,
    );
  }
}
