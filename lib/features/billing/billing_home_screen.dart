import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart' as strings;
import '../../core/errors/error_logger.dart';
import '../../core/errors/error_types.dart';
import '../../core/shortcuts/app_intents.dart';
import '../../core/shortcuts/app_shortcuts.dart';

import '../../shared/widgets/errors/error_dialog.dart';
import '../../shared/widgets/customer_search_field.dart';
import '../../shared/models/bill_item_model.dart';

import 'models/bill_line_item.dart';
import '../../routing/app_router.dart';
import '../../shared/models/customer_model.dart';
import '../khata/khata_providers.dart';
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
import 'views/mobile_express_billing_view.dart';
import 'controllers/billing_controller.dart';
import '../../core/auth/role_provider.dart';
import 'views/dialogs/discount_dialog.dart';
import 'views/dialogs/grand_total_dialog.dart';
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
  final _billLinesKey = GlobalKey<BillLinesPanelState>();
  final _billSummaryKey = GlobalKey<BillSummaryPanelState>();
  final BillingPrintService _billingPrintService = BillingPrintService();
  final _customerController = TextEditingController();
  final _searchController = TextEditingController();
  final _productSearchFocusNode = FocusNode();
  final _customerSearchFocusNode = FocusNode();
  
  String? _bannerMessage;
  String? _customerName;
  int? _customerId;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalHardwareKey);
    _customerController.addListener(() {
      final text = _customerController.text.trim();
      _customerName = text.isEmpty ? null : text;
      if (text.isEmpty) {
        _customerId = null;
        ref.read(billingTabsProvider.notifier).setCustomerForActive(
              customerId: null,
              customerName: null,
            );
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(billingSearchProvider.notifier).state = '';
      ref.invalidate(billingItemsProvider);
      _focusProductSearch();
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalHardwareKey);
    _customerController.dispose();
    _searchController.dispose();
    _productSearchFocusNode.dispose();
    _customerSearchFocusNode.dispose();
    super.dispose();
  }

  bool _handleGlobalHardwareKey(KeyEvent event) {
    if (!mounted) return false;
    if (event is! KeyDownEvent) {
      return false;
    }

    final isCtrlOrCmd = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final key = event.logicalKey;

    // Check if an editable text field has active focus
    final primaryFocus = FocusManager.instance.primaryFocus;
    final isFocusInTextField = _productSearchFocusNode.hasFocus ||
        _customerSearchFocusNode.hasFocus ||
        (primaryFocus != null && primaryFocus.context?.widget is EditableText);

    // ── Save Bill Shortcut: Ctrl + Enter / Ctrl + NumpadEnter ──
    if (isCtrlOrCmd &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter)) {
      _handleSaveBillShortcut();
      return true;
    }

    // ── Product Search Shortcut: Ctrl + F ──
    if (isCtrlOrCmd && key == LogicalKeyboardKey.keyF) {
      _billLinesKey.currentState?.commitCurrentEdit();
      _focusProductSearch();
      return true;
    }

    // ── Escape Key: Return to Product Search ──
    if (key == LogicalKeyboardKey.escape && !isCtrlOrCmd) {
      _handleEscape();
      return true;
    }

    // ── Up / Down arrow navigation between products when not editing text ──
    if (!isFocusInTextField && !isCtrlOrCmd) {
      if (key == LogicalKeyboardKey.arrowDown) {
        _billLinesKey.currentState?.selectNextRow();
        return true;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        _billLinesKey.currentState?.selectPreviousRow();
        return true;
      }
    }

    return false;
  }

  void _focusProductSearch() {
    if (!mounted) return;
    _productSearchFocusNode.requestFocus();
    _searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchController.text.length,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _productSearchFocusNode.requestFocus();
    });
  }

  void _focusFirstItemWeight() {
    if (!mounted) return;
    final lines = ref.read(billingControllerProvider).billLines;
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('કાર્ટ ખાલી છે. પહેલા ઉત્પાદન ઉમેરો (Ctrl+F).'),
          duration: Duration(seconds: 2),
        ),
      );
      _focusProductSearch();
      return;
    }
    _billLinesKey.currentState?.startEditingFirstItemWeight();
  }

  void _editDiscount() {
    if (!mounted) return;
    if (_billSummaryKey.currentState != null) {
      _billSummaryKey.currentState?.startDiscountEdit();
    } else {
      _openMobileDiscountDialog();
    }
  }

  void _editGrandTotal() {
    if (!mounted) return;
    if (_billSummaryKey.currentState != null) {
      _billSummaryKey.currentState?.startGrandTotalEdit();
    } else {
      _openMobileGrandTotalDialog();
    }
  }

  Future<void> _openMobileDiscountDialog() async {
    final currentDiscount = ref.read(billingControllerProvider).discount;
    final result = await DiscountDialog.show(
      context,
      currentDiscount,
    );
    if (result != null && mounted) {
      ref.read(billingControllerProvider.notifier).setDiscount(result);
    }
  }

  Future<void> _openMobileGrandTotalDialog() async {
    final total = ref.read(billingControllerProvider).total;
    final newTotal = await GrandTotalDialog.show(context, total);
    if (newTotal != null && mounted) {
      ref.read(billingControllerProvider.notifier).commitGrandTotalEdit(newTotal);
    }
  }

  void _clearBillFromShortcut() {
    if (!mounted) return;
    final lines = ref.read(billingControllerProvider).billLines;
    final hasCustomer = _customerId != null ||
        (_customerName != null && _customerName!.trim().isNotEmpty);
    if (lines.isEmpty && !hasCustomer) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('બિલ પહેલેથી જ ખાલી છે.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    _clearCurrentBillDraft();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('બિલ ક્લીયર થઈ ગયું.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _focusCustomerSearch() {
    if (!mounted) return;
    _customerSearchFocusNode.requestFocus();
    _customerController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _customerController.text.length,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _customerSearchFocusNode.requestFocus();
    });
  }

  void _togglePaymentMode() {
    final current = ref.read(billingTabsProvider).activeDraft.transactionType;
    final String nextMode;
    final String message;
    if (current == 'khata') {
      nextMode = 'cash';
      message = 'રોકડ (Cash) મોડ પસંદ થયો (F4).';
    } else if (current == 'cash') {
      nextMode = 'online';
      message = 'ઓનલાઇન (Online) મોડ પસંદ થયો (F4).';
    } else {
      nextMode = 'khata';
      message = 'ઉધાર (ખાતા) મોડ પસંદ થયો (F4). ગ્રાહકનું નામ ઉમેરો (F2).';
    }
    ref.read(billingTabsProvider.notifier).setTransactionTypeForActive(nextMode);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
    if (nextMode == 'khata') {
      final name = _normalizedCustomerName(_customerName);
      if (name == null || name.isEmpty) {
        _focusCustomerSearch();
      }
    }
  }

  void _setUdhaarMode() {
    ref.read(billingTabsProvider.notifier).setTransactionTypeForActive('khata');
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('ઉધાર (ખાતા) મોડ પસંદ થયો. ગ્રાહકનું નામ ઉમેરો (F2).'),
        duration: Duration(seconds: 2),
      ),
    );
    final name = _normalizedCustomerName(_customerName);
    if (name == null || name.isEmpty) {
      _focusCustomerSearch();
    }
  }

  void _setCashMode() {
    ref.read(billingTabsProvider.notifier).setTransactionTypeForActive('cash');
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('રોકડ (Cash) મોડ પસંદ થયો.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleEscape() {
    _billLinesKey.currentState?.deselectRow();
    _focusProductSearch();
  }

  void _deleteSelectedProductLine() {
    if (!mounted) return;
    _billLinesKey.currentState?.deleteSelectedRow();
  }

  Future<void> _handleSaveBillShortcut() async {
    if (_billLinesKey.currentState != null) {
      await _billLinesKey.currentState?.commitCurrentEdit();
    }
    _billSummaryKey.currentState?.commitActiveEdits();

    final lines = ref.read(billingControllerProvider).billLines;
    if (lines.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('બિલ ખાલી છે. કૃપયા ઉત્પાદન ઉમેરો.'),
          duration: Duration(seconds: 2),
        ),
      );
      _focusProductSearch();
      return;
    }

    final billingState = ref.read(billingTabsProvider);
    final transactionType = billingState.activeDraft.transactionType;
    if (transactionType == 'khata') {
      final customerNameSnapshot = _normalizedCustomerName(_customerName);
      if (customerNameSnapshot == null || customerNameSnapshot.isEmpty) {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('ઉધાર (ખાતા) બિલ માટે ગ્રાહકનું નામ જરૂરી છે.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        _focusCustomerSearch();
        return;
      }
    }

    final isPrinterConn = await _billingPrintService.isPrinterConnected();
    if (!mounted) return;

    if (isPrinterConn) {
      final shouldPrint = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('બિલ પ્રિન્ટ'),
            content: const Text('બિલ પ્રિન્ટ કરવું છે?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('ના (સાચવો ફક્ત)'),
              ),
              ElevatedButton(
                autofocus: true,
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('હા (પ્રિન્ટ કરો)'),
              ),
            ],
          );
        },
      );

      if (!mounted || shouldPrint == null) {
        _focusProductSearch();
        return;
      }

      if (shouldPrint) {
        await _saveAndPrintBill();
      } else {
        await _saveBill();
      }
    } else {
      await _saveBill();
    }

    if (mounted) {
      _focusProductSearch();
    }
  }

  Future<void> _saveBill() async {
    if (_billLinesKey.currentState != null) {
      await _billLinesKey.currentState?.commitCurrentEdit();
    }
    _billSummaryKey.currentState?.commitActiveEdits();

    if (ref.read(billingControllerProvider).billLines.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('બિલ ખાલી છે. કૃપયા ઉત્પાદન ઉમેરો.'),
          duration: Duration(seconds: 2),
        ),
      );
      _focusProductSearch();
      return;
    }

    final billingState = ref.read(billingTabsProvider);
    final transactionType = billingState.activeDraft.transactionType;
    if (transactionType == 'khata') {
      final rawCustomerName = _customerController.text.trim().isNotEmpty
          ? _customerController.text.trim()
          : _customerName;
      final customerNameSnapshot = _normalizedCustomerName(rawCustomerName);
      if (customerNameSnapshot == null || customerNameSnapshot.isEmpty) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('ઉધાર (ખાતા) બિલ માટે ગ્રાહકનું નામ જરૂરી છે.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        _focusCustomerSearch();
        return;
      }
    }

    await _saveBillToDatabase(showSuccessMessage: true, clearDraft: true);
    if (mounted) {
      _focusProductSearch();
    }
  }

  Future<void> _saveAndPrintBill() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_billLinesKey.currentState != null) {
      await _billLinesKey.currentState?.commitCurrentEdit();
    }
    _billSummaryKey.currentState?.commitActiveEdits();

    if (ref.read(billingControllerProvider).billLines.isEmpty) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('બિલ ખાલી છે. કૃપયા ઉત્પાદન ઉમેરો.'),
          duration: Duration(seconds: 2),
        ),
      );
      _focusProductSearch();
      return;
    }

    final billingState = ref.read(billingTabsProvider);
    final transactionType = billingState.activeDraft.transactionType;
    if (transactionType == 'khata') {
      final rawCustomerName = _customerController.text.trim().isNotEmpty
          ? _customerController.text.trim()
          : _customerName;
      final customerNameSnapshot = _normalizedCustomerName(rawCustomerName);
      if (customerNameSnapshot == null || customerNameSnapshot.isEmpty) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('ઉધાર (ખાતા) બિલ માટે ગ્રાહકનું નામ જરૂરી છે.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        _focusCustomerSearch();
        return;
      }
    }

    final billId = await _saveBillToDatabase(
      showSuccessMessage: false,
      clearDraft: false,
    );
    if (billId == null) {
      _focusProductSearch();
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

    if (mounted) {
      _focusProductSearch();
    }
  }

  double _toStockUnitQuantity(BillLineItem line) {
    final unit = line.item.unitType.trim().toLowerCase();
    if (unit == 'weight_kg' ||
        unit.contains('કિલો') ||
        unit == 'kg' ||
        unit.contains('kilo')) {
      return line.qtyGrams / 1000.0;
    }
    if (unit == 'weight_gram' ||
        unit.contains('ગ્રામ') ||
        unit == 'g' ||
        unit.contains('gram')) {
      return line.qtyGrams;
    }
    return line.qtyGrams.roundToDouble();
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
        productNameSnapshot: line.item.nameGujarati,
        unitTypeSnapshot: line.item.unitType,
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
    if (_billLinesKey.currentState != null) {
      await _billLinesKey.currentState?.commitCurrentEdit();
    }
    _billSummaryKey.currentState?.commitActiveEdits();

    final billingState = ref.read(billingTabsProvider);
    final transactionType = billingState.activeDraft.transactionType;
    final selectedCustomerId =
        billingState.activeDraft.customerId ?? _customerId;

    final linesSnapshot = ref.read(billingControllerProvider).billLines;
    final discountSnapshot = ref.read(billingControllerProvider).discount;
    final otherChargesSnapshot = ref.read(billingControllerProvider).otherCharges;
    final customerIdSnapshot =
        (selectedCustomerId != null && selectedCustomerId > 0)
            ? selectedCustomerId
            : null;
    final rawCustomerName = _customerController.text.trim().isNotEmpty
        ? _customerController.text.trim()
        : _customerName;
    final customerNameSnapshot = _normalizedCustomerName(rawCustomerName);
    final productIds = linesSnapshot
        .map((l) => l.item.id)
        .whereType<int>()
        .toList();

    try {
      int? effectiveCustomerId = customerIdSnapshot;
      if (effectiveCustomerId == null &&
          customerNameSnapshot != null &&
          customerNameSnapshot.trim().isNotEmpty) {
        final custRepo = ref.read(customerRepositoryProvider);
        final matches = await custRepo.search(customerNameSnapshot.trim());
        final exactMatch = matches.cast<Customer?>().firstWhere(
              (c) =>
                  c != null &&
                  (c.nameGujarati.trim().toLowerCase() ==
                          customerNameSnapshot.trim().toLowerCase() ||
                      (c.nameEnglish != null &&
                          c.nameEnglish!.trim().toLowerCase() ==
                              customerNameSnapshot.trim().toLowerCase())),
              orElse: () => null,
            );
        if (exactMatch != null && exactMatch.id != null) {
          effectiveCustomerId = exactMatch.id;
        } else if (transactionType == 'khata') {
          effectiveCustomerId = await custRepo.insert(
            Customer(
              nameGujarati: customerNameSnapshot.trim(),
              accountType: 'regular',
              totalOutstanding: 0.0,
              creditLimit: 2000.0,
              isActive: true,
              createdAt: DateTime.now().toIso8601String(),
            ),
          );
        }
      }

      final billItems = _buildBillItemsFromLines(linesSnapshot);
      final billRepo = ref.read(billRepositoryProvider);
      final totalBillAmount =
          linesSnapshot.fold(0.0, (s, l) => s + l.amount) -
              discountSnapshot +
              otherChargesSnapshot;
      final paidAmount = transactionType == 'khata' ? 0.0 : totalBillAmount;

      final billId = await billRepo.createBill(
        customerId: effectiveCustomerId,
        customerNameSnapshot:
            (customerNameSnapshot == null || customerNameSnapshot.isEmpty)
                ? null
                : customerNameSnapshot,
        items: billItems,
        discountAmount: discountSnapshot,
        otherCharges: otherChargesSnapshot,
        paidAmount: paidAmount,
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
    ref.invalidate(customersProvider);
    ref.invalidate(customerListProvider);
    ref.invalidate(bulkCustomerBalancesProvider);
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
    if (_billLinesKey.currentState != null) {
      await _billLinesKey.currentState?.commitCurrentEdit();
    }
    _billSummaryKey.currentState?.commitActiveEdits();

    if (ref.read(billingControllerProvider).billLines.isEmpty) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('બિલ ખાલી છે. કૃપયા આઇટમ ઉમેરો (F1).'),
          duration: Duration(seconds: 2),
        ),
      );
      _focusProductSearch();
      return;
    }

    final billingState = ref.read(billingTabsProvider);
    final transactionType = billingState.activeDraft.transactionType;
    if (transactionType == 'khata') {
      final rawCustomerName = _customerController.text.trim().isNotEmpty
          ? _customerController.text.trim()
          : _customerName;
      final customerNameSnapshot = _normalizedCustomerName(rawCustomerName);
      if (customerNameSnapshot == null || customerNameSnapshot.isEmpty) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('ઉધાર (ખાતા) બિલ માટે ગ્રાહકનું નામ જરૂરી છે (F2).'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        _focusCustomerSearch();
        return;
      }
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
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    final roleLabelGu = _currentRoleGujaratiLabel();
    final avatarText = _roleInitialForAvatar(roleLabelGu);
    final billLineCount = ref.watch(billingControllerProvider).billLines.length;

    ref.listen<List<BillLineItem>>(
      billingControllerProvider.select((s) => s.billLines),
      (prev, next) {
        if (prev != null && prev.isNotEmpty && next.isEmpty) {
          _focusProductSearch();
        }
      },
    );

    return Shortcuts(
      shortcuts: AppShortcuts.billingShortcuts,
      child: Actions(
        actions: {
          FocusProductSearchIntent: CallbackAction<FocusProductSearchIntent>(
            onInvoke: (_) {
              _billLinesKey.currentState?.commitCurrentEdit();
              _focusProductSearch();
              return null;
            },
          ),
          SaveBillIntent: CallbackAction<SaveBillIntent>(
            onInvoke: (_) {
              _handleSaveBillShortcut();
              return null;
            },
          ),
          EscapeIntent: CallbackAction<EscapeIntent>(
            onInvoke: (_) {
              _handleEscape();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
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
                    onPressed: _handleSaveBillShortcut,
                    tooltip: 'બિલ સાચવો (Ctrl+Enter)',
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
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'returns', child: Text('રિટર્ન / બદલો')),
                  ],
                ),
                if (!isWide)
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
                  child: isWide ? _buildDesktopLayout() : _buildMobileLayout(billLineCount),
                ),
              ],
            ),
          ),
        ),
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
            onProductAdded: (item, lineIndex, isWeight) {
              if (_billLinesKey.currentState != null) {
                _billLinesKey.currentState!.startEditingLineQuantity(lineIndex);
              } else {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _billLinesKey.currentState?.startEditingLineQuantity(lineIndex);
                });
              }
            },
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

  /// ─── Mobile layout: Express 1-Screen Counter Billing ───
  Widget _buildMobileLayout(int billLineCount) {
    return MobileExpressBillingView(
      boundaryKey: _billBoundaryMobileKey,
      customerName: _customerName,
      customerId: _customerId,
      customerController: _customerController,
      onCustomerSelected: (id, name) {
        ref.read(billingTabsProvider.notifier).setSelectedCustomer(id, name);
        setState(() {
          _customerId = id;
          _customerName = name;
        });
      },
      onClearCustomer: () {
        ref.read(billingTabsProvider.notifier).setCustomerForActive(
              customerId: null,
              customerName: null,
            );
        setState(() {
          _customerId = null;
          _customerName = null;
          _customerController.clear();
        });
      },
      checkStock: _hasEnoughStockForDraft,
      onSaveBill: _saveBill,
      onPrintBill: _printBill,
      onClearBill: _clearCurrentBillDraft,
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
                    focusNode: _customerSearchFocusNode,
                    hintText: 'ગ્રાહક ઉમેરો',
                    onCustomerSelected: (customerId, customerName) {
                      ref
                          .read(billingTabsProvider.notifier)
                          .setSelectedCustomer(customerId, customerName);
                      setState(() {
                        _customerId = customerId > 0 ? customerId : null;
                        _customerName = customerName;
                      });
                      _focusProductSearch();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: BillLinesPanel(
            key: _billLinesKey,
            checkStock: _hasEnoughStockForDraft,
            onInlineEditCompleted: _focusProductSearch,
          ),
        ),
        const Divider(height: 1),
        BillSummaryPanel(
          key: _billSummaryKey,
          onClearBill: _clearCurrentBillDraft,
          onSaveBill: _saveBill,
          onPrintBill: _printBill,
          onSaveAndPrintBill: _saveAndPrintBill,
        ),
      ],
    );
  }
}

