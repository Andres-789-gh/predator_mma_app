import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/enums.dart';
import '../../domain/models/plan_model.dart';
import '../cubit/plan_cubit.dart';
import '../cubit/plan_state.dart';

class PlanFormScreen extends StatefulWidget {
  final PlanModel? plan; 

  const PlanFormScreen({super.key, this.plan});

  @override
  State<PlanFormScreen> createState() => _PlanFormScreenState();
}

class _PlanFormScreenState extends State<PlanFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  PlanConsumptionType _consumptionType = PlanConsumptionType.limitedDaily;
  
  // Lista de Reglas
  List<ScheduleRule> _rules = [];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.plan?.name ?? '');
    _priceCtrl = TextEditingController(text: widget.plan?.price.toStringAsFixed(0) ?? '');
    _consumptionType = widget.plan?.consumptionType ?? PlanConsumptionType.limitedDaily;
    _rules = widget.plan?.scheduleRules != null 
        ? List.from(widget.plan!.scheduleRules) 
        : [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plan == null ? 'Crear Plan' : 'Editar Plan'),
      ),
      body: BlocListener<PlanCubit, PlanState>(
        listener: (context, state) {
          if (state is PlanLoaded) {
            Navigator.pop(context);
          } else if (state is PlanError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nombre
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre del Plan (Ej: Wild)'),
                  validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
                ),
                const SizedBox(height: 15),

                // Precio
                TextFormField(
                  controller: _priceCtrl,
                  decoration: const InputDecoration(labelText: 'Precio'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
                ),
                const SizedBox(height: 15),

                // ipo de Consumo
                DropdownButtonFormField<PlanConsumptionType>(
                  value: _consumptionType,
                  decoration: const InputDecoration(labelText: 'Tipo de Consumo'),
                  items: const [
                    DropdownMenuItem(
                      value: PlanConsumptionType.limitedDaily,
                      child: Text('Diario (1 vez al día - Ej: Wild, Full)'),
                    ),
                    DropdownMenuItem(
                      value: PlanConsumptionType.unlimited,
                      child: Text('Ilimitado (Sin límites - Ej: Weekends)'),
                    ),
                  ],
                  onChanged: (val) => setState(() => _consumptionType = val!),
                ),
                
                const Divider(height: 40, thickness: 2),

                // Reglas
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Reglas de Horario', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.blue, size: 30),
                      onPressed: _showAddRuleDialog,
                    )
                  ],
                ),
                const SizedBox(height: 10),
                
                if (_rules.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Agrega al menos una regla para limitar las categorías.',
                            style: TextStyle(color: Colors.brown),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._rules.asMap().entries.map((entry) {
                    final index = entry.key;
                    final rule = entry.value;
                    return Card(
                      color: Colors.blue.shade50,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(_formatDays(rule.allowedDays)),
                        subtitle: Text('${_formatTime(rule.startMinute)} - ${_formatTime(rule.endMinute)}\nCategorías: ${_formatCategories(rule.allowedCategories)}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => setState(() => _rules.removeAt(index)),
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 30),

                // btn save
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _savePlan,
                    child: const Text('GUARDAR PLAN'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Log. guardado
  void _savePlan() {
    if (!_formKey.currentState!.validate()) return;

    if (_rules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes agregar al menos una regla de horario.'),
          backgroundColor: Colors.orange,
        ),
      );
      return; 
    }

    final newPlan = PlanModel(
      id: widget.plan?.id ?? '', 
      name: _nameCtrl.text.trim(),
      price: double.tryParse(_priceCtrl.text) ?? 0,
      consumptionType: _consumptionType,
      scheduleRules: _rules, 
      isActive: true,
    );

    if (widget.plan == null) {
      context.read<PlanCubit>().createPlan(newPlan);
    } else {
      context.read<PlanCubit>().updatePlan(newPlan);
    }
  }

  void _showAddRuleDialog() {
    showDialog(
      context: context,
      builder: (_) => _RuleEditorDialog(
        onSave: (rule) {
          setState(() => _rules.add(rule));
        },
      ),
    );
  }

  String _formatTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final suffix = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:${m.toString().padLeft(2, '0')} $suffix';
  }

  String _formatDays(List<int> days) {
    if (days.length == 7) return 'Todos los días';
    const week = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return days.map((d) => week[d - 1]).join(', ');
  }

  String _formatCategories(List<ClassCategory> cats) {
    if (cats.isEmpty) return 'Todas';
    return cats.map((c) => c.name.toUpperCase()).join(', ');
  }
}

class _RuleEditorDialog extends StatefulWidget {
  final Function(ScheduleRule) onSave;
  const _RuleEditorDialog({required this.onSave});

  @override
  State<_RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends State<_RuleEditorDialog> {
  // Días seleccionados
  final Set<int> _selectedDays = {1, 2, 3, 4, 5}; 
  // Horas
  TimeOfDay _start = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 22, minute: 0);
  // Categorías
  final Set<ClassCategory> _selectedCategories = {...ClassCategory.values};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva Regla'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Días:', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 5,
              children: List.generate(7, (index) {
                final day = index + 1;
                final isSelected = _selectedDays.contains(day);
                return FilterChip(
                  label: Text(['L','M','X','J','V','S','D'][index]),
                  selected: isSelected,
                  onSelected: (val) {
                    setState(() {
                      val ? _selectedDays.add(day) : _selectedDays.remove(day);
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 10),
            const Text('Horario:', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                TextButton(
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: _start);
                    if (t != null) setState(() => _start = t);
                  },
                  child: Text('De: ${_start.format(context)}'),
                ),
                const Text('-'),
                TextButton(
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: _end);
                    if (t != null) setState(() => _end = t);
                  },
                  child: Text('Hasta: ${_end.format(context)}'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text('Categorías Permitidas:', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 5,
              children: ClassCategory.values.map((cat) {
                final isSelected = _selectedCategories.contains(cat);
                return FilterChip(
                  label: Text(cat.name.toUpperCase()),
                  selected: isSelected,
                  onSelected: (val) {
                    setState(() {
                      val ? _selectedCategories.add(cat) : _selectedCategories.remove(cat);
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            if (_selectedDays.isEmpty) return;
            
            final rule = ScheduleRule(
              allowedDays: _selectedDays.toList()..sort(),
              startMinute: _start.hour * 60 + _start.minute,
              endMinute: _end.hour * 60 + _end.minute,
              allowedCategories: _selectedCategories.toList(),
            );
            widget.onSave(rule);
            Navigator.pop(context);
          },
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}