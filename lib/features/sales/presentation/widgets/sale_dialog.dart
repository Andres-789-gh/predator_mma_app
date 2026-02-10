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

    final qty = int.parse(_qtyController.text);
    final total = widget.product.salePrice * qty;

    final buyerId = _selectedUser?.userId;
    final buyerName = _selectedUser?.fullName ?? 'Venta Externa';

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
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _qtyController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Cantidad',
                            border: OutlineInputBorder(),
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
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total:',
                                style: TextStyle(fontSize: 10),
                              ),
                              Text(
                                currencyFormat.format(_totalAmount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  BlocBuilder<SalesCubit, SalesState>(
                    builder: (context, state) {
                      if (state.status == SalesStatus.loadingUsers) {
                        return const LinearProgressIndicator();
                      }

                      return DropdownButtonFormField<UserModel>(
                        decoration: const InputDecoration(
                          labelText: 'Cliente Venta',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        isExpanded: true,
                        value: _selectedUser,
                        items: [
                          const DropdownMenuItem<UserModel>(
                            value: null,
                            child: Text(
                              'Venta Externa',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                          ),
                          ...state.users.map(
                            (user) => DropdownMenuItem(
                              value: user,
                              child: Text(
                                user.fullName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) => setState(() => _selectedUser = val),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Método de Pago',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.payment),
                    ),
                    items: _paymentMethods
                        .map(
                          (method) => DropdownMenuItem(
                            value: method,
                            child: Text(method),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _paymentMethod = val!),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _dateController,
                    readOnly: true,
                    onTap: _pickDate,
                    decoration: const InputDecoration(
                      labelText: 'Fecha de Venta',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'Nota / Observación',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note_alt_outlined),
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
                    : const Text('CONFIRMAR VENTA'),
              );
            },
          ),
        ],
      ),
    );
  }
}
