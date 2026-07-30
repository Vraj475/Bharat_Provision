import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart' as strings;
import '../../../core/errors/error_handler.dart';
import '../../../core/errors/error_logger.dart';
import '../../../core/errors/error_types.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/product_model.dart';
import '../../../shared/widgets/errors/error_dialogue.dart';
import '../billing_providers.dart';
import '../controllers/billing_controller.dart';
import '../models/bill_line_item.dart';
import 'dialogs/product_addition_dialog.dart';

enum BillingDropdownType { none, product }

class BillingProductPanel extends ConsumerStatefulWidget {
  final String? customerName;
  final Future<bool> Function({required int itemId, required double newQtyGrams, int? excludeLineIndex}) checkStock;
  final FocusNode productSearchFocusNode;
  final TextEditingController searchController;

  const BillingProductPanel({
    super.key,
    required this.customerName,
    required this.checkStock,
    required this.productSearchFocusNode,
    required this.searchController,
  });

  @override
  ConsumerState<BillingProductPanel> createState() => _BillingProductPanelState();
}

class _BillingProductPanelState extends ConsumerState<BillingProductPanel> {
  final _productPanelStackKey = GlobalKey();
  final _productFieldKey = GlobalKey();
  BillingDropdownType _activeDropdown = BillingDropdownType.none;
  bool _lowStockPopupShown = false;
  int _draftLineCounter = 0;

  void _openDropdown(BillingDropdownType type) {
    if (!mounted) return;
    setState(() {
      _activeDropdown = type;
    });
  }

  void _closeAllDropdowns() {
    if (!mounted) return;
    setState(() {
      _activeDropdown = BillingDropdownType.none;
    });
  }

  RelativeRect? _dropdownAnchorRect(GlobalKey anchorKey) {
    final stackContext = _productPanelStackKey.currentContext;
    final anchorContext = anchorKey.currentContext;
    if (stackContext == null || anchorContext == null) return null;

    final stackBox = stackContext.findRenderObject() as RenderBox?;
    final anchorBox = anchorContext.findRenderObject() as RenderBox?;
    if (stackBox == null || anchorBox == null) return null;
    if (!stackBox.attached || !anchorBox.attached) return null;

    final anchorTopLeft = anchorBox.localToGlobal(
      Offset.zero,
      ancestor: stackBox,
    );
    return RelativeRect.fromLTRB(
      anchorTopLeft.dx,
      anchorTopLeft.dy + anchorBox.size.height,
      stackBox.size.width - (anchorTopLeft.dx + anchorBox.size.width),
      0,
    );
  }

  String _nextDraftLineKey(int? itemId) {
    _draftLineCounter++;
    return '${itemId ?? 0}_$_draftLineCounter';
  }

  bool _isOutOfStock(Product item) => item.stockQty <= 0;

  bool _isLowStock(Product item) =>
      item.stockQty > 0 && item.isLowStock;

  Widget _buildStockBadge(Product item) {
    if (_isOutOfStock(item)) {
      return Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 14, color: Colors.red),
            SizedBox(width: 4),
            Text(
              'સ્ટોક નથી',
              style: TextStyle(
                fontSize: 11,
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    if (_isLowStock(item)) {
      return Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 14, color: Colors.amber),
            SizedBox(width: 4),
            Text(
              'ઓછો સ્ટોક',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF8A5A00),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildProductNameLine(Product item) {
    final hasBadge = _isOutOfStock(item) || _isLowStock(item);
    return Row(
      children: [
        Expanded(
          child: Text(
            item.nameGujarati,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        if (hasBadge) _buildStockBadge(item),
      ],
    );
  }

  void _addProductToBill(Product item) async {
    try {
      if (item.stockQty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('સ્ટોક ઉપલબ્ધ નથી')),
        );
        return;
      }

      if (item.isLowStock) {
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('લો સ્ટોક ચેતવણી'),
            content: Text(
              '${item.nameGujarati} નો સ્ટોક ઓછો છે.\nહાલ સ્ટોક: ${item.stockQty.toStringAsFixed(2)} ${item.unitType}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('રદ કરો'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('ઉમેરો'),
              ),
            ],
          ),
        );

        if (shouldContinue != true) return;
      }

      if (!mounted) return;
      final result = await ProductAdditionDialog.show(
        context,
        item: item,
        checkStock: (id, qty) => widget.checkStock(itemId: id, newQtyGrams: qty),
      );

      if (result != null) {
        final qtyGrams = result.$1;
        final amount = result.$2;
        ref.read(billingControllerProvider.notifier).addLine(
          BillLineItem(
            draftKey: _nextDraftLineKey(item.id),
            item: item,
            qtyGrams: qtyGrams,
            amount: amount,
          ),
        );
        
        if (mounted) {
          widget.productSearchFocusNode.requestFocus();
          widget.searchController.clear();
          ref.read(billingSearchProvider.notifier).state = '';
        }
      }
    } catch (error, stack) {
      await ErrorLogger.log(
        AppError(
          code: 'BILLING_ADD_002',
          category: ErrorCategory.validation,
          technicalMessage: error.toString(),
          userMessage: 'આઇટમ ઉમેરવામાં ભૂલ આવી. ફરી પ્રયાસ કરો.',
          isCritical: false,
          timestamp: DateTime.now(),
          stackTrace: stack,
        ),
        currentScreen: 'BillingProductPanel._addProductToBill',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('આઇટમ ઉમેરવામાં ભૂલ આવી')));
      }
    }
  }

  Widget _buildTransactionTypeButton({
    required String label,
    required IconData icon,
    required String value,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.3),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveDropdown(List<Product> products) {
    final isProduct = _activeDropdown == BillingDropdownType.product;
    if (!isProduct) {
      return const SizedBox.shrink();
    }

    final anchorRect = _dropdownAnchorRect(_productFieldKey);
    if (anchorRect == null) return const SizedBox.shrink();

    final query = widget.searchController.text.trim();
    if (query.isEmpty) return const SizedBox.shrink();

    final productRows = products.take(8).toList();
    final children = productRows.map((item) {
      final outOfStock = _isOutOfStock(item);
      return Opacity(
        opacity: outOfStock ? 0.5 : 1,
        child: InkWell(
          onTap: outOfStock
              ? null
              : () {
                  if (!mounted) return;
                  _closeAllDropdowns();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _addProductToBill(item);
                  });
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProductNameLine(item),
                const SizedBox(height: 4),
                Text(
                  '₹${item.sellPrice.toStringAsFixed(2)} | સ്ടોક: ${item.stockQty.toStringAsFixed(2)} ${item.unitType}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: anchorRect.left,
      right: anchorRect.right,
      top: anchorRect.top,
      child: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: children,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(billingItemsProvider);
    final billingState = ref.watch(billingTabsProvider);
    final transactionType = billingState.activeDraft.transactionType;
    final productsForDropdown = state.valueOrNull ?? const <Product>[];
    
    return Stack(
      key: _productPanelStackKey,
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Transaction type selector
                  Row(
                    spacing: 12,
                    children: [
                      Expanded(
                        child: _buildTransactionTypeButton(
                          label: 'રોકડ',
                          icon: Icons.payments,
                          value: 'cash',
                          selected: transactionType == 'cash',
                          onPressed: () {
                            ref
                                .read(billingTabsProvider.notifier)
                                .setTransactionTypeForActive('cash');
                          },
                        ),
                      ),
                      Expanded(
                        child: _buildTransactionTypeButton(
                          label: 'ઉધાર',
                          icon: Icons.account_balance_wallet,
                          value: 'udhaar',
                          selected: transactionType == 'udhaar',
                          onPressed: () {
                            ref
                                .read(billingTabsProvider.notifier)
                                .setTransactionTypeForActive('udhaar');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.customerName ?? 'ગ્રાહક પસંદ કરો (જરૂરી)',
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.customerName != null
                                  ? Colors.black
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  IgnorePointer(
                    child: Container(
                      key: _productFieldKey,
                      child: TextField(
                        controller: widget.searchController,
                        focusNode: widget.productSearchFocusNode,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: strings.AppStrings.searchHintProducts,
                          border: OutlineInputBorder(),
                        ),
                        onTap: () {
                          if (widget.searchController.text.trim().isNotEmpty) {
                            _openDropdown(BillingDropdownType.product);
                          }
                        },
                        onChanged: (value) {
                          ref.read(billingSearchProvider.notifier).state = value;
                          if (value.trim().isEmpty) {
                            _closeAllDropdowns();
                          } else {
                            _openDropdown(BillingDropdownType.product);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: state.when(
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'કોઈ ઉત્પાદન મળ્યું નહીં',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.searchController.text.isEmpty
                                ? 'ઉત્પાદન ઉમેરવા માટે ઇન્વેન્ટરીમાં જાઓ'
                                : '"${widget.searchController.text}" માટે કોઈ ઉત્પાદન નથી',
                            style: const TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('પુનરાવર્તમાન કરો'),
                            onPressed: () {
                              ref.read(billingSearchProvider.notifier).state = '';
                              widget.searchController.clear();
                              ref.invalidate(billingItemsProvider);
                            },
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (ctx, i) {
                      final item = items[i];
                      if (!_lowStockPopupShown) {
                        final lowStockItems = items
                            .where((p) => p.stockQty > 0 && p.isLowStock)
                            .toList();
                        if (lowStockItems.isNotEmpty) {
                          _lowStockPopupShown = true;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('લો સ્ટોક એલર્ટ'),
                                content: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: lowStockItems
                                        .take(6)
                                        .map(
                                          (p) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 6,
                                            ),
                                            child: Text(
                                              '• ${p.nameGujarati}: ${p.stockQty.toStringAsFixed(2)} ${p.unitType}',
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    child: const Text('બરાબર'),
                                  ),
                                ],
                              ),
                            );
                          });
                        }
                      }
                      return Opacity(
                        opacity: _isOutOfStock(item) ? 0.5 : 1,
                        child: ListTile(
                          leading: const Icon(Icons.inventory_2),
                          title: _buildProductNameLine(item),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('₹${item.sellPrice.toStringAsFixed(2)}'),
                              Text(
                                'સ્ટોક: ${item.stockQty.toStringAsFixed(2)} ${item.unitType}',
                                style: TextStyle(
                                  color: item.isLowStock
                                      ? Colors.red
                                      : Colors.grey,
                                  fontWeight: item.isLowStock
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          onTap: _isOutOfStock(item)
                              ? null
                              : () => _addProductToBill(item),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) {
                  final appError = e is AppError
                      ? e
                      : ErrorHandler.handle(
                          e,
                          st,
                          context: 'BillingProductPanel',
                        );
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ErrorDialogue.showSnackbar(
                      context,
                      message: appError.userMessage,
                      code: appError.code,
                      type: ErrorDialogueType.error,
                    );
                  });
                  return Center(
                    child: Text(
                      appError.userMessage,
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        _buildActiveDropdown(productsForDropdown),
      ],
    );
  }
}
