import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
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
  
  List<ScheduleRule> _rules = [];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.plan?.name ?? '');
    
    String initialPrice = '';
    if (widget.plan != null) {
      final formatter = NumberFormat("#,###", "es_CO");
      initialPrice = formatter.format(widget.plan!.price).replaceAll(',', '.');
    }
    _priceCtrl = TextEditingController(text: initialPrice);

    _consumptionType = widget.plan?.consumptionType ?? PlanConsumptionType.limitedDaily;
    _rules = widget.plan?.scheduleRules != null 
        ? List.from(widget.plan!.scheduleRules) 
        : [];
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.red[900]!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.plan == null ? 'Crear Plan' : 'Editar Plan'),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5, offset: const Offset(0, -2))],
          ),
          child: SizedBox(
            height: 50,
            child: BlocBuilder<PlanCubit, PlanState>(
              builder: (context, state) {
                final isLoading = state is PlanLoading;

                return ElevatedButton(
                  onPressed: isLoading ? null : _savePlan,
                  
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    disabledBackgroundColor: primaryColor.withOpacity(0.6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('GUARDAR PLAN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                );
              },
            ),
          ),
        ),
        body: BlocListener<PlanCubit, PlanState>(
          listener: (context, state) {
            if (state is PlanLoaded) {
              if (ModalRoute.of(context)?.isCurrent == true) {
                Navigator.pop(context);
              }
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
                  const Text("Información Básica", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 15),

                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Plan',
                      hintText: 'Ej: Wild, Full, Morning',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                    validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
                  ),
                  const SizedBox(height: 15),

                  TextFormField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _CurrencyInputFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Precio',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
                  ),
                  const SizedBox(height: 15),

                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Ingreso',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<PlanConsumptionType>(
                        value: _consumptionType,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: PlanConsumptionType.limitedDaily,
                            child: Text('Diario (Un ingreso al día)'),
                          ),
                          DropdownMenuItem(
                            value: PlanConsumptionType.unlimited,
                            child: Text('Ilimitado (Sin límites diarios)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _consumptionType = val);
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  const Divider(),
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Reglas del Plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton.filled(
                        icon: const Icon(Icons.add),
                        style: IconButton.styleFrom(backgroundColor: primaryColor),
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
                              '¡Atención! Debes agregar al menos una regla para limitar a qué clases pueden entrar.',
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
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(
                            _formatDays(rule.allowedDays),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(children: [
                                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text('${_formatTime(rule.startMinute)} - ${_formatTime(rule.endMinute)}'),
                              ]),
                              const SizedBox(height: 4),
                              Text(
                                _formatCategories(rule.allowedCategories),
                                style: TextStyle(color: primaryColor, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          // Fix: Diálogo de confirmación al borrar
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _confirmDeleteRule(index),
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteRule(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Regla"),
        content: const Text("¿Estás seguro de quitar esta restricción?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () {
              setState(() => _rules.removeAt(index));
              Navigator.pop(ctx);
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _savePlan() {
    if (context.read<PlanCubit>().state is PlanLoading) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    if (_rules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes agregar al menos una regla.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final cleanPrice = _priceCtrl.text.replaceAll('.', '').replaceAll(',', '');

    final newPlan = PlanModel(
      id: widget.plan?.id ?? '',
      name: _nameCtrl.text.trim(),
      price: double.tryParse(cleanPrice) ?? 0,
      consumptionType: _consumptionType,
      scheduleRules: _rules, 
      isActive: true,
      packClassesQuantity: widget.plan?.packClassesQuantity,
    );

    if (widget.plan == null) {
      context.read<PlanCubit>().createPlan(newPlan);
    } else {
      context.read<PlanCubit>().updatePlan(newPlan);
    }
  }

  Future<void> _showAddRuleDialog() async {
    FocusScope.of(context).requestFocus(FocusNode());
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RuleEditorDialog(
        onSave: (rule) {
          setState(() => _rules.add(rule));
        },
      ),
    );

    if (mounted) {
      FocusScope.of(context).requestFocus(FocusNode());
    }
  }

  String _formatTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, h, m);
    return DateFormat('h:mm a').format(dt);
  }

  String _formatDays(List<int> days) {
    if (days.length == 7) return 'Todos los días';
    const week = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return days.map((d) => week[d - 1]).join(', ');
  }

  String _formatCategories(List<ClassCategory> cats) {
    if (cats.isEmpty) return 'Todo Tipo de Clase';
    final names = {
      ClassCategory.combat: 'Combate',
      ClassCategory.conditioning: 'Físico',
      ClassCategory.kids: 'Niños',
      ClassCategory.virtual: 'Virtual',
      ClassCategory.personalized: 'Personalizado',
    };
    return cats.map((c) => names[c] ?? c.name).join(', ');
  }
}

class _RuleEditorDialog extends StatefulWidget {
  final Function(ScheduleRule) onSave;
  const _RuleEditorDialog({required this.onSave});

  @override
  State<_RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends State<_RuleEditorDialog> {
  final Set<int> _selectedDays = {}; 
  final Set<ClassCategory> _selectedCategories = {};
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.red[900]!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.rule, color: primaryColor),
          const SizedBox(width: 10),
          const Text('Nueva Regla'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Días Habilitados:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStaticChip("L", 1, isDark),
                _buildStaticChip("M", 2, isDark),
                _buildStaticChip("M", 3, isDark),
                _buildStaticChip("J", 4, isDark),
                _buildStaticChip("V", 5, isDark),
                _buildStaticChip("S", 6, isDark),
                _buildStaticChip("D", 7, isDark),
              ],
            ),
            const SizedBox(height: 20),

            const Text('Horario Permitido:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildTimeBox("Desde", _startTime, (t) => setState(() => _startTime = t))),
                const SizedBox(width: 10),
                Expanded(child: _buildTimeBox("Hasta", _endTime, (t) => setState(() => _endTime = t))),
              ],
            ),

            const SizedBox(height: 20),

            const Text('Tipos de Clase(s):', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildCategoryChip("COMBATE", ClassCategory.combat, isDark),
                _buildCategoryChip("FÍSICO", ClassCategory.conditioning, isDark),
                _buildCategoryChip("NIÑOS", ClassCategory.kids, isDark),
                _buildCategoryChip("VIRTUAL", ClassCategory.virtual, isDark),
                _buildCategoryChip("PERSONALIZADO", ClassCategory.personalized, isDark),
              ],
            ),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 15),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('AGREGAR REGLA'),
        ),
      ],
    );
  }

  void _submit() {
    setState(() => _errorMessage = null);

    if (_selectedDays.isEmpty) {
      setState(() => _errorMessage = "Selecciona al menos un día.");
      return;
    }
    if (_startTime == null || _endTime == null) {
      setState(() => _errorMessage = "Define hora de inicio y fin.");
      return;
    }
    
    final startMin = _startTime!.hour * 60 + _startTime!.minute;
    final endMin = _endTime!.hour * 60 + _endTime!.minute;
    
    if (endMin <= startMin) {
      setState(() => _errorMessage = "La hora final debe ser mayor a la inicial.");
      return;
    }

    final rule = ScheduleRule(
      allowedDays: _selectedDays.toList()..sort(),
      startMinute: startMin,
      endMinute: endMin,
      allowedCategories: _selectedCategories.toList(),
    );
    
    widget.onSave(rule);
    Navigator.pop(context);
  }

  Widget _buildTimeBox(String label, TimeOfDay? time, Function(TimeOfDay) onSelect) {
    return InkWell(
      onTap: () async {
        final t = await showTimePicker(context: context, initialTime: time ?? const TimeOfDay(hour: 8, minute: 0));
        if (t != null) onSelect(t);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        child: Text(
          time == null ? "--:--" : time.format(context),
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildStaticChip(String label, int dayIndex, bool isDark) {
    final isSelected = _selectedDays.contains(dayIndex);
    final color = Colors.red[900]!;
    
    final textColor = isSelected 
        ? color 
        : (isDark ? Colors.white70 : Colors.black87);

    return GestureDetector(
      onTap: () {
        setState(() {
          isSelected ? _selectedDays.remove(dayIndex) : _selectedDays.add(dayIndex);
        });
      },
      child: Container(
        width: 35,
        height: 35,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          border: Border.all(color: isSelected ? color : (isDark ? Colors.white24 : Colors.grey.shade400)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, ClassCategory cat, bool isDark) {
    final isSelected = _selectedCategories.contains(cat);
    final color = Colors.red[900]!;
    
    final borderColor = isSelected ? color : (isDark ? Colors.white24 : Colors.grey.shade400);
    final textColor = isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87);

    return GestureDetector(
      onTap: () {
        setState(() {
          isSelected ? _selectedCategories.remove(cat) : _selectedCategories.add(cat);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) return newValue;

    double value = double.parse(newValue.text);
    final formatter = NumberFormat("#,###", "es_CO");
    String newText = formatter.format(value).replaceAll(',', '.');

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}