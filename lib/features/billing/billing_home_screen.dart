import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart' as strings;
import '../../core/errors/error_logger.dart';
import '../../core/errors/error_types.dart';

import '../../shared/widgets/errors/error_dialog.dart';
import '../../shared/widgets/customer_search_field.dart';
import '../../shared/models/bill_item_model.dart';

import 'models/bill_line_item.dart';
import '../../routing/app_router.dart';
import 'billing_providers.dart';
import 'bill_history_providers.dart';
import '../../core/services/notification_service.dart';
import '../../features/inventory/inventory_providers.dart';
import '../../features/stock/stock_providers.dart';
import '../../features/settings/providers/auth_provider.dart';
import '../../data/providers.dart';
import '../../data/services/bill_service_provider.dart';
import '../../features/reports/reports_providers.dart';
import 'services/billing_print_service.dart';
import 'views/bill_summary_panel.dart';
import 'views/bill_lines_panel.dart';
import 'views/billing_product_panel.dart';
import 'controllers/billing_controller.dart';
import '../../core/auth/role_provider.dart';
import 'package:go_router/go_router.dart';

/// Simplified single-screen billing - Create bills and print them.
class BillingHomeScreen extends ConsumerStatefulWidget {
  const BillingHomeScreen({super.key});

  @override
  ConsumerState<BillingHomeScreen> createState() => _BillingHomeScreenState();
}

class _BillingHomeScreenState extends ConsumerState<BillingHomeScreen> {
  final _billBoundaryDesktopKey = GlobalKey();
  final _billBoundaryMobileKey = GlobalKey();
  final BillingPrintService _billingPrintService = BillingPrintService();
  final _customerController = TextEditingController();
  final _searchController = TextEditingController();
  final _productSearchFocusNode = FocusNode();
  
  String? _bannerMessage;
  String? _customerName;
  int? _customerId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(billingSearchProvider.notifier).state = '';
      ref.invalidate(billingItemsProvider);
    });
  }

  @override
  void dispose() {
    _customerController.dispose();
    _searchController.dispose();
    _productSearchFocusNode.dispose();
    super.dispose();
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

  double _toStockUnitQuantity(BillLineItem line) {
    final unit = line.item.unitType.trim().toLowerCase();
    if (unit.contains('કિલો') || unit == 'kg' || unit.contains('kilo')) {
      return line.qtyGrams / 1000.0;
    }
    if (unit.contains('ગ્રામ') || unit == 'g' || unit.contains('gram')) {
      return line.qtyGrams;
    }
    return line.qtyGrams;
  }

  List<BillItem> _buildBillItemsFromLines(List<BillLineItem> lines) {
    return lines.map((line) {
      final quantityInStockUnit = _toStockUnitQuantity(line);
      final double unitPrice = quantityInStockUnit > 0
          ? line.amount / quantityInStockUnit
          : 0.0;
      return BillItem(
        billId: 0, // Placeholder, updated in repository
        productId: line.item.id ?? 0,
        qty: quantityInStockUnit,
        amount: line.amount,
        sellPriceSnapshot: unitPrice,
        isReturned: false,
      );
    }).toList();
  }

  void _clearCurrentBillDraft() {
    setState(() {
      _customerName = null;
      _customerId = null;
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
    final billingState = ref.read(billingTabsProvider);
    final transactionType = billingState.activeDraft.transactionType;
    final selectedCustomerId =
        billingState.activeDraft.customerId ?? _customerId;

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
    final customerNameSnapshot = _normalizedCustomerName(_customerName);
    final productIds = linesSnapshot
        .map((l) => l.item.id)
        .whereType<int>()
        .toList();

    try {
      final billItems = _buildBillItemsFromLines(linesSnapshot);
      final billRepo = ref.read(billRepositoryProvider);
      final billId = await billRepo.createBill(
        customerId: customerIdSnapshot,
        customerNameSnapshot:
            (customerNameSnapshot == null || customerNameSnapshot.isEmpty)
            ? null
            : customerNameSnapshot,
        items: billItems,
        discountAmount: discountSnapshot,
        paidAmount: transactionType == 'udhaar'
            ? 0.0
            : (linesSnapshot.fold(0.0, (s, l) => s + l.amount) - discountSnapshot),
        paymentMode: transactionType,
        userId: null,
      );

      if (mounted) {
        _refreshBillingRelatedData();
      }

      try {
        await _updateStockAlerts(productIds);
      } catch (_) {}

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
      
      setState(() {
        _bannerMessage = 'સ્ટોક ઓછો/ખૂટ્યો: $names';
      });

      if (userRole != 'employee') {
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
    return 'admin';
  }

  String? _normalizedCustomerName(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  void _refreshBillingRelatedData() {
    ref.invalidate(reportRepositoryProvider);
    ref.invalidate(salesReportProvider);
    ref.invalidate(billingItemsProvider);
    ref.invalidate(itemListProvider);
    ref.invalidate(stockDashboardProductsProvider);
    ref.invalidate(todaysBillsProvider);
    ref.invalidate(billsProvider);
    ref.invalidate(billHistoryProvider);
    ref.invalidate(billHistoryPreviewProvider);
  }

  Future<double> _getLatestStockKg(int itemId) async {
    final repo = ref.read(itemRepositoryProvider);
    final latestItem = await repo.getById(itemId);
    return latestItem?.stockQty ?? 0.0;
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

  Future<void> _printBill() async {
    final messenger = ScaffoldMessenger.of(context);
    if (ref.read(billingControllerProvider).billLines.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('બિલ ખાલી છે. કૃપયા આઇટમ ઉમેરો.')),
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

    await _billingPrintService.attemptPrintSavedBill(
      messenger,
      ref,
      billId: billId,
      allowRetry: true,
      desktopKey: _billBoundaryDesktopKey,
      mobileKey: _billBoundaryMobileKey,
      isMounted: () => mounted,
      onClearDraft: _clearCurrentBillDraft,
    );
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
    context.go(AppRouter.roleSelection);
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
                context.push(AppRouter.returnsNew);
              } else if (value == 'replace') {
                context.push(AppRouter.returnsReplace);
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
        Expanded(
          flex: 2,
          child: BillingProductPanel(
            checkStock: _hasEnoughStockForDraft,
            productSearchFocusNode: _productSearchFocusNode,
            searchController: _searchController,
          ),
        ),
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
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: BillingProductPanel(
            checkStock: _hasEnoughStockForDraft,
            productSearchFocusNode: _productSearchFocusNode,
            searchController: _searchController,
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 3,
          child: RepaintBoundary(
            key: _billBoundaryMobileKey,
            child: _buildBillPanel(isWindows: false),
          ),
        ),
      ],
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
              const SizedBox(width: 12),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
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
                      _productSearchFocusNode.requestFocus();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (ref.watch(billingControllerProvider).billLines.isEmpty)
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
                    'ડાબી બાજુથી ઉત્પાદન પસંદ કરો',
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
