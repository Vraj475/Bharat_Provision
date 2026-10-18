import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_format.dart';
import '../../../../data/providers.dart';
import '../../../../shared/models/purchase_model.dart';
import '../providers/purchase_providers.dart';

class PurchaseDetailScreen extends ConsumerStatefulWidget {
  final int purchaseId;

  const PurchaseDetailScreen({super.key, required this.purchaseId});

  @override
  ConsumerState<PurchaseDetailScreen> createState() =>
      _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends ConsumerState<PurchaseDetailScreen> {
  bool _isDeleting = false;

  Future<void> _deletePurchase(Purchase purchase) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ખરીદી રદ કરો? (Delete Purchase)'),
        content: Text(
          'શું તમે ખરીદી #${purchase.purchaseNo} કાઢી નાખવા માંગો છો?\n'
          'આનાથી તમામ વસ્તુઓનો સ્ટોક અને પડતર ભાવ પાછો જૂનો થઈ જશે, અને ખર્ચની નોંધ પણ હટાવી દેવામાં આવશે.',
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('ના, રહેવા દો'),
          ),
          ElevatedButton(
            onPressed: () => ctx.pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alert,
              foregroundColor: Colors.white,
            ),
            child: const Text('હા, કાઢી નાખો'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      final repo = ref.read(purchaseRepositoryProvider);
      await repo.deletePurchase(widget.purchaseId);

      ref.invalidate(purchasesListProvider);
      ref.invalidate(purchaseSummaryProvider);
      ref.invalidate(expenseRepositoryProvider);
      ref.invalidate(stockRepositoryProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ખરીદી સફળતાપૂર્વક કાઢી નાખવામાં આવી.'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ભૂલ: $e'),
          backgroundColor: AppColors.alert,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(purchaseRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ખરીદી વિગત (Purchase Details)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: FutureBuilder<Purchase?>(
        future: repo.getPurchaseById(widget.purchaseId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('ભૂલ: ${snapshot.error}'));
          }
          final purchase = snapshot.data;
          if (purchase == null) {
            return const Center(child: Text('ખરીદી મળી નથી.'));
          }

          final items = purchase.items ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Card: Summary info
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.divider),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primarySurface,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '#${purchase.purchaseNo}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryDark,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'તારીખ: ${purchase.purchaseDate}',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                _buildPaymentModeBadge(purchase.paymentMode),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Divider(),
                            const SizedBox(height: 10),

                            // Supplier and notes
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'સપ્લાયર (Supplier):',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        purchase.supplierName?.isNotEmpty == true
                                            ? purchase.supplierName!
                                            : 'નોંધાયેલ નથી (Not specified)',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      if (purchase.supplierPhone?.isNotEmpty == true)
                                        Text(
                                          'ફોન: ${purchase.supplierPhone}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'કુલ રકમ (Total Amount):',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      formatCurrency(purchase.totalAmount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 22,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                    if (purchase.paidAmount < purchase.totalAmount)
                                      Text(
                                        'બાકી: ${formatCurrency(purchase.totalAmount - purchase.paidAmount)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.alert,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            if (purchase.notes?.isNotEmpty == true) ...[
                              const SizedBox(height: 10),
                              Text(
                                'નોંધ: ${purchase.notes}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Items Table
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ખરીદેલ વસ્તુઓ (${items.length})',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.divider),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, idx) {
                          final item = items[idx];
                          final name = item.productNameGujarati ?? 'વસ્તુ';
                          final unit = item.unit ?? '';
                          final costDiff = item.newCostPrice - item.oldCostPrice;
                          final costIncPct = item.oldCostPrice > 0
                              ? (costDiff / item.oldCostPrice) * 100
                              : 0.0;

                          return Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${idx + 1}. $name',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      formatCurrency(item.totalCost),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text(
                                      'જથ્થો: ${item.qty} $unit × ${formatCurrency(item.unitCost)}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'સ્ટોક: ${item.oldStockQty} ➔ ${item.oldStockQty + item.qty}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        'પડતર: ${formatCurrency(item.oldCostPrice)} ➔ સરેરાશ: ${formatCurrency(item.newCostPrice)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (costIncPct >= 10) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '(+${costIncPct.toStringAsFixed(1)}%)',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.alert,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      Text(
                                        'વેચાણ: ${formatCurrency(item.oldSellPrice)} ➔ ${formatCurrency(item.newSellPrice)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: item.newSellPrice != item.oldSellPrice
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Delete purchase button
                    Center(
                      child: TextButton.icon(
                        onPressed: _isDeleting ? null : () => _deletePurchase(purchase),
                        icon: const Icon(Icons.delete_forever, color: AppColors.alert),
                        label: Text(
                          _isDeleting
                              ? 'રદ થઈ રહી છે...'
                              : 'આ ખરીદી રદ કરો (Cancel / Delete Purchase)',
                          style: const TextStyle(
                            color: AppColors.alert,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentModeBadge(String mode) {
    Color bg;
    Color fg;
    String label;

    switch (mode) {
      case 'khata':
        bg = AppColors.warning.withValues(alpha: 0.15);
        fg = Colors.orange.shade900;
        label = 'ખાતું (Khata)';
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
        label = 'રોકડ (Cash)';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
