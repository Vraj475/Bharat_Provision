import 'dart:async';
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
import '../../core/database/database_helper.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/errors/error_dialogue.dart';
import '../../shared/widgets/errors/error_dialog.dart';
import '../../core/utils/currency_format.dart';
import '../../core/utils/weight_calculator.dart';
import '../../data/models/item.dart';
import '../../shared/models/customer_model.dart';
import '../../routing/app_router.dart';
import 'billing_providers.dart';
import '../../core/services/notification_service.dart';
import '../../features/inventory/inventory_providers.dart';
import '../../features/stock/stock_providers.dart';
import '../../features/settings/settings_providers.dart';
import '../../data/providers.dart';
import '../../data/repositories/bill_repository.dart';
import '../../data/services/bill_service_provider.dart';
import '../../data/repositories/udhaar_repository.dart';
import '../../features/reports/reports_providers.dart';

/// Simplified single-screen billing - Create bills and print them.
class BillingHomeScreen extends ConsumerStatefulWidget {
  const BillingHomeScreen({super.key});

  @override
  ConsumerState<BillingHomeScreen> createState() => _BillingHomeScreenState();
}

class _BillingHomeScreenState extends ConsumerState<BillingHomeScreen> {
  final _billBoundaryKey = GlobalKey();
  final BlueThermalPrinter _bluePrinter = BlueThermalPrinter.instance;
  final _customerController = TextEditingController();
  final _searchController = TextEditingController();
  final _customerFocusNode = FocusNode();
  final _productSearchFocusNode = FocusNode();
  final List<BillLineItem> _billLines = [];
  double _discount = 0;
  String? _bannerMessage;
  String? _customerName;
  String? _shopName;
  int? _customerId;
  List<Customer> _customerSuggestions = const [];
  bool _isSearchingCustomers = false;
  bool _isCustomerDropdownOpen = false;
  Timer? _customerSearchDebounce;
  int _customerSearchToken = 0;
  bool _lowStockPopupShown = false;
  int? _editingLineIndex;
  _DraftEditableField? _editingField;
  final _inlineEditController = TextEditingController();
  final _inlineEditFocusNode = FocusNode();
  final _weightEntryFocusNode = FocusNode();
  final _grandTotalEditController = TextEditingController();
  final _grandTotalEditFocusNode = FocusNode();
  bool _isEditingGrandTotal = false;
  bool _isGrandTotalAdjusted = false;

  @override
  void initState() {
    super.initState();
    _customerFocusNode.addListener(() {
      if (!mounted) return;
      if (!_customerFocusNode.hasFocus) {
        setState(() {
          _customerSuggestions = const [];
          _isSearchingCustomers = false;
          _isCustomerDropdownOpen = false;
        });
      }
    });
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
    _customerSearchDebounce?.cancel();
    _inlineEditController.dispose();
    _inlineEditFocusNode.dispose();
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
    if (!mounted) return;
    FocusScope.of(context).requestFocus(_productSearchFocusNode);
  }

  void _clearCustomerSelection({bool clearText = true}) {
    _customerSearchDebounce?.cancel();
    setState(() {
      _customerId = null;
      _customerSuggestions = const [];
      _isSearchingCustomers = false;
      _isCustomerDropdownOpen = false;
      if (clearText) {
        _customerName = null;
      }
    });
    if (clearText && _customerController.text.isNotEmpty) {
      _customerController.clear();
    }
  }

  bool _hasExactCustomerMatch(String typedName, List<Customer> customers) {
    final normalizedTyped = typedName.trim().toLowerCase();
    if (normalizedTyped.isEmpty) return false;
    return customers.any((customer) {
      return customer.nameGujarati.trim().toLowerCase() == normalizedTyped ||
          (customer.nameEnglish?.trim().toLowerCase() == normalizedTyped);
    });
  }

  void _onCustomerChanged(String value) {
    final typed = value.trim();
    _customerSearchDebounce?.cancel();

    if (typed.isEmpty) {
      _clearCustomerSelection(clearText: false);
      return;
    }

    setState(() {
      _customerName = typed;
      _customerId = null;
      _isSearchingCustomers = true;
      _isCustomerDropdownOpen = true;
    });

    final searchToken = ++_customerSearchToken;
    _customerSearchDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final repo = UdhaarRepository(DatabaseHelper.instance);
        final customers = await repo.findSimilarCustomers(typed);
        if (!mounted || searchToken != _customerSearchToken) return;

        final sortedCustomers = [...customers]
          ..sort((a, b) => a.nameGujarati.compareTo(b.nameGujarati));

        setState(() {
          _customerSuggestions = sortedCustomers.take(5).toList();
          _isSearchingCustomers = false;
          _isCustomerDropdownOpen = _shouldShowCustomerDropdown();
        });
      } catch (_) {
        if (!mounted || searchToken != _customerSearchToken) return;
        setState(() {
          _customerSuggestions = const [];
          _isSearchingCustomers = false;
          _isCustomerDropdownOpen = _shouldShowCustomerDropdown();
        });
      }
    });
  }

  void _selectCustomer(Customer customer) {
    _customerSearchDebounce?.cancel();
    setState(() {
      _customerId = customer.id;
      _customerName = customer.nameGujarati;
      _customerSuggestions = const [];
      _isSearchingCustomers = false;
      _isCustomerDropdownOpen = false;
    });
    _customerController.value = TextEditingValue(
      text: customer.nameGujarati,
      selection: TextSelection.collapsed(offset: customer.nameGujarati.length),
    );
    _focusProductSearch();
  }

  void _selectWalkInCustomer() {
    final typed = _customerController.text.trim();
    _customerSearchDebounce?.cancel();
    setState(() {
      _customerId = null;
      _customerName = typed.isEmpty ? null : typed;
      _customerSuggestions = const [];
      _isSearchingCustomers = false;
      _isCustomerDropdownOpen = false;
    });
    _focusProductSearch();
  }

  void _setCustomerName() async {
    final controller = TextEditingController(text: _customerName ?? '');
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ગ્રાહક નું નામ દાખલ કરો'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'ગ્રાહક નું નામ',
              hintText: 'નામ દાખલ કરો...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(strings.AppStrings.cancelButton),
            ),
            ElevatedButton(
              onPressed: () {
                if (!mounted) return;
                setState(
                  () => _customerName = controller.text.trim().isEmpty
                      ? null
                      : controller.text.trim(),
                );
                Navigator.of(ctx).pop();
              },
              child: const Text(strings.AppStrings.saveButton),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  void _setShopName() async {
    final controller = TextEditingController(text: _shopName ?? '');
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('દુકાનનું નામ દાખલ કરો'),
          content: TextField(
            controller: controller,
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
                final newShopName = controller.text.trim().isEmpty
                    ? null
                    : controller.text.trim();

                if (!mounted) return;
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

                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
              },
              child: const Text(strings.AppStrings.saveButton),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  double get _subtotal => _billLines.fold(0, (sum, line) => sum + line.amount);
  double get _total => _subtotal - _discount;

  Future<void> _saveBill() async {
    if (_billLines.isEmpty) {
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
    _clearInlineEditState();
    setState(() {
      _billLines.clear();
      _discount = 0;
      _isEditingGrandTotal = false;
      _isGrandTotalAdjusted = false;
      _customerName = null;
      _customerId = null;
      _customerSuggestions = const [];
      _isCustomerDropdownOpen = false;
      _customerController.clear();
    });
    ref.read(billingTabsProvider.notifier).clearActive();
  }

  Future<int?> _saveBillToDatabase({
    required bool showSuccessMessage,
    required bool clearDraft,
  }) async {
    final linesSnapshot = List<BillLineItem>.from(_billLines);
    final discountSnapshot = _discount;
    final customerIdSnapshot = _customerId;
    final customerNameSnapshot = _customerName?.trim();
    final productIds = linesSnapshot
        .map((l) => l.item.id)
        .whereType<int>()
        .toList();

    try {
      final billItems = _buildBillItemsFromLines(linesSnapshot);
      final billRepo = await ref.read(billRepositoryFutureProvider.future);
      final billId = await billRepo.createBill(
        customerId: customerIdSnapshot,
        customerNameSnapshot: (customerNameSnapshot == null || customerNameSnapshot.isEmpty)
            ? null
            : customerNameSnapshot,
        items: billItems,
        discountAmount: discountSnapshot,
        paidAmount: linesSnapshot.fold(0.0, (s, l) => s + l.amount) - discountSnapshot,
        paymentMode: 'cash',
        userId: null,
      );

      if (mounted) {
        ref.invalidate(reportRepositoryFutureProvider);
        ref.invalidate(salesReportProvider);
        ref.invalidate(billingItemsProvider);
        ref.invalidate(itemListProvider);
        ref.invalidate(stockDashboardProductsProvider);
        ref.invalidate(todaysBillsProvider);
      }

      await _updateStockAlerts(productIds);

      if (mounted && clearDraft) {
        _clearCurrentBillDraft();
      }

      if (mounted && showSuccessMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('બિલ સેવ થઈ ગયું')),
        );
      }

      return billId;
    } catch (error, stack) {
      final appError = AppError(
        code: 'DB_003',
        category: ErrorCategory.database,
        technicalMessage: error.toString(),
        userMessage: 'બિલ સેવ કરવામાં નિષ્ફળ. કોઈ ડેટા બદલાયો નથી. ફરી પ્રયાસ કરો.',
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

    for (var i = 0; i < _billLines.length; i++) {
      final line = _billLines[i];
      if (line.item.id != itemId) continue;
      if (excludeLineIndex != null && i == excludeLineIndex) continue;
      existingQtyKg += line.qtyGrams / 1000.0;
    }

    final requestedQtyKg = newQtyGrams / 1000.0;
    return (existingQtyKg + requestedQtyKg) <= latestStockKg;
  }

  void _addProductToBill(Item item) async {
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

    double amountPaid = item.salePrice;
    double weightGrams = 1000;
    String mode = 'weight';
    bool itemAdded = false;
    bool focusScheduled = false;
    final weightKgController = TextEditingController();

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            double? calculatedWeight;
            double? calculatedAmount;

            Future<void> addCurrentItem() async {
              if (item.id == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('પ્રોડક્ટ પસંદ કરો')),
                );
                _focusProductSearch();
                return;
              }

              double finalAmount;
              double finalQty;

              if (mode == 'amount') {
                finalQty = WeightCalculator.calculateWeightFromAmount(
                  amountPaid: amountPaid,
                  sellPricePerKg: item.salePrice,
                );
                finalAmount = amountPaid;
              } else {
                final rawKg = weightKgController.text.trim();
                final parsedKg = double.tryParse(rawKg);
                if (rawKg.isEmpty || parsedKg == null || parsedKg <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('વજન દાખલ કરો')),
                  );
                  if (!mounted || !ctx.mounted) return;
                  FocusScope.of(ctx).requestFocus(_weightEntryFocusNode);
                  return;
                }
                final grams = parsedKg * 1000.0;
                finalAmount = WeightCalculator.calculateAmountFromWeight(
                  weightGrams: grams,
                  sellPricePerKg: item.salePrice,
                );
                finalQty = grams;
              }

              final itemId = item.id;
              if (itemId != null) {
                final hasStock = await _hasEnoughStockForDraft(
                  itemId: itemId,
                  newQtyGrams: finalQty,
                );
                if (!mounted || !ctx.mounted) return;
                if (!hasStock) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('સ્ટોક અવેલેબલ નથી કૃપા કરી ખરીદી ની યાદી માં એડ કરો'),
                    ),
                  );
                  FocusScope.of(ctx).requestFocus(_weightEntryFocusNode);
                  return;
                }
              }

              _billLines.add(
                BillLineItem(
                  item: item,
                  qtyGrams: finalQty,
                  amount: finalAmount,
                ),
              );
              weightKgController.clear();
              itemAdded = true;
              Navigator.of(ctx).pop();
            }

            if (mode == 'amount') {
              calculatedWeight = WeightCalculator.calculateWeightFromAmount(
                amountPaid: amountPaid,
                sellPricePerKg: item.salePrice,
              );
            } else {
              final parsedKg = double.tryParse(weightKgController.text.trim());
              if (parsedKg != null && parsedKg > 0) {
                weightGrams = parsedKg * 1000.0;
              }
              calculatedAmount = WeightCalculator.calculateAmountFromWeight(
                weightGrams: weightGrams,
                sellPricePerKg: item.salePrice,
              );
            }

            if (mode == 'weight' && !focusScheduled) {
              focusScheduled = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !ctx.mounted) return;
                _weightEntryFocusNode.requestFocus();
              });
            }

            return AlertDialog(
              title: Text(item.nameGu),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.6,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('₹ રૂપિયાથી'),
                            selected: mode == 'amount',
                            onSelected: (_) =>
                                setDialogState(() => mode = 'amount'),
                          ),
                          ChoiceChip(
                            label: const Text('⚖ વજનથી'),
                            selected: mode == 'weight',
                            onSelected: (_) {
                              setDialogState(() => mode = 'weight');
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted || !ctx.mounted) return;
                                _weightEntryFocusNode.requestFocus();
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (mode == 'amount') ...[
                        TextField(
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: '₹ રકમ દાખલ કરો',
                          ),
                          onChanged: (v) {
                            final parsed = double.tryParse(v);
                            if (parsed != null) {
                              setDialogState(() => amountPaid = parsed);
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        if (calculatedWeight != null)
                          Text(
                            'આપો: ${WeightCalculator.formatWeight(calculatedWeight)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                              fontSize: 16,
                            ),
                          ),
                      ] else ...[
                        Focus(
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent &&
                                _weightEntryFocusNode.hasFocus &&
                                (event.logicalKey == LogicalKeyboardKey.enter ||
                                    event.logicalKey ==
                                        LogicalKeyboardKey.numpadEnter)) {
                              addCurrentItem();
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: TextField(
                            controller: weightKgController,
                            focusNode: _weightEntryFocusNode,
                            autofocus: false,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,3}'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'વજન (કિલો)',
                              hintText: 'કિલોમાં દાખલ કરો જેમ કે 1.500',
                            ),
                            onChanged: (_) {
                              setDialogState(() {});
                            },
                            onSubmitted: (_) => addCurrentItem(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (calculatedAmount != null)
                          Text(
                            'રકમ: ${formatCurrency(calculatedAmount)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                              fontSize: 16,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(strings.AppStrings.cancelButton),
                ),
                ElevatedButton(
                  onPressed: () {
                    addCurrentItem();
                  },
                  child: const Text(strings.AppStrings.addButton),
                ),
              ],
            );
          },
        );
      },
    );

    weightKgController.dispose();

    // Trigger parent widget rebuild after dialog closes
    if (itemAdded && mounted) {
      setState(() {});
      _focusProductSearch();
    }
  }

  void _clearInlineEditState() {
    _inlineEditFocusNode.unfocus();
    _inlineEditController.clear();
    _editingLineIndex = null;
    _editingField = null;
  }

  void _startGrandTotalEdit() {
    if (_billLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('પ્રથમ આઇટમ ઉમેરો')),
      );
      return;
    }

    _commitInlineEdit();
    setState(() {
      _isEditingGrandTotal = true;
      _grandTotalEditController.text = _total.toStringAsFixed(2);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _grandTotalEditFocusNode.requestFocus();
      _grandTotalEditController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _grandTotalEditController.text.length,
      );
    });
  }

  void _commitGrandTotalEdit() {
    if (!_isEditingGrandTotal) return;

    final raw = _grandTotalEditController.text.trim();
    final parsed = double.tryParse(raw);
    if (raw.isEmpty || parsed == null || parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('કુલ રકમ સાચી નથી')),
      );
      setState(() {
        _isEditingGrandTotal = false;
      });
      return;
    }

    if (_billLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('પ્રથમ આઇટમ ઉમેરો')),
      );
      setState(() {
        _isEditingGrandTotal = false;
      });
      return;
    }

    final oldSubtotal = _subtotal;
    final targetSubtotal = parsed + _discount;

    if (oldSubtotal <= 0 || targetSubtotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('કુલ રકમ સાચી નથી')),
      );
      setState(() {
        _isEditingGrandTotal = false;
      });
      return;
    }

    final updated = <BillLineItem>[];
    for (final line in _billLines) {
      final proportion = line.amount / oldSubtotal;
      final redistributedAmount = targetSubtotal * proportion;
      final sellPrice = _lineSellPricePerKg(line);
      if (sellPrice <= 0) {
        updated.add(line);
        continue;
      }
      final redistributedQty = (redistributedAmount / sellPrice) * 1000.0;
      updated.add(
        line.copyWith(
          amount: redistributedAmount,
          qtyGrams: redistributedQty,
        ),
      );
    }

    setState(() {
      _billLines
        ..clear()
        ..addAll(updated);
      _isEditingGrandTotal = false;
      _isGrandTotalAdjusted = true;
    });
  }

  double _lineSellPricePerKg(BillLineItem line) {
    if (line.qtyGrams <= 0) return line.item.salePrice;
    return (line.amount * 1000.0) / line.qtyGrams;
  }

  String _kgEditableText(double qtyGrams) {
    return (qtyGrams / 1000.0).toStringAsFixed(3);
  }

  void _startInlineEdit(int index, _DraftEditableField field) {
    if (index < 0 || index >= _billLines.length) return;

    if (_isEditingGrandTotal) {
      _commitGrandTotalEdit();
    }

    if (_editingLineIndex != null) {
      _commitInlineEdit();
    }

    final line = _billLines[index];
    final initialValue = switch (field) {
      _DraftEditableField.quantity => _kgEditableText(line.qtyGrams),
      _DraftEditableField.price => _lineSellPricePerKg(line).toStringAsFixed(2),
      _DraftEditableField.amount => line.amount.toStringAsFixed(2),
    };

    setState(() {
      _editingLineIndex = index;
      _editingField = field;
      _inlineEditController.value = TextEditingValue(
        text: initialValue,
        selection: TextSelection.collapsed(offset: initialValue.length),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _inlineEditFocusNode.requestFocus();
      _inlineEditController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _inlineEditController.text.length,
      );
    });
  }

  Future<void> _commitInlineEdit() async {
    final editingIndex = _editingLineIndex;
    final editingField = _editingField;
    final controller = _inlineEditController;

    if (editingIndex == null ||
        editingField == null ||
        editingIndex < 0 ||
        editingIndex >= _billLines.length) {
      _clearInlineEditState();
      return;
    }

    final line = _billLines[editingIndex];
    final raw = controller.text.trim();
    final parsed = double.tryParse(raw);

    BillLineItem updatedLine = line;
    if (editingField == _DraftEditableField.quantity) {
      if (raw.isEmpty || parsed == null || parsed <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('વજન શૂન્ય ન હોઈ શકે')),
        );
        setState(_clearInlineEditState);
        return;
      }

      final newQtyGrams = parsed * 1000.0;
      final itemId = line.item.id;
      if (itemId != null) {
        final hasStock = await _hasEnoughStockForDraft(
          itemId: itemId,
          newQtyGrams: newQtyGrams,
          excludeLineIndex: editingIndex,
        );
        if (!mounted) return;
        if (!hasStock) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('સ્ટોક અવેલેબલ નથી કૃપા કરી ખરીદી ની યાદી માં એડ કરો'),
            ),
          );
          setState(_clearInlineEditState);
          return;
        }
      }

      final existingSellPrice = _lineSellPricePerKg(line);
      final newAmount = (newQtyGrams / 1000.0) * existingSellPrice;
      updatedLine = line.copyWith(qtyGrams: newQtyGrams, amount: newAmount);
    } else if (editingField == _DraftEditableField.price) {
      if (raw.isEmpty || parsed == null || parsed <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('કિંમત શૂન્ય ન હોઈ શકે')),
        );
        setState(_clearInlineEditState);
        return;
      }

      final newAmount = (line.qtyGrams / 1000.0) * parsed;
      updatedLine = line.copyWith(amount: newAmount);
    } else {
      if (raw.isEmpty || parsed == null || parsed <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('રકમ શૂન્ય ન હોઈ શકે')),
        );
        setState(_clearInlineEditState);
        return;
      }

      final sellPrice = _lineSellPricePerKg(line);
      if (sellPrice <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('કિંમત શૂન્ય ન હોઈ શકે')),
        );
        setState(_clearInlineEditState);
        return;
      }

      final newQtyGrams = (parsed / sellPrice) * 1000.0;
      updatedLine = line.copyWith(qtyGrams: newQtyGrams, amount: parsed);
    }

    setState(() {
      _billLines[editingIndex] = updatedLine;
      _clearInlineEditState();
    });
  }

  void _deleteLineWithUndo(int index) {
    if (index < 0 || index >= _billLines.length) return;

    _commitInlineEdit();
    final removedLine = _billLines[index];

    setState(() {
      _billLines.removeAt(index);
      if (_editingLineIndex != null) {
        if (_editingLineIndex == index) {
          _clearInlineEditState();
        } else if (_editingLineIndex! > index) {
          _editingLineIndex = _editingLineIndex! - 1;
        }
      }
    });

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('આઇટમ કાઢી નાખવી?'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (!mounted) return;
            setState(() {
              final insertIndex = index.clamp(0, _billLines.length);
              _billLines.insert(insertIndex, removedLine);
            });
          },
        ),
      ),
    );
  }

  Widget _buildEditableValueChip({
    required bool isEditing,
    required String value,
    required VoidCallback onTap,
    required ValueChanged<String> onSubmitted,
    required TextInputType keyboardType,
    String? prefixText,
  }) {
    if (isEditing) {
      return SizedBox(
        width: 106,
        child: TextField(
          controller: _inlineEditController,
          focusNode: _inlineEditFocusNode,
          keyboardType: keyboardType,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          onSubmitted: onSubmitted,
          onTapOutside: (_) => _commitInlineEdit(),
          decoration: InputDecoration(
            isDense: true,
            prefixText: prefixText,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 110),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: Colors.grey.shade500,
            color: Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildBillLineTile(BillLineItem line, int index) {
    final isEditingRow = _editingLineIndex == index;
    final isEditingQty = isEditingRow && _editingField == _DraftEditableField.quantity;
    final isEditingPrice = isEditingRow && _editingField == _DraftEditableField.price;
    final isEditingAmount = isEditingRow && _editingField == _DraftEditableField.amount;
    final qtyDisplay = '${_kgEditableText(line.qtyGrams)} કિલો';
    final priceDisplay = '₹${_lineSellPricePerKg(line).toStringAsFixed(2)}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isEditingRow ? AppColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.item.nameGu,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildEditableValueChip(
                      isEditing: isEditingQty,
                      value: qtyDisplay,
                      onTap: () => _startInlineEdit(index, _DraftEditableField.quantity),
                      onSubmitted: (_) => _commitInlineEdit(),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    _buildEditableValueChip(
                      isEditing: isEditingPrice,
                      value: priceDisplay,
                      onTap: () => _startInlineEdit(index, _DraftEditableField.price),
                      onSubmitted: (_) => _commitInlineEdit(),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      prefixText: isEditingPrice ? '₹' : null,
                    ),
                    _buildEditableValueChip(
                      isEditing: isEditingAmount,
                      value: formatCurrency(line.amount),
                      onTap: () => _startInlineEdit(index, _DraftEditableField.amount),
                      onSubmitted: (_) => _commitInlineEdit(),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isEditingRow)
            SizedBox(
              width: 36,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                icon: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                tooltip: 'સેવ કરો',
                onPressed: () {
                  _commitInlineEdit();
                },
              ),
            ),
          SizedBox(
            width: 36,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              tooltip: 'આઇટમ કાઢો',
              onPressed: () => _deleteLineWithUndo(index),
            ),
          ),
        ],
      ),
    );
  }

  void _setDiscount() async {
    final controller = TextEditingController(
      text: _discount.toStringAsFixed(2),
    );
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ડિસ્કાઉન્ટ સેટ કરો'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '₹ રકમ'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(strings.AppStrings.cancelButton),
            ),
            ElevatedButton(
              onPressed: () {
                if (!mounted) return;
                setState(() => _discount = double.tryParse(controller.text) ?? 0);
                Navigator.of(ctx).pop();
              },
              child: const Text(strings.AppStrings.saveButton),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _printBill() async {
    if (_billLines.isEmpty) {
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
    final boundary = _billBoundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('બિલ પ્રિન્ટ થઈ ગયું.')),
      );
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
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Scaffold(
      appBar: AppBar(
        title: const Text(strings.AppStrings.billingTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveBill,
            tooltip: 'બિલ સાચવો',
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _printBill,
            tooltip: 'બિલ છાપો',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'returns') {
                Navigator.of(context).pushNamed(AppRouter.returnsNew);
              } else if (value == 'replace') {
                Navigator.of(context).pushNamed(AppRouter.returnsReplace);
              } else if (value == 'history') {
                Navigator.of(context).pushNamed(AppRouter.returnsHistory);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'returns', child: Text('પાછું આપવું')),
              const PopupMenuItem(value: 'replace', child: Text('બદલવું')),
              const PopupMenuItem(
                value: 'history',
                child: Text('પાછું આપવાનો ઇતિહાસ'),
              ),
            ],
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
            child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
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
            key: _billBoundaryKey,
            child: _buildBillPanel(),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Expanded(flex: 2, child: _buildProductPanel()),
        const Divider(height: 1),
        Expanded(
          flex: 3,
          child: RepaintBoundary(
            key: _billBoundaryKey,
            child: _buildBillPanel(),
          ),
        ),
      ],
    );
  }

  Widget _buildProductPanel() {
    final state = ref.watch(billingItemsProvider);
    return Stack(
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
                  TextField(
                    controller: _customerController,
                    focusNode: _customerFocusNode,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'ગ્રાહકનું નામ',
                      prefixIcon: const Icon(Icons.person),
                      suffixIcon: _customerController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear customer',
                              onPressed: () {
                                _clearCustomerSelection();
                                _focusProductSearch();
                              },
                              icon: const Icon(Icons.close),
                            ),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: _onCustomerChanged,
                    onSubmitted: (_) => _focusProductSearch(),
                    onEditingComplete: _focusProductSearch,
                  ),
                  const SizedBox(height: 8),
                  IgnorePointer(
                    ignoring: _isCustomerDropdownOpen,
                    child: TextField(
                      controller: _searchController,
                      focusNode: _productSearchFocusNode,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: strings.AppStrings.searchHintProducts,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        ref.read(billingSearchProvider.notifier).state = value;
                      },
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
                          ref.read(billingSearchProvider.notifier).state = '';
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                  return ListTile(
                    leading: const Icon(Icons.inventory_2),
                    title: Text(item.nameGu),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('₹${item.salePrice.toStringAsFixed(2)}'),
                        Text(
                          'સ્ટોક: ${item.currentStock.toStringAsFixed(2)} ${item.unit}',
                          style: TextStyle(
                            color: item.isLowStock ? Colors.red : Colors.grey,
                            fontWeight: item.isLowStock
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    trailing: item.isLowStock
                        ? const Icon(Icons.warning_amber, color: Colors.red)
                        : null,
                    onTap: () => _addProductToBill(item),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) {
              final appError = e is AppError
                  ? e
                  : ErrorHandler.handle(e, st, context: 'BillingHomeScreen');
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
        if (_showCustomerDropdown)
          Positioned(
            left: 8,
            right: 8,
            top: 116,
            child: Material(
              elevation: 10,
              borderRadius: BorderRadius.circular(14),
              color: Colors.white,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: _customerDropdownChildren(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  bool _shouldShowCustomerDropdown() {
    final typed = _customerController.text.trim();
    if (typed.isEmpty) return false;
    return (_customerFocusNode.hasFocus || _isSearchingCustomers) &&
        (_isSearchingCustomers ||
            _customerSuggestions.isNotEmpty ||
            !_hasExactCustomerMatch(typed, _customerSuggestions));
  }

  bool get _showCustomerDropdown {
    return _isCustomerDropdownOpen;
  }

  List<Widget> _customerDropdownChildren() {
    final typed = _customerController.text.trim();
    final hasExactMatch = _hasExactCustomerMatch(typed, _customerSuggestions);

    final rows = <Widget>[];
    for (final customer in _customerSuggestions) {
      rows.add(
        InkWell(
          onTap: () => _selectCustomer(customer),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.nameGujarati,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (customer.totalOutstanding > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'ઉધાર બાકી: ${formatCurrency(customer.totalOutstanding)}',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else if ((customer.nameEnglish ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    customer.nameEnglish!,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (!hasExactMatch) {
      if (rows.isNotEmpty) {
        rows.add(const Divider(height: 1));
      }
      rows.add(
        InkWell(
          onTap: _selectWalkInCustomer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(
                    text: 'નવા ગ્રાહક તરીકે ઉમેરો',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (typed.isNotEmpty)
                    TextSpan(
                      text: ' - $typed',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return rows;
  }

  Widget _buildBillPanel() {
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
                  GestureDetector(
                    onTap: _setCustomerName,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            _customerName ?? 'ગ્રાહક ઉમેરો',
                            style: TextStyle(
                              fontSize: 12,
                              color: _customerName != null
                                  ? Colors.black
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (_billLines.isEmpty)
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
                  const Text(
                    'ડાબી બાજુથી ઉત્પાદન પસંદ કરો',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _billLines.length,
              itemBuilder: (ctx, i) {
                final line = _billLines[i];
                return _buildBillLineTile(line, i);
              },
            ),
          ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('કુલ:'),
                  Text(
                    formatCurrency(_subtotal),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _setDiscount,
                    child: const Text(
                      'ડિસ્કાઉન્ટ:',
                      style: TextStyle(decoration: TextDecoration.underline),
                    ),
                  ),
                  Text(
                    '-${formatCurrency(_discount)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'દેય:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isGrandTotalAdjusted)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            'સુધારેલ કુલ',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (_isEditingGrandTotal)
                        SizedBox(
                          width: 130,
                          child: TextField(
                            controller: _grandTotalEditController,
                            focusNode: _grandTotalEditFocusNode,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*'),
                              ),
                            ],
                            onSubmitted: (_) => _commitGrandTotalEdit(),
                            onTapOutside: (_) => _commitGrandTotalEdit(),
                            decoration: const InputDecoration(
                              isDense: true,
                              prefixText: '₹',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                          ),
                        )
                      else
                        InkWell(
                          onTap: _startGrandTotalEdit,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              formatCurrency(_total),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Colors.green.shade700,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ),
                      if (_isEditingGrandTotal)
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          onPressed: _commitGrandTotalEdit,
                          tooltip: 'કુલ સેવ કરો',
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.clear),
                label: const Text('બિલ ક્લીયર કરો'),
                onPressed: _billLines.isEmpty
                    ? null
                    : () {
                        _commitInlineEdit();
                        setState(() {
                          _billLines.clear();
                          _discount = 0;
                          _isEditingGrandTotal = false;
                          _isGrandTotalAdjusted = false;
                          _customerName = null;
                        });
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Simple bill line item model.
class BillLineItem {
  final Item item;
  final double qtyGrams;
  final double amount;

  BillLineItem({
    required this.item,
    required this.qtyGrams,
    required this.amount,
  });

  BillLineItem copyWith({
    Item? item,
    double? qtyGrams,
    double? amount,
  }) {
    return BillLineItem(
      item: item ?? this.item,
      qtyGrams: qtyGrams ?? this.qtyGrams,
      amount: amount ?? this.amount,
    );
  }
}

enum _DraftEditableField { quantity, price, amount }
