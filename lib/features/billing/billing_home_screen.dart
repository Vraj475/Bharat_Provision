import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart' as strings;
import '../../core/errors/error_handler.dart';
import '../../core/errors/error_logger.dart';
import '../../core/errors/error_types.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/numpad.dart';
import '../../shared/widgets/errors/error_dialogue.dart';
import '../../shared/widgets/errors/error_dialog.dart';
import '../../shared/widgets/customer_search_field.dart';
import '../../core/utils/currency_format.dart';
import '../../core/utils/weight_calculator.dart';
import '../../data/models/bill_item_input.dart';
import '../../data/models/item.dart';
import 'models/bill_line_item.dart';
import '../../core/auth/role_provider.dart';
import '../../routing/app_router.dart';
import 'billing_providers.dart';
import '../../core/services/notification_service.dart';
import '../../features/inventory/inventory_providers.dart';
import '../../features/stock/stock_providers.dart';
import '../../features/settings/providers/auth_provider.dart';
import '../../features/settings/screens/role_selection_screen.dart';
import '../../features/settings/settings_providers.dart';
import '../../data/providers.dart';
import '../../data/services/bill_service_provider.dart';
import '../../features/reports/reports_providers.dart';
import 'views/dialogs/product_addition_dialog.dart';
import 'views/bill_summary_panel.dart';
import 'views/bill_lines_panel.dart';
import 'controllers/billing_controller.dart';
/// Simplified single-screen billing - Create bills and print them.
class BillingHomeScreen extends ConsumerStatefulWidget {
  const BillingHomeScreen({super.key});

  @override
  ConsumerState<BillingHomeScreen> createState() => _BillingHomeScreenState();
}

class _BillingHomeScreenState extends ConsumerState<BillingHomeScreen> {
  final _productPanelStackKey = GlobalKey();
  final _productFieldKey = GlobalKey();
  final _billBoundaryDesktopKey = GlobalKey();
  final _billBoundaryMobileKey = GlobalKey();
  final BlueThermalPrinter _bluePrinter = BlueThermalPrinter.instance;
  final _customerController = TextEditingController();
  final _searchController = TextEditingController();
  final _weightEntryController = TextEditingController();
  final _customerNameDialogController = TextEditingController();
  final _shopNameDialogController = TextEditingController();
  final _discountDialogController = TextEditingController();
  final _customerFocusNode = FocusNode();
  final _productSearchFocusNode = FocusNode();
  int _draftLineCounter = 0;
  // double _discount = 0;
  String? _bannerMessage;
  String? _customerName;
  String? _shopName;
  int? _customerId;

  bool _lowStockPopupShown = false;
  final _weightEntryFocusNode = FocusNode();
  final _grandTotalEditController = TextEditingController();
  final _grandTotalEditFocusNode = FocusNode();
  // bool _isEditingGrandTotal = false;
  // bool _isGrandTotalAdjusted = false;
  bool _isDisposed = false;
  _BillingDropdownType _activeDropdown = _BillingDropdownType.none;

  @override
  void initState() {
    super.initState();

    // Load all items when screen loads (from inventory items table)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(billingSearchProvider.notifier).state = '';
      ref.invalidate(billingItemsProvider);
      _loadShopProfileFromSettings();
      _customerFocusNode.requestFocus();
    });
  }

  Future<void> _loadShopProfileFromSettings() async {
    final repo = await ref.read(settingsRepositoryFutureProvider.future);
    final savedShopName = (await repo.get('shop_name')).trim();
    if (!mounted) return;
    setState(() {
      _shopName = savedShopName.isEmpty ? null : savedShopName;
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _customerFocusNode.unfocus();

      controller.dispose();
    }
      node.dispose();
    }

    _weightEntryController.dispose();
    _customerNameDialogController.dispose();
    _shopNameDialogController.dispose();
    _discountDialogController.dispose();
    _weightEntryFocusNode.dispose();
    _grandTotalEditController.dispose();
    _grandTotalEditFocusNode.dispose();
    _customerController.dispose();
    _searchController.dispose();
    _customerFocusNode.dispose();
    _productSearchFocusNode.dispose();
    super.dispose();
  }

  void _focusProductSearch() {
    if (!mounted || _isDisposed) {
      return;
    }
    FocusScope.of(context).requestFocus(_productSearchFocusNode);
  }

  void _openDropdown(_BillingDropdownType type) {
    if (!mounted || _isDisposed) {
      return;
    }
    setState(() {
      _activeDropdown = type;
    });
  }

  void _closeAllDropdowns({bool markClosing = false}) {
    if (!mounted || _isDisposed) {
      return;
    }
    setState(() {
      _activeDropdown = _BillingDropdownType.none;
    });
  }

  void _releaseDropdownClosingFlagNextFrame() {
    // No longer needed
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



  void _setShopName() async {
    _shopNameDialogController.text = _shopName ?? '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('દુકાનનું નામ દાખલ કરો'),
        content: TextField(
          controller: _shopNameDialogController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'દુકાનનું નામ',
            hintText: 'દુકાનનું નામ દાખલ કરો...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(strings.AppStrings.cancelButton),
          ),
          ElevatedButton(
            onPressed: () async {
              final newShopName = _shopNameDialogController.text.trim().isEmpty
                  ? null
                  : _shopNameDialogController.text.trim();

              if (!mounted || _isDisposed) {
                return;
              }
              setState(() => _shopName = newShopName);

              // Save to settings
              if (newShopName != null) {
                final repo = await ref.read(
                  settingsRepositoryFutureProvider.future,
                );
                await repo.set('shop_name', newShopName);
                ref.invalidate(shopNameProvider);
                ref.invalidate(settingsValuesProvider);
              }

              if (!ctx.mounted) {
                return;
              }
              Navigator.of(ctx).pop();
            },
            child: const Text(strings.AppStrings.saveButton),
          ),
        ],
      ),
    );
  }


  Future<void> _saveBill() async {
    if (ref.read(billingControllerProvider).billLines.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('બિલ ખાલી છે. કૃપયા આઇટમ ઉમેરો.')),
      );
      return;
    }

    await _saveBillToDatabase(showSuccessMessage: true, clearDraft: true);
  }

  List<BillItemInput> _buildBillItemsFromLines(List<BillLineItem> lines) {
    return lines.map((line) {
      final quantityInStockUnit = _toStockUnitQuantity(line);
      final double unitPrice = quantityInStockUnit > 0
          ? line.amount / quantityInStockUnit
          : 0.0;
      return BillItemInput(
        itemId: line.item.id ?? 0,
        quantity: quantityInStockUnit,
        unitPrice: unitPrice,
      );
    }).toList();
  }

  void _clearCurrentBillDraft() {

    setState(() {
      
      _customerName = null;
      _customerId = null;
      _activeDropdown = _BillingDropdownType.none;
      _customerController.clear();
    });
    ref.read(billingTabsProvider.notifier).clearActive();
    ref.read(billingControllerProvider.notifier).clearBill();
    ref.read(billingControllerProvider.notifier).syncLines([]);
  }

  Future<int?> _saveBillToDatabase({
    required bool showSuccessMessage,
    required bool clearDraft,
  }) async {
    debugPrint('SAVE TRACE: entered _saveBillToDatabase');

    // Get current transaction type from provider
    final billingState = ref.read(billingTabsProvider);
    final transactionType = billingState.activeDraft.transactionType;
    final selectedCustomerId =
        billingState.activeDraft.customerId ?? _customerId;

    // Validate: Udhaar requires a customer with ID (not just name)
    debugPrint(
      'SAVE CHECK: transactionType=$transactionType selectedCustomerId=$selectedCustomerId',
    );
    debugPrint('SAVE CHECK: customerId=$selectedCustomerId');
    if (transactionType == 'udhaar' && selectedCustomerId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ઉધાર માટે ગ્રાહક પસંદ કરવો જરૂરી છે'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return null;
    }

    final linesSnapshot = ref.read(billingControllerProvider).billLines;
    final discountSnapshot = ref.read(billingControllerProvider).discount;
    final customerIdSnapshot = selectedCustomerId;
    final customerNameSnapshot = _customerName?.trim();
    final productIds = linesSnapshot
        .map((l) => l.item.id)
        .whereType<int>()
        .toList();

    try {
      debugPrint('SAVE TRACE: building BillItemInput list');
      final billItems = _buildBillItemsFromLines(linesSnapshot);
      debugPrint('SAVE TRACE: reading billRepositoryFutureProvider');
      final billRepo = await ref.read(billRepositoryFutureProvider.future);
      debugPrint('SAVE TRACE: calling BillRepository.createBill');
      final billId = await billRepo.createBill(
        customerId: customerIdSnapshot,
        customerNameSnapshot:
            (customerNameSnapshot == null || customerNameSnapshot.isEmpty)
            ? null
            : customerNameSnapshot,
        items: billItems,
        discountAmount: discountSnapshot,
        paidAmount:
            linesSnapshot.fold(0.0, (s, l) => s + l.amount) - discountSnapshot,
        paymentMode: transactionType,
        userId: null,
      );
      debugPrint('SAVE TRACE: createBill returned billId=$billId');

      if (mounted) {
        ref.invalidate(reportRepositoryFutureProvider);
        ref.invalidate(salesReportProvider);
        ref.invalidate(billingItemsProvider);
        ref.invalidate(itemListProvider);
        ref.invalidate(stockDashboardProductsProvider);
        ref.invalidate(todaysBillsProvider);
      }

      try {
        debugPrint('SAVE TRACE: updating stock alerts');
        await _updateStockAlerts(productIds);
        debugPrint('SAVE TRACE: stock alerts updated');
      } catch (_) {
        // Do not block bill save if stock-alert refresh fails.
        debugPrint('SAVE TRACE: stock alert update failed (non-blocking)');
      }

      if (mounted && clearDraft) {
        _clearCurrentBillDraft();
      }

      if (mounted && showSuccessMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('બિલ સેવ થઈ ગયું')));
      }

      return billId;
    } catch (error, stack) {
      debugPrint('SAVE FAILED: $error \n $stack');
      final appError = AppError(
        code: 'DB_003',
        category: ErrorCategory.database,
        technicalMessage: error.toString(),
        userMessage:
            'બિલ સેવ કરવામાં નિષ્ફળ. કોઈ ડેટા બદલાયો નથી. ફરી પ્રયાસ કરો.',
        isCritical: false,
        timestamp: DateTime.now(),
        stackTrace: stack,
      );
      await ErrorLogger.log(
        appError,
        currentScreen: 'BillingHomeScreen._saveBillToDatabase',
      );

      if (mounted) {
        await ErrorDialog.show(context, appError);
      }
      return null;
    }
  }

  Future<void> _updateStockAlerts(List<int> productIds) async {
    final stockRepo = ref.read(stockRepositoryProvider);
    final alertResult = await stockRepo.checkStockAlerts(productIds);
    final userRole = await _getCurrentUserRole();

    if (alertResult.lowStock.isNotEmpty || alertResult.outOfStock.isNotEmpty) {
      final names = [
        ...alertResult.lowStock.map((p) => p.nameGujarati),
        ...alertResult.outOfStock.map((p) => p.nameGujarati),
      ].join(', ');
      if (userRole == 'employee') {
        setState(() {
          _bannerMessage = 'સ્ટોક ઓછો/ખૂટ્યો: $names';
        });
      } else {
        setState(() {
          _bannerMessage = 'સ્ટોક ઓછો/ખૂટ્યો: $names';
        });
        for (final p in alertResult.lowStock) {
          await NotificationService.instance.showLowStockAlert(
            productName: p.nameGujarati,
            qty: p.stockQty,
          );
        }
        for (final p in alertResult.outOfStock) {
          await NotificationService.instance.showOutOfStockAlert(
            productName: p.nameGujarati,
          );
        }
      }
    } else {
      setState(() {
        _bannerMessage = null;
      });
    }
  }

  Future<String> _getCurrentUserRole() async {
    // Replace with actual user role fetch logic
    // For demo, return 'admin'
    return 'admin';
  }

  Future<double> _getLatestStockKg(int itemId) async {
    final repo = await ref.read(itemRepositoryFutureProvider.future);
    final latestItem = await repo.getById(itemId);
    return latestItem?.currentStock ?? 0.0;
  }

  Future<bool> _hasEnoughStockForDraft({
    required int itemId,
    required double newQtyGrams,
    int? excludeLineIndex,
  }) async {
    final latestStockKg = await _getLatestStockKg(itemId);
    var existingQtyKg = 0.0;

    for (var i = 0; i < ref.read(billingControllerProvider).billLines.length; i++) {
      final line = ref.read(billingControllerProvider).billLines[i];
      if (line.item.id != itemId) continue;
      if (excludeLineIndex != null && i == excludeLineIndex) continue;
      existingQtyKg += line.qtyGrams / 1000.0;
    }

    final requestedQtyKg = newQtyGrams / 1000.0;
    return (existingQtyKg + requestedQtyKg) <= latestStockKg;
  }

  bool _isOutOfStock(Item item) => item.currentStock <= 0;

  bool _isLowStock(Item item) =>
      item.currentStock > 0 && item.currentStock <= item.lowStockThreshold;

  Widget _buildStockBadge(Item item) {
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

  Widget _buildProductNameLine(Item item) {
    final hasBadge = _isOutOfStock(item) || _isLowStock(item);
    return Row(
      children: [
        Expanded(
          child: Text(
            item.nameGu,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        if (hasBadge) _buildStockBadge(item),
      ],
    );
  }

  Future<bool> _addProductWithWeightFromBottomSheet({
    required Item item,
    required double weightKg,
  }) async {
    if (!mounted || _isDisposed) {
      return false;
    }

    if (item.currentStock <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('સ્ટોક ઉપલબ્ધ નથી')));
      return false;
    }

    if (item.isLowStock) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('લો સ્ટોક ચેતવણી'),
          content: Text(
            '${item.nameGu} નો સ્ટોક ઓછો છે.\nહાલ સ્ટોક: ${item.currentStock.toStringAsFixed(2)} ${item.unit}',
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

      if (shouldContinue != true) {
        return false;
      }
    }

    final grams = weightKg * 1000.0;
    final itemId = item.id;
    if (itemId != null) {
      final hasStock = await _hasEnoughStockForDraft(
        itemId: itemId,
        newQtyGrams: grams,
      );
      if (!mounted || _isDisposed) return false;
      if (!hasStock) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'સ્ટોક અવેલેબલ નથી કૃપા કરી ખરીદી ની યાદી માં એડ કરો',
            ),
          ),
        );
        return false;
      }
    }

    final amount = WeightCalculator.calculateAmountFromWeight(
      weightGrams: grams,
      sellPricePerKg: item.salePrice,
    );

    setState(() {
      ref.read(billingControllerProvider.notifier).addLine(
        BillLineItem(
          draftKey: _nextDraftLineKey(item.id),
          item: item,
          qtyGrams: grams,
          amount: amount,
        ),
      );
    });
    return true;
  }

  Future<void> _openAndroidProductBottomSheet() async {
    if (!mounted || _isDisposed) {
      return;
    }
    Item? selectedItem;
    _weightEntryController.clear();

    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
    }
    ref.read(billingSearchProvider.notifier).state = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Consumer(
              builder: (context, ref, _) {
                final state = ref.watch(billingItemsProvider);
                final maxHeight = MediaQuery.of(ctx).size.height * 0.88;

                return SizedBox(
                  height: maxHeight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: selectedItem == null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Transaction type selector for Android bottom sheet
                              Consumer(
                                builder: (context, ref, _) {
                                  final billingState = ref.watch(
                                    billingTabsProvider,
                                  );
                                  final transactionType =
                                      billingState.activeDraft.transactionType;
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: _buildTransactionTypeButton(
                                          label: 'રોકડ',
                                          icon: Icons.payments,
                                          value: 'cash',
                                          selected: transactionType == 'cash',
                                          onPressed: () {
                                            ref
                                                .read(
                                                  billingTabsProvider.notifier,
                                                )
                                                .setTransactionTypeForActive(
                                                  'cash',
                                                );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildTransactionTypeButton(
                                          label: 'ઉધાર',
                                          icon: Icons.account_balance_wallet,
                                          value: 'udhaar',
                                          selected: transactionType == 'udhaar',
                                          onPressed: () {
                                            ref
                                                .read(
                                                  billingTabsProvider.notifier,
                                                )
                                                .setTransactionTypeForActive(
                                                  'udhaar',
                                                );
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.search),
                                  hintText:
                                      'નામ અથવા marchu chaval tel ટાઈપ કરો',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  ref
                                          .read(billingSearchProvider.notifier)
                                          .state =
                                      value;
                                },
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: state.when(
                                  data: (items) {
                                    if (items.isEmpty) {
                                      return const Center(
                                        child: Text('કોઈ ઉત્પાદન મળ્યું નહીં'),
                                      );
                                    }
                                    return ListView.separated(
                                      itemCount: items.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(height: 8),
                                      itemBuilder: (_, i) {
                                        final item = items[i];
                                        final outOfStock = _isOutOfStock(item);
                                        return Opacity(
                                          opacity: outOfStock ? 0.5 : 1,
                                          child: Card(
                                            child: InkWell(
                                              onTap: outOfStock
                                                  ? null
                                                  : () {
                                                      if (!mounted ||
                                                          _isDisposed) {
                                                        return;
                                                      }
                                                      _closeAllDropdowns(
                                                        markClosing: true,
                                                      );
                                                      Navigator.of(ctx).pop();
                                                      WidgetsBinding.instance
                                                          .addPostFrameCallback((
                                                            _,
                                                          ) {
                                                            if (!mounted ||
                                                                _isDisposed) {
                                                              return;
                                                            }
                                                            _addProductToBill(
                                                              item,
                                                            );
                                                            _releaseDropdownClosingFlagNextFrame();
                                                          });
                                                    },
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    _buildProductNameLine(item),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      '₹${item.salePrice.toStringAsFixed(2)} પ્રતિ કિલો',
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'સ્ટોક: ${item.currentStock.toStringAsFixed(2)} ${item.unit}',
                                                      style: TextStyle(
                                                        color: Colors
                                                            .grey
                                                            .shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  loading: () => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  error: (e, st) => Center(
                                    child: Text(
                                      (e is AppError)
                                          ? e.userMessage
                                          : 'ભૂલ આવી છે. ફરી પ્રયાસ કરો.',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      setSheetState(() {
                                        selectedItem = null;
                                        _weightEntryController.clear();
                                      });
                                    },
                                    icon: const Icon(Icons.arrow_back),
                                  ),
                                  Expanded(
                                    child: _buildProductNameLine(selectedItem!),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              NumpadTextField(
                                controller: _weightEntryController,
                                allowDecimal: true,
                                decoration: const InputDecoration(
                                  labelText: 'વજન (કિલો)',
                                  hintText: 'કિલોમાં દાખલ કરો જેમ કે 1.500',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              NumpadWidget(
                                controller: _weightEntryController,
                                allowDecimal: true,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final rawKg = _weightEntryController.text
                                      .trim();
                                  final parsedKg = double.tryParse(rawKg);
                                  if (rawKg.isEmpty ||
                                      parsedKg == null ||
                                      parsedKg <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('વજન દાખલ કરો'),
                                      ),
                                    );
                                    return;
                                  }

                                  final added =
                                      await _addProductWithWeightFromBottomSheet(
                                        item: selectedItem!,
                                        weightKg: parsedKg,
                                      );
                                  if (!mounted || !ctx.mounted) {
                                    return;
                                  }
                                  if (added) {
                                    Navigator.of(ctx).pop();
                                  }
                                },
                                icon: const Icon(Icons.add_shopping_cart),
                                label: const Text('Add to Bill'),
                              ),
                            ],
                          ),
                  ),
                );
              },
            );
          },
        );
      },
    );

    if (!mounted || _isDisposed) {
      return;
    }
    _searchController.clear();
    ref.read(billingSearchProvider.notifier).state = '';
  }

  String _currentRoleGujaratiLabel() {
    final session = ref.read(authSessionProvider);
    final String role =
        session?.role ?? ref.read(currentRoleProvider) ?? 'employee';
    return RoleInfo.fromRole(role).displayNameGu;
  }

  String _roleInitialForAvatar(String roleLabel) {
    final trimmed = roleLabel.trim();
    if (trimmed.isEmpty) return 'R';
    return trimmed.substring(0, 1);
  }

  void _logoutFromBilling() {
    ref.read(authSessionProvider.notifier).logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (route) => false,
    );
  }

  void _addProductToBill(Item item) async {
    try {
      if (item.currentStock <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('સ્ટોક ઉપલબ્ધ નથી')), // Gujarati message
        );
        return;
      }

      if (item.isLowStock) {
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('લો સ્ટોક ચેતવણી'),
            content: Text(
              '${item.nameGu} નો સ્ટોક ઓછો છે.\nહાલ સ્ટોક: ${item.currentStock.toStringAsFixed(2)} ${item.unit}',
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
        checkStock: (id, qty) => _hasEnoughStockForDraft(itemId: id, newQtyGrams: qty),
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
        final addedKey = ref.read(billingControllerProvider).billLines.last.draftKey;
        
        if (mounted) {
          setState(() {});
          _focusProductSearch();
        }
        // Wire up the new controller even if it's not strictly driving the UI yet
        ref.read(billingControllerProvider.notifier).addLine(ref.read(billingControllerProvider).billLines.last);
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
        currentScreen: 'BillingHomeScreen._addProductToBill',
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('આઇટમ ઉમેરવામાં ભૂલ આવી')));
      }
    }
  }












  Future<void> _printBill() async {
    if (ref.read(billingControllerProvider).billLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('બિલ ખાલી છે. કૃપया આઇટમ ઉમેરો.')),
      );
      return;
    }
    final billId = await _saveBillToDatabase(
      showSuccessMessage: false,
      clearDraft: false,
    );
    if (billId == null) {
      return;
    }

    await _attemptPrintSavedBill(billId, allowRetry: true);
  }

  Future<Uint8List?> _captureBillImageBytes() async {
    final boundary =
        (_billBoundaryDesktopKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?) ??
        (_billBoundaryMobileKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?);
    if (boundary == null || !boundary.attached) return null;

    final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _attemptPrintSavedBill(
    int billId, {
    required bool allowRetry,
  }) async {
    try {
      final billRepo = await ref.read(billRepositoryFutureProvider.future);
      final savedBill = await billRepo.getById(billId);
      final savedBillItems = await billRepo.getBillItems(billId);
      if (savedBill == null || savedBillItems.isEmpty) {
        throw StateError('PRINT_001');
      }

      final connected = await _bluePrinter.isConnected ?? false;
      if (!connected) {
        throw StateError('PRINT_001');
      }

      final billImageBytes = await _captureBillImageBytes();
      if (billImageBytes == null) {
        throw StateError('PRINT_001');
      }

      await _bluePrinter.writeBytes(billImageBytes);
      if (!mounted) return;
      _clearCurrentBillDraft();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('બિલ પ્રિન્ટ થઈ ગયું.')));
    } catch (error, stack) {
      final appError = AppError(
        code: 'PRINT_001',
        category: ErrorCategory.printing,
        technicalMessage: error.toString(),
        userMessage: 'પ્રિન્ટર કનેક્ટ નથી અથવા ભૂલ આવી. બિલ સેવ થઈ ગયું છે.',
        isCritical: false,
        timestamp: DateTime.now(),
        stackTrace: stack,
      );
      await ErrorLogger.log(
        appError,
        currentScreen: 'BillingHomeScreen._attemptPrintSavedBill',
      );

      if (!mounted) return;

      if (!allowRetry) {
        _clearCurrentBillDraft();
        return;
      }

      ErrorDialogue.showSnackbar(
        context,
        message: 'પ્રિન્ટર કનેક્ટ નથી અથવા ભૂલ આવી. બિલ સેવ થઈ ગયું છે.',
        code: 'PRINT_001',
        type: ErrorDialogueType.error,
        retryCallback: () {
          _attemptPrintSavedBill(billId, allowRetry: false);
        },
      );
    }
  }

  double _toStockUnitQuantity(BillLineItem line) {
    final unit = line.item.unit.trim().toLowerCase();
    if (unit.contains('કિલો') || unit == 'kg' || unit.contains('kilo')) {
      return line.qtyGrams / 1000.0;
    }
    if (unit.contains('ગ્રામ') || unit == 'g' || unit.contains('gram')) {
      return line.qtyGrams;
    }
    return line.qtyGrams;
  }

  @override
  Widget build(BuildContext context) {
    final isWindows = Platform.isWindows;
    final roleLabelGu = _currentRoleGujaratiLabel();
    final avatarText = _roleInitialForAvatar(roleLabelGu);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(strings.AppStrings.billingTitle),
        actions: [
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
                maxWidth: 40,
                maxHeight: 40,
              ),
              icon: const Icon(Icons.save),
              onPressed: _saveBill,
              tooltip: 'બિલ સાચવો',
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
                maxWidth: 40,
                maxHeight: 40,
              ),
              icon: const Icon(Icons.print),
              onPressed: _printBill,
              tooltip: 'બિલ છાપો',
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'returns') {
                Navigator.of(context).pushNamed(AppRouter.returnsNew);
              } else if (value == 'replace') {
                Navigator.of(context).pushNamed(AppRouter.returnsReplace);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'returns', child: Text('પાછું આપવું')),
              const PopupMenuItem(value: 'replace', child: Text('બદલવું')),
            ],
          ),
          if (!isWindows)
            PopupMenuButton<String>(
              tooltip: 'એકાઉન્ટ',
              onSelected: (value) {
                if (value == 'logout') {
                  _logoutFromBilling();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text(
                    roleLabelGu,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red),
                      SizedBox(width: 8),
                      Text('લૉગ આઉટ', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: CircleAvatar(
                  radius: 15,
                  child: Text(
                    avatarText,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_bannerMessage != null)
            Container(
              color: Colors.red.shade100,
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _bannerMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: isWindows ? _buildDesktopLayout() : _buildAndroidLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(flex: 2, child: _buildProductPanel()),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 3,
          child: RepaintBoundary(
            key: _billBoundaryDesktopKey,
            child: _buildBillPanel(isWindows: true),
          ),
        ),
      ],
    );
  }

  Widget _buildAndroidLayout() {
    return RepaintBoundary(
      key: _billBoundaryMobileKey,
      child: _buildBillPanel(isWindows: false),
    );
  }

  Widget _buildProductPanel() {
    final state = ref.watch(billingItemsProvider);
    final billingState = ref.watch(billingTabsProvider);
    final transactionType = billingState.activeDraft.transactionType;
    final productsForDropdown = state.valueOrNull ?? const <Item>[];
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
                            _customerName ?? 'ગ્રાહક પસંદ કરો (જરૂરી)',
                            style: TextStyle(
                              fontSize: 12,
                              color: _customerName != null
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
                        controller: _searchController,
                        focusNode: _productSearchFocusNode,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: strings.AppStrings.searchHintProducts,
                          border: OutlineInputBorder(),
                        ),
                        onTap: () {
                          if (_searchController.text.trim().isNotEmpty) {
                            _openDropdown(_BillingDropdownType.product);
                          }
                        },
                        onChanged: (value) {
                          ref.read(billingSearchProvider.notifier).state =
                              value;
                          if (value.trim().isEmpty) {
                            _closeAllDropdowns();
                          } else {
                            _openDropdown(_BillingDropdownType.product);
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
                            _searchController.text.isEmpty
                                ? 'ઉત્પાદન ઉમેરવા માટે ઇન્વેન્ટરીમાં જાઓ'
                                : '"${_searchController.text}" માટે કોઈ ઉત્પાદન નથી',
                            style: const TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('પુનરાવર્તમાન કરો'),
                            onPressed: () {
                              ref.read(billingSearchProvider.notifier).state =
                                  '';
                              _searchController.clear();
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
                            .where((p) => p.currentStock > 0 && p.isLowStock)
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
                                              '• ${p.nameGu}: ${p.currentStock.toStringAsFixed(2)} ${p.unit}',
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
                              Text('₹${item.salePrice.toStringAsFixed(2)}'),
                              Text(
                                'સ્ટોક: ${item.currentStock.toStringAsFixed(2)} ${item.unit}',
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
                          context: 'BillingHomeScreen',
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

  Widget _buildActiveDropdown(List<Item> products) {
    final isProduct = _activeDropdown == _BillingDropdownType.product;
    if (!isProduct) {
      return const SizedBox.shrink();
    }

    final anchorRect = _dropdownAnchorRect(_productFieldKey);
    if (anchorRect == null) return const SizedBox.shrink();

    final query = _searchController.text.trim();
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
                  if (!mounted || _isDisposed) {
                    return;
                  }
                  _closeAllDropdowns();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted || _isDisposed) {
                      return;
                    }
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
                  '₹${item.salePrice.toStringAsFixed(2)} | സ്ടോക്ക്: ${item.currentStock.toStringAsFixed(2)} ${item.unit}',
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

  Widget _buildBillPanel({required bool isWindows}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'હાલનો બિલ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _setShopName,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.store, size: 16, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            _shopName ?? 'દુકાન નામ',
                            style: TextStyle(
                              fontSize: 12,
                              color: _shopName != null
                                  ? Colors.black
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 280,
                    child: CustomerSearchField(
                      controller: _customerController,
                      hintText: 'ગ્રાહક ઉમેરો',
                      onCustomerSelected: (customerId, customerName) {
                        ref
                            .read(billingTabsProvider.notifier)
                            .setSelectedCustomer(customerId, customerName);
                        setState(() {
                          _customerId = customerId;
                          _customerName = customerName;
                        });
                        _focusProductSearch();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (!isWindows)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _openAndroidProductBottomSheet,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'ઉત્પાદન ઉમેરો',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (ref.read(billingControllerProvider).billLines.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.shopping_cart_outlined,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'બિલ ખાલી છે',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isWindows
                        ? 'ડાબી બાજુથી ઉત્પાદન પસંદ કરો'
                        : 'ઉત્પાદન ઉમેરો પર ટૅપ કરી ઉત્પાદન પસંદ કરો',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: BillLinesPanel(
              checkStock: _hasEnoughStockForDraft,
            ),
          ),
        const Divider(height: 1),
        BillSummaryPanel(
          onClearBill: () {
            _clearCurrentBillDraft();
          },
        ),
      ],
    );
  }
}




enum _BillingDropdownType { none, product }
