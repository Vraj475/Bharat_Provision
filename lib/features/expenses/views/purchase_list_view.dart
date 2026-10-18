import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_format.dart';
import '../../../../routing/app_router.dart';
import '../../../../shared/models/purchase_model.dart';
import '../providers/purchase_providers.dart';

class PurchaseListView extends ConsumerStatefulWidget {
  const PurchaseListView({super.key});

  @override
  ConsumerState<PurchaseListView> createState() => _PurchaseListViewState();
}

class _PurchaseListViewState extends ConsumerState<PurchaseListView> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _selectDateRange() async {
    final currentFilter = ref.read(purchaseFilterProvider);
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: currentFilter.startDate != null && currentFilter.endDate != null
          ? DateTimeRange(
              start: currentFilter.startDate!,
              end: currentFilter.endDate!,
            )
          : null,
    );

    if (range != null) {
      ref.read(purchaseFilterProvider.notifier).state = currentFilter.copyWith(
        startDate: range.start,
        endDate: range.end,
      );
    }
  }

  void _clearDateFilter() {
    final currentFilter = ref.read(purchaseFilterProvider);
    ref.read(purchaseFilterProvider.notifier).state = currentFilter.copyWith(
      clearDates: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final purchasesAsync = ref.watch(purchasesListProvider);
    final summaryAsync = ref.watch(purchaseSummaryProvider);
    final filter = ref.watch(purchaseFilterProvider);

    return Scaffold(
      body: Column(
        children: [
          // 1. KPI Summary Cards
          summaryAsync.when(
            data: (summary) => _buildSummaryCards(summary),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // 2. Filter & Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'ખરીદી શોધો (નંબર અથવા સપ્લાયર)...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                ref.read(purchaseFilterProvider.notifier).state =
                                    filter.copyWith(query: '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (val) {
                      ref.read(purchaseFilterProvider.notifier).state =
                          filter.copyWith(query: val);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    filter.startDate != null && filter.endDate != null
                        ? '${filter.startDate!.day}/${filter.startDate!.month} - ${filter.endDate!.day}/${filter.endDate!.month}'
                        : 'તારીખ પસંદ કરો',
                  ),
                ),
                if (filter.startDate != null) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'તારીખ ફિલ્ટર હટાવો',
                    onPressed: _clearDateFilter,
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 1),

          // 3. Purchase List
          Expanded(
            child: purchasesAsync.when(
              data: (purchases) {
                if (purchases.isEmpty) {
                  return _buildEmptyState();
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(purchasesListProvider);
                    ref.invalidate(purchaseSummaryProvider);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: purchases.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, index) {
                      return _buildPurchaseCard(purchases[index]);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('ભૂલ: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRouter.addPurchase),
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('નવી ખરીદી (Add Purchase)'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> summary) {
    final count = summary['total_count'] as int? ?? 0;
    final totalAmount = summary['total_amount'] as double? ?? 0.0;
    final totalPaid = summary['total_paid'] as double? ?? 0.0;
    final totalPending = (totalAmount - totalPaid).clamp(0.0, double.infinity);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          Expanded(
            child: _buildMetricTile(
              label: 'કુલ ખરીદી',
              value: '$count ઓર્ડર',
              color: AppColors.primary,
              icon: Icons.receipt_long,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricTile(
              label: 'કુલ ખરીદી રકમ',
              value: formatCurrency(totalAmount),
              color: const Color(0xFF1E293B),
              icon: Icons.account_balance_wallet,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricTile(
              label: 'બાકી રકમ (Pending)',
              value: formatCurrency(totalPending),
              color: totalPending > 0 ? AppColors.alert : AppColors.success,
              icon: Icons.pending_actions,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseCard(Purchase purchase) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.push(
            '${AppRouter.purchaseDetail}?id=${purchase.id}',
            extra: purchase.id,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Purchase icon / badge
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#${purchase.purchaseNo}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${purchase.purchaseDate}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildPaymentBadge(purchase.paymentMode),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      purchase.supplierName?.isNotEmpty == true
                          ? 'સપ્લાયર: ${purchase.supplierName}${purchase.supplierPhone != null ? ' (${purchase.supplierPhone})' : ''}'
                          : 'સપ્લાયર: નોંધાયેલ નથી',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),

              // Amount & arrow
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency(purchase.totalAmount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (purchase.paidAmount < purchase.totalAmount)
                    Text(
                      'બાકી: ${formatCurrency(purchase.totalAmount - purchase.paidAmount)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.alert,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentBadge(String mode) {
    Color bg;
    Color fg;
    String label;

    switch (mode) {
      case 'khata':
        bg = AppColors.warning.withValues(alpha: 0.15);
        fg = Colors.orange.shade900;
        label = 'ખાતું';
        break;
      case 'bank':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        label = 'બેંક / UPI';
        break;
      case 'cash':
      default:
        bg = AppColors.success.withValues(alpha: 0.15);
        fg = Colors.green.shade900;
        label = 'રોકડ';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          const Text(
            'કોઈ ખરીદી મળી નથી',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'નવી સ્ટોક ખરીદી નોંધવા નીચેનું બટન દબાવો',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => context.push(AppRouter.addPurchase),
            icon: const Icon(Icons.add),
            label: const Text('નવી ખરીદી કરો (Add Purchase)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
