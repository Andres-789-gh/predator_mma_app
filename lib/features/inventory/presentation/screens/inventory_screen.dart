import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../injection_container.dart';
import '../../domain/enums/inventory_sort_type.dart';
import '../cubit/inventory_cubit.dart';
import '../cubit/inventory_state.dart';
import '../widgets/product_card.dart';
import 'product_form_screen.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<InventoryCubit>()..loadInitialData(),
      child: const _InventoryView(),
    );
  }
}

class _InventoryView extends StatefulWidget {
  const _InventoryView();

  @override
  State<_InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<_InventoryView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isBottom) {
      context.read<InventoryCubit>().loadNextPage();
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    // detecta si llega al 90% del scroll
    return currentScroll >= (maxScroll * 0.9);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inventario'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: () {
                  _showSortMenu(context);
                },
                icon: const Icon(Icons.sort, color: Colors.white),
                label: const Text(
                  'Filtros',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProductFormScreen()),
            );

            if (result == true && context.mounted) {
              context.read<InventoryCubit>().loadInitialData();
            }
          },
          child: const Icon(Icons.add),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar producto...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      FocusManager.instance.primaryFocus?.unfocus();
                      context.read<InventoryCubit>().onSearchChanged('');
                    },
                  ),
                ),
                onChanged: (value) {
                  context.read<InventoryCubit>().onSearchChanged(value);
                },
              ),
            ),
            Expanded(
              child: BlocBuilder<InventoryCubit, InventoryState>(
                builder: (context, state) {
                  if (state.status == InventoryStatus.loading &&
                      state.products.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state.products.isEmpty) {
                    return const Center(
                      child: Text('No hay productos registrados'),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: state.hasReachedMax
                        ? state.products.length
                        : state.products.length + 1,
                    itemBuilder: (context, index) {
                      if (index >= state.products.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final product = state.products[index];
                      return ProductCard(
                        product: product,
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProductFormScreen(product: product),
                            ),
                          );

                          if (result == true && context.mounted) {
                            context.read<InventoryCubit>().loadInitialData();
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortMenu(BuildContext context) async {
    final sort = await showMenu<InventorySortType>(
      context: context,
      position: const RelativeRect.fromLTRB(100, 80, 0, 0),
      items: [
        _buildSortOption(InventorySortType.byNameAsc, 'Nombre (A-Z)'),
        _buildSortOption(InventorySortType.byNameDesc, 'Nombre (Z-A)'),
        _buildSortOption(InventorySortType.byStockHigh, 'Mayor Stock'),
        _buildSortOption(InventorySortType.byStockLow, 'Menor Stock'),
        _buildSortOption(InventorySortType.byDateNewest, 'Más Recientes'),
      ],
    );

    if (sort != null && context.mounted) {
      context.read<InventoryCubit>().changeSort(sort);
    }
  }

  PopupMenuItem<InventorySortType> _buildSortOption(
    InventorySortType type,
    String text,
  ) {
    return PopupMenuItem(value: type, child: Text(text));
  }
}
