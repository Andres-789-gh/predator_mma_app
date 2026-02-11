import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../injection_container.dart';
import '../../../inventory/domain/entities/product_entity.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../domain/entities/sale_entity.dart';
import '../cubit/sales_cubit.dart';
import '../cubit/sales_state.dart';

class SaleDialog extends StatelessWidget {
  final ProductEntity product;

  const SaleDialog({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<SalesCubit>()..loadUsers(),
      child: _SaleDialogView(product: product),
    );
  }
}

class _SaleDialogView extends StatefulWidget {
  final ProductEntity product;

  const _SaleDialogView({required this.product});

  @override
  State<_SaleDialogView> createState() => _SaleDialogViewState();
}

class _SaleDialogViewState extends State<_SaleDialogView> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController(text: '1');
  final _dateController = TextEditingController();
  final _noteController = TextEditingController();

  UserModel? _selectedUser;
  bool _isExternalSale = false;
  String _paymentMethod = 'Efectivo';
  DateTime _selectedDate = DateTime.now();

  final List<String> _paymentMethods = [
    'Efectivo',
    'Nequi',
    'DaviPlata',
    'Tarjeta',
    'Transferencia',
  ];

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _dateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double get _totalAmount {
    final qty = int.tryParse(_qtyController.text) ?? 0;
    return widget.product.salePrice * qty;
  }

  void _processSale(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    if (!_isExternalSale && _selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione un cliente o seleccione "Venta Externa".'),
        ),
      );
      return;
    }

    final qty = int.parse(_qtyController.text);
    final total = widget.product.salePrice * qty;

    final buyerId = _isExternalSale ? null : _selectedUser?.userId;
    final buyerName = _isExternalSale
        ? 'Cliente Externo'
        : _selectedUser!.fullName;

    final sale = SaleEntity(
      id: '',
      productId: widget.product.id,
      productName: widget.product.name,
      productUnitPrice: widget.product.salePrice,
      productUnitCost: widget.product.costPrice,
      quantity: qty,
      totalPrice: total,
      buyerId: buyerId,
      buyerName: buyerName,
      paymentMethod: _paymentMethod,
      saleDate: _selectedDate,
      note: _noteController.text.isEmpty ? null : _noteController.text.trim(),
    );

    context.read<SalesCubit>().submitSale(sale);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    const compactInputDecoration = InputDecoration(
      border: OutlineInputBorder(),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    );

    return BlocListener<SalesCubit, SalesState>(
      listener: (context, state) {
        if (state.status == SalesStatus.success) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Venta registrada con éxito')),
          );
        } else if (state.status == SalesStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage ?? 'Error al vender')),
          );
        }
      },
      child: AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Registrar Venta'),
            Text(
              widget.product.name,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cantidad y Total
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _qtyController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: compactInputDecoration.copyWith(
                            labelText: 'Cant.',
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Req';
                            if (int.tryParse(v) == 0) return '> 0';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Total:',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green.shade900,
                                ),
                              ),
                              Text(
                                currencyFormat.format(_totalAmount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade900,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Venta Externa
                  SwitchListTile(
                    title: const Text(
                      '¿Es venta externa?',
                      style: TextStyle(fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Cliente no registrado',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _isExternalSale,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setState(() {
                        _isExternalSale = val;
                        if (val) _selectedUser = null;
                      });
                    },
                  ),

                  // Selector Cliente
                  BlocBuilder<SalesCubit, SalesState>(
                    builder: (context, state) {
                      if (state.status == SalesStatus.loadingUsers) {
                        return const LinearProgressIndicator(minHeight: 2);
                      }

                      return IgnorePointer(
                        ignoring: _isExternalSale,
                        child: DropdownButtonFormField<UserModel>(
                          decoration: compactInputDecoration.copyWith(
                            labelText: 'Seleccionar Cliente',
                            prefixIcon: const Icon(Icons.person_outline),
                            filled: _isExternalSale,
                            fillColor: _isExternalSale
                                ? Colors.grey.withValues(alpha: 0.2)
                                : null,
                            enabled: !_isExternalSale,
                          ),
                          isExpanded: true,
                          initialValue: _selectedUser,
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: _isExternalSale ? Colors.transparent : null,
                          ),
                          items: state.users
                              .map(
                                (user) => DropdownMenuItem(
                                  value: user,
                                  child: Text(
                                    user.fullName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _isExternalSale
                              ? null
                              : (val) => setState(() => _selectedUser = val),
                          validator: (value) {
                            if (!_isExternalSale && value == null) {
                              return 'Requerido si no es externo';
                            }
                            return null;
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    initialValue: _paymentMethod,
                    decoration: compactInputDecoration.copyWith(
                      labelText: 'Método de Pago',
                      prefixIcon: const Icon(Icons.payment, size: 20),
                    ),
                    items: _paymentMethods
                        .map(
                          (method) => DropdownMenuItem(
                            value: method,
                            child: Text(
                              method,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _paymentMethod = val!),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _dateController,
                    readOnly: true,
                    onTap: _pickDate,
                    decoration: compactInputDecoration.copyWith(
                      labelText: 'Fecha',
                      prefixIcon: const Icon(Icons.calendar_today, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _noteController,
                    decoration: compactInputDecoration.copyWith(
                      labelText: 'Nota (Opcional)',
                      prefixIcon: const Icon(Icons.note_alt_outlined, size: 20),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          BlocBuilder<SalesCubit, SalesState>(
            builder: (context, state) {
              return FilledButton(
                onPressed: state.status == SalesStatus.processing
                    ? null
                    : () => _processSale(context),
                child: state.status == SalesStatus.processing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('CONFIRMAR'),
              );
            },
          ),
        ],
      ),
    );
  }
}
