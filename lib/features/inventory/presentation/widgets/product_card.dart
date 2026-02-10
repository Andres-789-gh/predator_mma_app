import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/product_entity.dart';
import '../../../sales/presentation/widgets/sale_dialog.dart';

class ProductCard extends StatelessWidget {
  final ProductEntity product;
  final VoidCallback onTap;
  final VoidCallback? onSaleSuccess;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onSaleSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    final stockColor = product.stock == null
        ? Colors.blue.shade100
        : (product.stock! < 5 ? Colors.red.shade100 : Colors.green.shade100);

    final stockTextColor = product.stock == null
        ? Colors.blue.shade900
        : (product.stock! < 5 ? Colors.red.shade900 : Colors.green.shade900);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: stockColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      product.stock == null
                          ? 'bajo pedido'
                          : '${product.stock} unid.',
                      style: TextStyle(
                        color: stockTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildInfoColumn(
                    'venta',
                    currencyFormat.format(product.salePrice),
                  ),
                  const SizedBox(width: 16),
                  _buildInfoColumn(
                    'costo',
                    currencyFormat.format(product.costPrice),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () async {
                      final sold = await showDialog<bool>(
                        context: context,
                        builder: (_) => SaleDialog(product: product),
                      );

                      if (sold == true && onSaleSuccess != null) {
                        onSaleSuccess!();
                      }
                    },
                    icon: const Icon(Icons.attach_money, size: 18),
                    label: const Text('Vender'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}
