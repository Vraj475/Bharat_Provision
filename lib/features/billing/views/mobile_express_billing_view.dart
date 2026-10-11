import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_format.dart';
import '../../../data/providers.dart';
import '../../../shared/models/product_model.dart';
import '../../../shared/widgets/customer_search_field.dart';
import '../billing_providers.dart';
import '../controllers/billing_controller.dart';
import '../models/bill_line_item.dart';
import 'dialogs/discount_dialog.dart';
import 'dialogs/product_addition_dialog.dart';

/// Express 1-Screen Billing View for Mobile / Android.
/// Allows shopkeepers to select customer, search/scan products, adjust quantities
/// with Kirana weight chips, and save/print — all on a single screen without tab switching.
class MobileExpressBillingView extends ConsumerStatefulWidget {
  final GlobalKey boundaryKey;
  final String? customerName;
  final int? customerId;
  final TextEditingController customerController;
  final void Function(int customerId, String customerName) onCustomerSelected;
  final VoidCallback onClearCustomer;
  final Future<bool> Function({
    required int itemId,
    required double newQtyGrams,
    int? excludeLineIndex,
  }) checkStock;
  final VoidCallback onSaveBill;
  final VoidCallback onPrintBill;
  final VoidCallback onClearBill;

  const MobileExpressBillingView({
    super.key,
    required this.boundaryKey,
    required this.customerName,
    required this.customerId,
    required this.customerController,
    required this.onCustomerSelected,
    required this.onClearCustomer,
    required this.checkStock,
    required this.onSaveBill,
    required this.onPrintBill,
    required this.onClearBill,
  });

  @override
  ConsumerState<MobileExpressBillingView> createState() =>
      _MobileExpressBillingViewState();
}

class _MobileExpressBillingViewState
    extends ConsumerState<MobileExpressBillingView> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  List<Product> _searchResults = [];
  bool _isSearching = false;
  bool _showDropdown = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _debounceTimer?.cancel();
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _showDropdown = false;
      });
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      try {
        final repo = ref.read(itemRepositoryProvider);
        final results = await repo.search(query, lowStockOnly: false);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
            _showDropdown = true;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _isSearching = false);
        }
      }
    });
  }

  bool _isWeightProduct(Product item) {
    final u = item.unitType.trim().toLowerCase();
    return u.contains('કિલો') ||
        u == 'kg' ||
        u.contains('kilo') ||
        u.contains('ગ્રામ') ||
        u == 'g' ||
        u.contains('gram');
  }

  double _lineUnitPrice(BillLineItem line) {
    if (line.qtyGrams <= 0) return line.item.sellPrice;
    if (_isWeightProduct(line.item)) {
      return (line.amount * 1000.0) / line.qtyGrams;
    }
    return line.amount / line.qtyGrams;
  }

  Future<void> _promptAndAddProduct(Product item) async {
    _searchFocusNode.unfocus();
    final result = await ProductAdditionDialog.show(
      context,
      item: item,
      checkStock: (id, qty) => widget.checkStock(itemId: id, newQtyGrams: qty),
    );

    if (result != null && mounted) {
      final (qtyGrams, amount) = result;
      _applyProductAddition(item, qtyGrams, amount);
    }
  }

  void _applyProductAddition(Product item, double qtyGrams, double amount) {
    final currentLines = ref.read(billingControllerProvider).billLines;
    final existingIndex = currentLines.indexWhere((l) => l.item.id == item.id);

    if (existingIndex >= 0) {
      final existingLine = currentLines[existingIndex];
      final newQty = existingLine.qtyGrams + qtyGrams;
      final isWeight = _isWeightProduct(item);
      final unitPrice = item.sellPrice;
      final newAmount = isWeight
          ? (newQty / 1000.0) * unitPrice
          : newQty * unitPrice;

      ref.read(billingControllerProvider.notifier).updateLine(
            existingIndex,
            existingLine.copyWith(qtyGrams: newQty, amount: newAmount),
          );
    } else {
      ref.read(billingControllerProvider.notifier).addLine(
            BillLineItem(
              draftKey:
                  'draft_${item.id}_${DateTime.now().millisecondsSinceEpoch}',
              item: item,
              qtyGrams: qtyGrams,
              amount: amount,
            ),
          );
    }

    _searchController.clear();
    setState(() {
      _showDropdown = false;
      _searchResults = [];
    });
  }

  Future<void> _editLineWithWeightDialog(int index) async {
    if (index < 0 ||
        index >= ref.read(billingControllerProvider).billLines.length) return;
    final line = ref.read(billingControllerProvider).billLines[index];

    final result = await ProductAdditionDialog.show(
      context,
      item: line.item,
      initialQtyGrams: line.qtyGrams,
      checkStock: (id, qty) => widget.checkStock(
        itemId: id,
        newQtyGrams: qty,
        excludeLineIndex: index,
      ),
    );

    if (result != null && mounted) {
      final (newQty, newAmount) = result;
      ref.read(billingControllerProvider.notifier).updateLine(
            index,
            line.copyWith(qtyGrams: newQty, amount: newAmount),
          );
    }
  }

  void _updateLineQty(int index, double newQtyGrams) {
    if (index < 0 ||
        index >= ref.read(billingControllerProvider).billLines.length) return;
    final line = ref.read(billingControllerProvider).billLines[index];
    final isWeight = _isWeightProduct(line.item);
    final unitPrice = line.item.sellPrice;

    if (newQtyGrams <= 0) {
      _deleteLineWithUndo(index);
      return;
    }

    final newAmount = isWeight
        ? (newQtyGrams / 1000.0) * unitPrice
        : newQtyGrams * unitPrice;

    ref.read(billingControllerProvider.notifier).updateLine(
          index,
          line.copyWith(qtyGrams: newQtyGrams, amount: newAmount),
        );
  }

  void _stepQuantity(int index, bool isIncrement) {
    if (index < 0 ||
        index >= ref.read(billingControllerProvider).billLines.length) return;
    final line = ref.read(billingControllerProvider).billLines[index];
    final isWeight = _isWeightProduct(line.item);

    final double step = isWeight ? 250.0 : 1.0;
    final double newQty = isIncrement
        ? line.qtyGrams + step
        : (line.qtyGrams - step).clamp(0.0, double.infinity);

    _updateLineQty(index, newQty);
  }

  void _deleteLineWithUndo(int index) {
    if (index < 0 ||
        index >= ref.read(billingControllerProvider).billLines.length) return;
    final removedLine = ref.read(billingControllerProvider).billLines[index];
    ref.read(billingControllerProvider.notifier).removeLine(index);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('${removedLine.item.nameGujarati} દૂર કરવામાં આવ્યું'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'પાછું લાવો',
          onPressed: () {
            ref.read(billingControllerProvider.notifier).insertLine(
                  index,
                  removedLine,
                );
          },
        ),
      ),
    );
  }

  void _showCustomerSelectionSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ગ્રાહક પસંદ કરો',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              CustomerSearchField(
                controller: widget.customerController,
                hintText: 'ગ્રાહક શોધો અથવા નવો ઉમેરો...',
                onCustomerSelected: (id, name) {
                  widget.onCustomerSelected(id, name);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.person_outline),
                label: const Text('રોકડ ગ્રાહક (જનરલ કેશ)'),
                onPressed: () {
                  widget.onClearCustomer();
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final billingState = ref.watch(billingControllerProvider);
    final billLines = billingState.billLines;
    final activeDraft = ref.watch(billingTabsProvider).activeDraft;
    final currentTransactionType = activeDraft.transactionType;

    return Stack(
      children: [
        Column(
          children: [
            // ── TOP BAR: Customer selector chip & Quick Actions ──
            Container(
              color: Colors.grey.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  // Customer selection chip
                  Expanded(
                    child: InkWell(
                      onTap: _showCustomerSelectionSheet,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: widget.customerName != null
                              ? AppColors.primaryLight.withValues(alpha: 0.15)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: widget.customerName != null
                                ? AppColors.primary
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.customerName != null
                                  ? Icons.person
                                  : Icons.person_outline,
                              size: 18,
                              color: widget.customerName != null
                                  ? AppColors.primary
                                  : Colors.grey.shade700,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                widget.customerName ?? 'રોકડ ગ્રાહક',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: widget.customerName != null
                                      ? AppColors.primary
                                      : Colors.grey.shade800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_drop_down,
                              size: 18,
                              color: Colors.grey.shade600,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── TOP SEARCH BAR ──
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: 'ઉત્પાદન / બારકોડ શોધો...',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _showDropdown = false);
                          },
                        )
                      : null,
                ),
              ),
            ),
            const Divider(height: 1),

            // ── CENTRAL LIVE BILL LINES TABLE ──
            Expanded(
              child: billLines.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 54,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'બિલ ખાલી છે',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'ઉપરથી ઉત્પાદન શોધીને સીધું ઉમેરો',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _searchFocusNode.requestFocus(),
                              icon: const Icon(Icons.add_circle, size: 18),
                              label: const Text('+ નવી વસ્તુ ઉમેરો'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: billLines.length + 1,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemBuilder: (ctx, i) {
                        if (i == billLines.length) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
                            child: InkWell(
                              onTap: () => _searchFocusNode.requestFocus(),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_circle,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        '+ નવી વસ્તુ ઉમેરો',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        final line = billLines[i];
                        final isWeight = _isWeightProduct(line.item);
                        final unitPrice = _lineUnitPrice(line);
                        final unit = line.item.unitType;
                        final qtyDisplay = isWeight
                            ? '${(line.qtyGrams / 1000.0).toStringAsFixed(3)} કિલો'
                            : '${line.qtyGrams.toInt()} $unit';

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title row: Name, unit price, total, delete
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => _editLineWithWeightDialog(i),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              line.item.nameGujarati,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '₹${unitPrice.toStringAsFixed(2)} / $unit',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Text(
                                      formatCurrency(line.amount),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: Colors.red,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _deleteLineWithUndo(i),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Controls row: Stepper & Quick chips
                                Row(
                                  children: [
                                    // Stepper [-] [qty] [+]
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove, size: 16),
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(),
                                            onPressed: () => _stepQuantity(i, false),
                                          ),
                                          InkWell(
                                            onTap: () => _editLineWithWeightDialog(i),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 4,
                                              ),
                                              child: Text(
                                                qtyDisplay,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add, size: 16),
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(),
                                            onPressed: () => _stepQuantity(i, true),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Quick Kirana Gram Chips (if weight item)
                                    if (isWeight) ...[
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Wrap(
                                          spacing: 4,
                                          runSpacing: 4,
                                          alignment: WrapAlignment.end,
                                          children: [
                                            _buildQuickGramChip(
                                              label: '100g',
                                              targetGrams: 100,
                                              currentGrams: line.qtyGrams,
                                              onTap: () => _updateLineQty(i, 100),
                                            ),
                                            _buildQuickGramChip(
                                              label: '250g',
                                              targetGrams: 250,
                                              currentGrams: line.qtyGrams,
                                              onTap: () => _updateLineQty(i, 250),
                                            ),
                                            _buildQuickGramChip(
                                              label: '500g',
                                              targetGrams: 500,
                                              currentGrams: line.qtyGrams,
                                              onTap: () => _updateLineQty(i, 500),
                                            ),
                                            _buildQuickGramChip(
                                              label: '1kg',
                                              targetGrams: 1000,
                                              currentGrams: line.qtyGrams,
                                              onTap: () => _updateLineQty(i, 1000),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // ── PINNED BOTTOM SUMMARY & ACTION BAR ──
            RepaintBoundary(
              key: widget.boundaryKey,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Total & Discount Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'આઇટમ: ${billLines.length}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: InkWell(
                                    onTap: () async {
                                      final newDiscount =
                                          await DiscountDialog.show(
                                        context,
                                        billingState.discount,
                                      );
                                      if (newDiscount != null) {
                                        ref
                                            .read(
                                              billingControllerProvider.notifier,
                                            )
                                            .setDiscount(newDiscount);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.orange.shade300,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.remove,
                                            size: 13,
                                            color: Colors.orange.shade900,
                                          ),
                                          const SizedBox(width: 2),
                                          Flexible(
                                            child: Text(
                                              billingState.discount > 0
                                                  ? 'ડિસ્કાઉન્ટ: -₹${billingState.discount.toStringAsFixed(0)}'
                                                  : '- ₹0',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange.shade900,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('કુલ: ', style: TextStyle(fontSize: 13)),
                              Text(
                                formatCurrency(billingState.total),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Payment Mode Chips
                      Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildPaymentModeChip(
                                    label: '💵 કેશ',
                                    mode: 'cash',
                                    isSelected:
                                        currentTransactionType == 'cash',
                                  ),
                                  const SizedBox(width: 6),
                                  _buildPaymentModeChip(
                                    label: '📱 ઓનલાઇન',
                                    mode: 'online',
                                    isSelected:
                                        currentTransactionType == 'online',
                                  ),
                                  const SizedBox(width: 6),
                                  _buildPaymentModeChip(
                                    label: '📒 ખાતું',
                                    mode: 'khata',
                                    isSelected:
                                        currentTransactionType == 'khata',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (billLines.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: widget.onClearBill,
                              child: const Text(
                                'સાફ કરો',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Action Buttons: Save & Print, Save
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: ElevatedButton.icon(
                              onPressed: billLines.isEmpty ? null : widget.onPrintBill,
                              icon: const Icon(Icons.print, size: 20),
                              label: const Text(
                                'સાચવો & પ્રિન્ટ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: OutlinedButton.icon(
                              onPressed: billLines.isEmpty ? null : widget.onSaveBill,
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text(
                                'સાચવો',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        // ── AUTOCOMPLETE SEARCH RESULTS OVERLAY ──
        if (_showDropdown)
          Positioned(
            top: 96,
            left: 12,
            right: 12,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: (MediaQuery.sizeOf(context).height * 0.35)
                      .clamp(160.0, 280.0),
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : _searchResults.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                '"${_searchController.text}" માટે કોઈ ઉત્પાદન મળ્યું નથી',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _searchResults.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final item = _searchResults[i];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  item.nameGujarati,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '₹${item.sellPrice.toStringAsFixed(2)} / ${item.unitType}'
                                  '  •  સ્ટોક: ${item.stockQty % 1 == 0 ? item.stockQty.toInt() : item.stockQty.toStringAsFixed(2)}',
                                ),
                                trailing: const Icon(
                                  Icons.add_circle,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                                onTap: () => _promptAndAddProduct(item),
                              );
                            },
                          ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickGramChip({
    required String label,
    required double targetGrams,
    required double currentGrams,
    required VoidCallback onTap,
  }) {
    final isSelected = (currentGrams - targetGrams).abs() < 1;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentModeChip({
    required String label,
    required String mode,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        ref
            .read(billingTabsProvider.notifier)
            .setTransactionTypeForActive(mode);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
