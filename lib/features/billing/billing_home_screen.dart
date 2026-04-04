import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart' as strings;
import '../../core/errors/error_handler.dart';
import '../../core/errors/error_types.dart';
import '../../core/database/database_helper.dart';
import '../../shared/widgets/errors/error_dialogue.dart';
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
  }

  void _setShopName() async {
    final controller = TextEditingController(text: _shopName ?? '');
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
  }

  double get _subtotal => _billLines.fold(0, (sum, line) => sum + line.amount);
  double get _total => _subtotal - _discount;

  Future<void> _saveBill() async {
    // Save bill logic (not shown here)
    // After saving, check stock alerts for all products in bill
    final productIds = _billLines
        .map((l) => l.item.id)
        .whereType<int>()
        .toList();
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
    String mode = 'amount';
    bool itemAdded = false;

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            double? calculatedWeight;
            double? calculatedAmount;

            if (mode == 'amount') {
              calculatedWeight = WeightCalculator.calculateWeightFromAmount(
                amountPaid: amountPaid,
                sellPricePerKg: item.salePrice,
              );
            } else {
              calculatedAmount = WeightCalculator.calculateAmountFromWeight(
                weightGrams: weightGrams,
                sellPricePerKg: item.salePrice,
              );
            }

            return AlertDialog(
              title: Text(item.nameGu),
              content: Column(
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
                        onSelected: (_) =>
                            setDialogState(() => mode = 'weight'),
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
                    TextField(
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'ગ્રામમાં વજન દાખલ કરો',
                      ),
                      onChanged: (v) {
                        final parsed = double.tryParse(v);
                        if (parsed != null) {
                          setDialogState(() => weightGrams = parsed);
                        }
                      },
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(strings.AppStrings.cancelButton),
                ),
                ElevatedButton(
                  onPressed: () {
                    double finalAmount, finalQty;
                    if (mode == 'amount') {
                      finalQty = WeightCalculator.calculateWeightFromAmount(
                        amountPaid: amountPaid,
                        sellPricePerKg: item.salePrice,
                      );
                      finalAmount = amountPaid;
                    } else {
                      finalAmount = WeightCalculator.calculateAmountFromWeight(
                        weightGrams: weightGrams,
                        sellPricePerKg: item.salePrice,
                      );
                      finalQty = weightGrams;
                    }
                    _billLines.add(
                      BillLineItem(
                        item: item,
                        qtyGrams: finalQty,
                        amount: finalAmount,
                      ),
                    );
                    itemAdded = true;
                    Navigator.of(ctx).pop();
                  },
                  child: const Text(strings.AppStrings.addButton),
                ),
              ],
            );
          },
        );
      },
    );

    // Trigger parent widget rebuild after dialog closes
    if (itemAdded && mounted) {
      setState(() {});
    }
  }

  void _removeLine(int index) {
    setState(() => _billLines.removeAt(index));
  }

  void _setDiscount() async {
    final controller = TextEditingController(
      text: _discount.toStringAsFixed(2),
    );
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
              setState(() => _discount = double.tryParse(controller.text) ?? 0);
              Navigator.of(ctx).pop();
            },
            child: const Text(strings.AppStrings.saveButton),
          ),
        ],
      ),
    );
  }

  Future<void> _printBill() async {
    if (_billLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('બિલ ખાલી છે. કૃપया આઇટમ ઉમેરો.')),
      );
      return;
    }
    try {
      final connected = await _bluePrinter.isConnected ?? false;
      if (!connected) {
        if (!mounted) return;
        ErrorDialogue.showSnackbar(
          context,
          message: 'પ્રિન્ટર કનેક્ટ નથી. Bluetooth તપાસો.',
          code: 'PRINT_001',
          type: ErrorDialogueType.error,
        );
        return;
      }

      final billImageBytes = await _captureBillImageBytes();
      if (billImageBytes == null) {
        throw StateError('PRINT_003');
      }

      await _bluePrinter.writeBytes(billImageBytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('બિલ સફળતાથી પ્રિન્ટ થયું')),
      );

      // Save bill after successful print dispatch.
      await _saveBillAfterPrint();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ભૂલ: $e')));
    }
  }

  Future<Uint8List?> _captureBillImageBytes() async {
    final boundary = _billBoundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _saveBillAfterPrint() async {
    try {
      // Convert bill line items to BillItemInput format
      final billItems = _billLines.map((line) {
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

      // Save bill to database
      final billRepo = await ref.read(billRepositoryFutureProvider.future);
      final billId = await billRepo.createBill(
        customerId: _customerId,
        items: billItems,
        discountAmount: _discount,
        paidAmount: _total,
        paymentMode: 'cash',
        userId: null,
      );

      // Invalidate reports providers to refresh data
      if (mounted) {
        ref.invalidate(reportRepositoryFutureProvider);
        ref.invalidate(salesReportProvider);
        ref.invalidate(billingItemsProvider);
        ref.invalidate(itemListProvider);
      }

      // Clear bill after successful save
      setState(() {
        _billLines.clear();
        _discount = 0;
        _customerName = null;
        _customerId = null;
        _customerSuggestions = const [];
        _isCustomerDropdownOpen = false;
        _customerController.clear();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'બિલ #$billId સફળતાથી બચાવવામાં આવ્યો! રિપોર્ટમાં અપડેટ થયો.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('બિલ બચાવવામાં ભૂલ: $e')));
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
                return Dismissible(
                  key: Key(i.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _removeLine(i),
                  child: ListTile(
                    title: Text(line.item.nameGu),
                    subtitle: Text(
                      WeightCalculator.formatWeight(line.qtyGrams),
                    ),
                    trailing: Text(
                      formatCurrency(line.amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
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
                  Text(
                    formatCurrency(_total),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.green,
                    ),
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
                        setState(() {
                          _billLines.clear();
                          _discount = 0;
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
}
