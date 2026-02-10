import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/product_entity.dart';
import '../cubit/product_form_cubit.dart';
import '../cubit/product_form_state.dart';

class ProductFormScreen extends StatelessWidget {
  final ProductEntity? product;

  const ProductFormScreen({super.key, this.product});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProductFormCubit>(),
      child: _ProductFormView(product: product),
    );
  }
}

class _ProductFormView extends StatefulWidget {
  final ProductEntity? product;

  const _ProductFormView({this.product});

  @override
  State<_ProductFormView> createState() => _ProductFormViewState();
}

class _ProductFormViewState extends State<_ProductFormView> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _costController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  bool _hasInfiniteStock = false;

  // formateo moneda
  final _currencyFormatter = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');

    _costController = TextEditingController(
      text: p != null ? _currencyFormatter.format(p.costPrice) : '',
    );
    _priceController = TextEditingController(
      text: p != null ? _currencyFormatter.format(p.salePrice) : '',
    );

    _stockController = TextEditingController(text: p?.stock?.toString() ?? '');

    // determina si stock es infinito bajo pedido
    _hasInfiniteStock = p?.stock == null;

    // si es nuevo por defecto stock fisico activo
    if (p == null) _hasInfiniteStock = false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _costController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  // string moneda a double
  double _parseCurrency(String value) {
    String clean = value
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll('\$', '')
        .trim();
    return double.tryParse(clean) ?? 0.0;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final cost = _parseCurrency(_costController.text);
    final price = _parseCurrency(_priceController.text);

    // define stock segun switch
    final int? stock = _hasInfiniteStock
        ? null
        : int.tryParse(_stockController.text.trim());

    final productToSave = ProductEntity(
      id: widget.product?.id ?? '',
      name: name,
      costPrice: cost,
      salePrice: price,
      stock: stock,
      createdAt: widget.product?.createdAt ?? DateTime.now(),
    );

    context.read<ProductFormCubit>().saveProduct(productToSave);
  }

  void _delete() {
    if (widget.product == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text(
          '¿Estás seguro de eliminar este producto del inventario?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ProductFormCubit>().deleteProduct(
                widget.product!.id,
              );
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  ProductEntity _collectFormData() {
    final name = _nameController.text.trim();
    final cost = _parseCurrency(_costController.text);
    final price = _parseCurrency(_priceController.text);
    final int? stock = _hasInfiniteStock
        ? null
        : int.tryParse(_stockController.text.trim());

    return ProductEntity(
      id: '',
      name: name,
      costPrice: cost,
      salePrice: price,
      stock: stock,
      createdAt: DateTime.now(),
      isActive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return BlocListener<ProductFormCubit, ProductFormState>(
      listener: (context, state) {
        if (state.status == ProductFormStatus.success) {
          Navigator.pop(context, true);
        } else if (state.status == ProductFormStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage ?? 'Error desconocido')),
          );
        } else if (state.status == ProductFormStatus.askRevive) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Producto Eliminado'),
              content: const Text(
                'Este nombre ya existe en un producto eliminado anteriormente. ¿Deseas restaurarlo con los nuevos datos?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    final productData = _collectFormData();
                    if (state.existingProductId != null) {
                      context.read<ProductFormCubit>().reviveProduct(
                        state.existingProductId!,
                        productData,
                      );
                    }
                  },
                  child: const Text('Restaurar'),
                ),
              ],
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Editar Producto' : 'Nuevo Producto'),
          actions: [
            if (isEditing)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // nombre
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Producto',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),

                // fila precios
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _costController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          CurrencyInputFormatter(),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Costo Compra',
                          border: OutlineInputBorder(),
                          prefixText: '\$ ',
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Requerido';
                          if (_parseCurrency(v) < 0) {
                            return 'No puede ser negativo';
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          CurrencyInputFormatter(),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Precio Venta',
                          border: OutlineInputBorder(),
                          prefixText: '\$ ',
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Requerido';
                          final cost = _parseCurrency(_costController.text);
                          final sale = _parseCurrency(v);
                          if (sale < cost) return 'Menor a costo';
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),

                // visualizador ganancia
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: _buildProfitIndicator(),
                ),

                const Divider(),

                // seccion stock
                SwitchListTile(
                  title: const Text('Producto Bajo Pedido'),
                  subtitle: const Text(
                    'Activar si no maneja inventario físico',
                  ),
                  value: _hasInfiniteStock,
                  onChanged: (val) {
                    setState(() {
                      _hasInfiniteStock = val;
                      if (val) {
                        _stockController.clear();
                      }
                    });
                  },
                ),

                if (!_hasInfiniteStock)
                  TextFormField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Cantidad en Stock',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                      helperText: 'Cantidad física disponible actualmente',
                    ),
                    validator: (v) {
                      if (_hasInfiniteStock) return null;
                      if (v == null || v.isEmpty)
                        return 'Requerido si maneja stock';
                      return null;
                    },
                  ),

                const SizedBox(height: 24),

                // boton guardar
                BlocBuilder<ProductFormCubit, ProductFormState>(
                  builder: (context, state) {
                    return FilledButton.icon(
                      onPressed: state.status == ProductFormStatus.loading
                          ? null
                          : _save,
                      icon: state.status == ProductFormStatus.loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: const Text('GUARDAR PRODUCTO'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // calculo ganancia
  Widget _buildProfitIndicator() {
    final cost = _parseCurrency(_costController.text);
    final price = _parseCurrency(_priceController.text);

    if (price <= 0) return const SizedBox.shrink();

    final profit = price - cost;

    final marginPercent = (cost == 0) ? 100.0 : ((profit / price) * 100);

    final isPositive = profit >= 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPositive ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ganancia Neta:',
                style: TextStyle(
                  color: isPositive
                      ? Colors.green.shade900
                      : Colors.red.shade900,
                ),
              ),
              Text(
                _currencyFormatter.format(profit),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isPositive
                      ? Colors.green.shade800
                      : Colors.red.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Margen:',
                style: TextStyle(
                  fontSize: 12,
                  color: isPositive
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
              ),
              Text(
                '${marginPercent.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isPositive
                      ? Colors.green.shade800
                      : Colors.red.shade800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
