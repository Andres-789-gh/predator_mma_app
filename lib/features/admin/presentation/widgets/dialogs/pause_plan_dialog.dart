import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../auth/domain/models/user_model.dart';

class PausePlanDialog extends StatefulWidget {
  final String currentAdminName;
  final Function(PlanPause) onPauseConfirmed;

  const PausePlanDialog({
    super.key,
    required this.currentAdminName,
    required this.onPauseConfirmed,
  });

  @override
  State<PausePlanDialog> createState() => _PausePlanDialogState();
}

class _PausePlanDialogState extends State<PausePlanDialog> {
  late DateTime startDate;
  late DateTime endDate;

  @override
  void initState() {
    super.initState();
    // inicializa fechas por defecto
    startDate = DateTime.now();
    endDate = DateTime.now().add(const Duration(days: 7));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Pausar Plan"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Selecciona el rango de fechas para pausar el plan actual.",
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),

          // selector fecha inicio
          const Text("Desde:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          InkWell(
            onTap: _pickStartDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today, size: 18),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              child: Text(DateFormat('dd/MM/yyyy').format(startDate)),
            ),
          ),

          const SizedBox(height: 15),

          // selector fecha fin
          const Text("Hasta:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          InkWell(
            onTap: _pickEndDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.event_busy, size: 18),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              child: Text(DateFormat('dd/MM/yyyy').format(endDate)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.pause),
          label: const Text("Confirmar Pausa"),
          style: FilledButton.styleFrom(backgroundColor: Colors.orange[800]),
          onPressed: _confirmPause,
        ),
      ],
    );
  }

  // lógica pa seleccionar fecha inicio
  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: "SELECCIONAR FECHA INICIO",
    );
    if (picked != null) {
      setState(() {
        startDate = picked;
        if (endDate.isBefore(startDate)) {
          endDate = startDate.add(const Duration(days: 1));
        }
      });
    }
  }

  // lógica pa seleccionar fecha fin
  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: endDate,
      firstDate: startDate,
      lastDate: startDate.add(const Duration(days: 365)),
      helpText: "SELECCIONAR FECHA FIN",
    );
    if (picked != null) {
      setState(() => endDate = picked);
    }
  }

  // confirmar y cerrar
  void _confirmPause() {
    final newPause = PlanPause(
      startDate: startDate,
      endDate: endDate,
      createdBy: widget.currentAdminName,
    );

    widget.onPauseConfirmed(newPause);
    Navigator.pop(context);
  }
}
