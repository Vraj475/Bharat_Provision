import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/models/product_model.dart';
import '../../data/repositories/stock_repository.dart';
import 'stock_providers.dart';
import 'add_stock_screen.dart';
import 'stock_history_screen.dart';

class StockDashboardScreen extends ConsumerStatefulWidget {
  const StockDashboardScreen({super.key});

  @override
  ConsumerState<StockDashboardScreen> createState() =>
      _StockDashboardScreenState();
}

class _StockDashboardScreenState extends ConsumerState<StockDashboardScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(stockDashboardProductsProvider);
    final summaryAsync = ref.watch(stockSummaryProvider);
    final statusFilter = ref.watch(stockStatusFilterProvider);
    final categoryFilter = ref.watch(stockCategoryFilterProvider);
    final categoriesAsync = ref.watch(stockCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('સ્ટોક'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'રિફ્રેશ',
            onPressed: () {
              ref.invalidate(stockDashboardProductsProvider);
              ref.invalidate(stockSummaryProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Summary row ────────────────────────────────────────────────
          summaryAsync.when(
            data: (s) => _SummaryRow(summary: s),
            loading: () => const SizedBox(
              height: 56,
              child: Center(child: LinearProgressIndicator()),
            ),
            error: (_, _) => const SizedBox.shrink(),
          ),

          // ── Search bar ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'નામ / English / phonetic શોધો...',
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(stockSearchProvider.notifier).state = '';
                        },
                      )
                    : null,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) =>
                  ref.read(stockSearchProvider.notifier).state = v,
            ),
          ),

          // ── Status filter chips ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: StockStatusFilter.values.map((f) {
                  final labels = {
                    StockStatusFilter.all: 'બધા',
                    StockStatusFilter.low: 'ઓછો',
                    StockStatusFilter.critical: 'ક્રિટિકલ',
                    StockStatusFilter.outOfStock: 'ખૂટ્યો',
                  };
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(labels[f]!),
                      selected: statusFilter == f,
                      onSelected: (_) =>
                          ref.read(stockStatusFilterProvider.notifier).state =
                              f,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Category filter chips ──────────────────────────────────────
          categoriesAsync.when(
            data: (cats) {
              if (cats.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text('બધી કેટેગરી'),
                          selected: categoryFilter == null,
                          onSelected: (_) =>
                              ref
                                      .read(
                                        stockCategoryFilterProvider.notifier,
                                      )
                                      .state =
                                  null,
                        ),
                      ),
                      ...cats.map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(c.name),
                            selected: categoryFilter == c.id,
                            onSelected: (_) =>
                                ref
                                    .read(stockCategoryFilterProvider.notifier)
                                    .state = c
                                    .id,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 4),

          // ── Product list ───────────────────────────────────────────────
          Expanded(
            child: productsAsync.when(
              data: (products) {
                final filtered = _applyFilters(
                  products,
                  statusFilter,
                  categoryFilter,
                );
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'કોઈ ઉત્પાદ મળ્યો નહીં',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _ProductStockTile(
                    product: filtered[i],
                    onAddStock: () => _openAddStock(filtered[i]),
                    onViewHistory: () => _openHistory(filtered[i]),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('ભૂલ: $e')),
            ),
          ),
        ],
      ),
    );
  }

  List<Product> _applyFilters(
    List<Product> products,
    StockStatusFilter status,
    int? categoryId,
  ) {
    var list = products;
    if (categoryId != null) {
      list = list.where((p) => p.categoryId == categoryId).toList();
    }
    switch (status) {
      case StockStatusFilter.all:
        break;
      case StockStatusFilter.low:
        list = list.where((p) => p.stockHealth == StockHealth.low).toList();
      case StockStatusFilter.critical:
        list = list
            .where((p) => p.stockHealth == StockHealth.critical)
            .toList();
      case StockStatusFilter.outOfStock:
        list = list
            .where((p) => p.stockHealth == StockHealth.outOfStock)
            .toList();
    }
    return list;
  }

  void _openAddStock(Product product) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddStockScreen(prefilledProduct: product),
      ),
    );
    // Refresh after returning
    ref.invalidate(stockDashboardProductsProvider);
    ref.invalidate(stockSummaryProvider);
  }

  void _openHistory(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StockHistoryScreen(
          productId: product.id!,
          productName: product.nameGujarati,
        ),
      ),
    );
  }
}

// ─── Summary row ──────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.summary});
  final StockSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _SummaryChip(
            label: 'કુલ ઉત્પાદ',
            value: '${summary.total}',
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          _SummaryChip(
            label: 'ઓછો સ્ટોક',
            value: '${summary.low}',
            color: AppColors.warning,
          ),
          const SizedBox(width: 12),
          _SummaryChip(
            label: 'ખૂટ્યો',
            value: '${summary.outOfStock}',
            color: AppColors.alert,
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}

// ─── Product tile ─────────────────────────────────────────────────────────────

class _ProductStockTile extends StatelessWidget {
  const _ProductStockTile({
    required this.product,
    required this.onAddStock,
    required this.onViewHistory,
  });
  final Product product;
  final VoidCallback onAddStock;
  final VoidCallback onViewHistory;

  @override
  Widget build(BuildContext context) {
    final health = product.stockHealth;
    final bgColor = _healthBg(health);
    final dotColor = _healthDot(health);
    final label = _healthLabel(health);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: bgColor,
      child: ListTile(
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        title: Text(
          product.nameGujarati,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'સ્ટોક: ${product.stockQty.toStringAsFixed(1)} ${_unitLabel(product.unitType)}'
              ' | ન્યૂ: ${product.minStockQty.toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 12),
            ),
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: dotColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: dotColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.history, size: 20),
              tooltip: 'ઇતિહાસ',
              onPressed: onViewHistory,
            ),
            ElevatedButton.icon(
              onPressed: product.isActive ? onAddStock : null,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('ઉમેરો'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                textStyle: const TextStyle(fontSize: 12),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _healthBg(StockHealth h) {
    switch (h) {
      case StockHealth.healthy:
        return Colors.green.shade50;
      case StockHealth.low:
        return Colors.orange.shade50;
      case StockHealth.critical:
        return Colors.red.shade50;
      case StockHealth.outOfStock:
        return Colors.red.shade100;
    }
  }

  Color _healthDot(StockHealth h) {
    switch (h) {
      case StockHealth.healthy:
        return AppColors.success;
      case StockHealth.low:
        return AppColors.warning;
      case StockHealth.critical:
        return AppColors.alert;
      case StockHealth.outOfStock:
        return const Color(0xFF7B0000);
    }
  }

  String _healthLabel(StockHealth h) {
    switch (h) {
      case StockHealth.healthy:
        return 'સ્ટોક સારો';
      case StockHealth.low:
        return 'સ્ટોક ઓછો';
      case StockHealth.critical:
        return 'ક્રિટિકલ';
      case StockHealth.outOfStock:
        return 'સ્ટોક ખૂટ્યો';
    }
  }

  String _unitLabel(String unitType) {
    switch (unitType) {
      case 'weight_kg':
        return 'કિલો';
      case 'weight_gram':
        return 'ગ્રામ';
      case 'litre':
        return 'લિ';
      default:
        return 'નંગ';
    }
  }
}
