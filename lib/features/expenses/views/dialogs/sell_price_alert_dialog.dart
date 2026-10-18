import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_format.dart';
import '../../providers/purchase_providers.dart';

class SellPriceAlertItem {
  final int productId;
  final String productName;
  final double oldCost;
  final double newCost;
  final double oldSell;
  final double suggestedSell;
  final double percentageIncrease;

  SellPriceAlertItem({
    required this.productId,
    required this.productName,
    required this.oldCost,
    required this.newCost,
    required this.oldSell,
    required this.suggestedSell,
    required this.percentageIncrease,
  });

  factory SellPriceAlertItem.fromDraft(PurchaseLineDraft draft) {
    return SellPriceAlertItem(
      productId: draft.product.id!,
      productName: draft.product.nameGujarati,
      oldCost: draft.product.buyPrice,
      newCost: draft.newAvgCost,
      oldSell: draft.product.sellPrice,
      suggestedSell: draft.suggestedSellPrice,
      percentageIncrease: draft.percentageIncrease,
    );
  }
}

class SellPriceAlertDialog extends StatefulWidget {
  final List<SellPriceAlertItem> items;

  const SellPriceAlertDialog({super.key, required this.items});

  /// Shows the dialog and returns a Map of `productId -> newSellPrice?`
  /// If user chose not to update a product, its value is null or omitted.
  static Future<Map<int, double?>?> show(
    BuildContext context, {
    required List<SellPriceAlertItem> items,
  }) {
    if (items.isEmpty) return Future.value({});
    return showDialog<Map<int, double?>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SellPriceAlertDialog(items: items),
    );
  }

  @override
  State<SellPriceAlertDialog> createState() => _SellPriceAlertDialogState();
}

class _SellPriceAlertDialogState extends State<SellPriceAlertDialog> {
  late final Map<int, TextEditingController> _controllers;
  late final Map<int, bool> _applyUpdates;

  @override
  void initState() {
    super.initState();
    _controllers = {};
    _applyUpdates = {};

    for (final item in widget.items) {
      _controllers[item.productId] = TextEditingController(
        text: item.suggestedSell.toStringAsFixed(2),
      );
      _applyUpdates[item.productId] = true; // Default to checked
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onConfirm() {
    final result = <int, double?>{};
    for (final item in widget.items) {
      final shouldApply = _applyUpdates[item.productId] ?? false;
      if (shouldApply) {
        final text = _controllers[item.productId]?.text.trim() ?? '';
        final parsed = double.tryParse(text);
        result[item.productId] = parsed ?? item.suggestedSell;
      } else {
        result[item.productId] = null; // Don't change sell price
      }
    }
    Navigator.of(context).pop(result);
  }

  void _onSkip() {
    // Keep all existing selling prices unchanged
    final result = <int, double?>{};
    for (final item in widget.items) {
      result[item.productId] = null;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.trending_up,
                      color: AppColors.warning,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ખરીદ ભાવ વધારાની ચેતવણી',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'ખરીદ ભાવ ૧૦% કે તેથી વધુ વધ્યો છે. શું વેચાણ ભાવ બદલવો છે?',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Items List
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) {
                    final item = widget.items[idx];
                    final isChecked = _applyUpdates[item.productId] ?? false;
                    final controller = _controllers[item.productId]!;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(
                          color: isChecked
                              ? AppColors.primaryLight
                              : Colors.grey.shade300,
                          width: isChecked ? 1.5 : 1.0,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.productName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.alert.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '+${item.percentageIncrease.toStringAsFixed(1)}% વધારો',
                                  style: const TextStyle(
                                    color: AppColors.alert,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                'જૂનો પડતર: ${formatCurrency(item.oldCost)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const Icon(Icons.arrow_right_alt, size: 16, color: Colors.grey),
                              Text(
                                'નવો સરેરાશ પડતર: ${formatCurrency(item.newCost)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'હાલનો વેચાણ ભાવ: ${formatCurrency(item.oldSell)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Checkbox(
                                value: isChecked,
                                activeColor: AppColors.primary,
                                onChanged: (val) {
                                  setState(() {
                                    _applyUpdates[item.productId] = val ?? false;
                                  });
                                },
                              ),
                              const Text(
                                'નવો વેચાણ ભાવ:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 110,
                                height: 40,
                                child: TextField(
                                  controller: controller,
                                  keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  enabled: isChecked,
                                  decoration: InputDecoration(
                                    prefixText: '₹ ',
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '(સૂચિત: ${formatCurrency(item.suggestedSell)})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _onSkip,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('ફેરફાર વગર ચાલુ રાખો'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('વેચાણ ભાવ અપડેટ કરો'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
