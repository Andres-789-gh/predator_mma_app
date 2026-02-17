import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../injection_container.dart';
import '../cubit/report_cubit.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ReportCubit>(),
      child: Scaffold(
        appBar: AppBar(title: const Text("Reportes Financieros")),
        body: const _ReportsBody(),
      ),
    );
  }
}

class _ReportsBody extends StatefulWidget {
  const _ReportsBody();

  @override
  State<_ReportsBody> createState() => _ReportsBodyState();
}

class _ReportsBodyState extends State<_ReportsBody> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedRangeLabel = "Personalizado";

  void _setRange(int days, String label) {
    final now = DateTime.now();
    setState(() {
      _endDate = now;
      if (label == "Mes Actual") {
        _startDate = DateTime(now.year, now.month, 1);
      } else {
        _startDate = now.subtract(Duration(days: days));
      }
      _selectedRangeLabel = label;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReportCubit, ReportState>(
      listener: (context, state) {
        if (state is ReportSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Reporte generado y listo para compartir."),
              backgroundColor: Colors.green,
            ),
          );
        } else if (state is ReportError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is ReportLoading;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Generar Excel",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Selecciona un rango de fechas para exportar las ventas, planes y ganancias.",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),

              const Text(
                "Rangos Rápidos:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _FilterChip(
                    label: "Mes Actual",
                    isSelected: _selectedRangeLabel == "Mes Actual",
                    onTap: () => _setRange(0, "Mes Actual"),
                  ),
                  _FilterChip(
                    label: "Últimos 15 días",
                    isSelected: _selectedRangeLabel == "Últimos 15 días",
                    onTap: () => _setRange(15, "Últimos 15 días"),
                  ),
                  _FilterChip(
                    label: "Últimos 30 días",
                    isSelected: _selectedRangeLabel == "Últimos 30 días",
                    onTap: () => _setRange(30, "Últimos 30 días"),
                  ),
                  _FilterChip(
                    label: "Últimos 60 días",
                    isSelected: _selectedRangeLabel == "Últimos 60 días",
                    onTap: () => _setRange(60, "Últimos 60 días"),
                  ),
                  _FilterChip(
                    label: "Últimos 90 días",
                    isSelected: _selectedRangeLabel == "Últimos 90 días",
                    onTap: () => _setRange(90, "Últimos 90 días"),
                  ),
                ],
              ),

              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: _DateSelector(
                      label: "Desde",
                      date: _startDate,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime(2023),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _startDate = picked;
                            _selectedRangeLabel = "Personalizado";
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _DateSelector(
                      label: "Hasta",
                      date: _endDate,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? DateTime.now(),
                          firstDate: _startDate ?? DateTime(2023),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _endDate = picked;
                            _selectedRangeLabel = "Personalizado";
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 50),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: FilledButton.icon(
                  onPressed:
                      (isLoading || _startDate == null || _endDate == null)
                      ? null
                      : () {
                          context.read<ReportCubit>().generateReport(
                            _startDate!,
                            _endDate!,
                          );
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green[800],
                  ),
                  icon: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.file_download),
                  label: Text(isLoading ? "PROCESANDO..." : "DESCARGAR EXCEL"),
                ),
              ),
              if (_startDate != null && _endDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Center(
                    child: Text(
                      "Rango: ${DateFormat('dd/MM/yyyy').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? Theme.of(context).primaryColor : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

class _DateSelector extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DateSelector({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                const SizedBox(width: 10),
                Text(
                  date != null
                      ? DateFormat('dd/MM/yyyy').format(date!)
                      : '--/--/--',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
