import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_format.dart';
import '../../data/repositories/return_repository.dart';
import '../../shared/models/bill_item_model.dart';
import '../../shared/models/bill_model.dart';
import '../../shared/models/product_model.dart';
import '../billing/views/dialogs/product_addition_dialog.dart';
import 'returns_providers.dart';

class ReturnReplaceScreen extends ConsumerStatefulWidget {
  const ReturnReplaceScreen({super.key});

  @override
  ConsumerState<ReturnReplaceScreen> createState() => _ReturnReplaceScreenState();
}

class _ReturnReplaceScreenState extends ConsumerState<ReturnReplaceScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _searchDebounce;

  String _query = '';
  String _status = 'all';
  DateTime? _fromDate;
  DateTime? _toDate;

  // Selected Bill State
  Bill? _selectedBill;
  List<BillItem> _billItems = [];
  bool _isLoading = false;
  String? _error;

  // Mode: 'return' or 'replace'
  String _activeMode = 'return';

  // --- RETURN MODE STATE ---
  // Map of billItemId -> committed returnedQty (in product base unit: kg, gram, liter, or count)
  final Map<int, double> _returnedQtyMap = {};

  // Which item row is currently expanded for inline input
  int? _expandedItemId;

  // Per-item text controllers for the inline return input (key = billItemId)
  final Map<int, TextEditingController> _returnInputControllers = {};

  // Focus nodes for inline return quantity inputs (key = billItemId)
  final Map<int, FocusNode> _returnFocusNodes = {};

  // Per-item inline validation errors
  final Map<int, String?> _returnInputErrors = {};

  // --- REPLACE MODE STATE ---
  List<BillItem> _replaceCartItems = [];
  final _catalogSearchCtrl = TextEditingController();
  List<Product> _catalogSearchResults = [];
  bool _isSearchingCatalog = false;
  Timer? _catalogSearchDebounce;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadCatalogProducts();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _catalogSearchDebounce?.cancel();
    _searchCtrl.dispose();
    _scrollController.dispose();
    _catalogSearchCtrl.dispose();
    _disposeReturnControllers();
    super.dispose();
  }

  void _disposeReturnControllers() {
    _searchDebounce?.cancel();
    _catalogSearchDebounce?.cancel();
    for (final ctrl in _returnInputControllers.values) {
      ctrl.dispose();
    }
    _returnInputControllers.clear();
    for (final fn in _returnFocusNodes.values) {
      fn.dispose();
    }
    _returnFocusNodes.clear();
    _returnInputErrors.clear();
    _expandedItemId = null;
  }

  TextEditingController _getOrCreateReturnController(int itemId) {
    return _returnInputControllers.putIfAbsent(itemId, () {
      final ctrl = TextEditingController();
      ctrl.addListener(() {
        if (_returnInputErrors[itemId] != null) {
          _returnInputErrors[itemId] = null;
        }
        if (mounted) setState(() {});
      });
      return ctrl;
    });
  }

  FocusNode _getOrCreateFocusNode(int itemId) {
    return _returnFocusNodes.putIfAbsent(itemId, () => FocusNode());
  }

  // ─── Filter helpers ────────────────────────────────────────────────────────

  bool get _hasDateFilter => _fromDate != null && _toDate != null;
  bool get _hasActiveFilters => _query.isNotEmpty || _status != 'all' || _hasDateFilter;

  BillListQueryParams get _queryParams => BillListQueryParams(
        query: _query,
        status: _status,
        from: _fromDate,
        to: _toDate,
      );

  void _scheduleSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        _query = _searchCtrl.text.trim();
      });
    });
  }

  void _scheduleCatalogSearch(String q) {
    _catalogSearchDebounce?.cancel();
    _catalogSearchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _loadCatalogProducts(query: q);
    });
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _fromDate = picked);
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? _fromDate ?? DateTime.now(),
      firstDate: _fromDate ?? DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _toDate = picked);
  }

  void _clearDates() => setState(() {
        _fromDate = null;
        _toDate = null;
      });

  // ─── Bill selection ────────────────────────────────────────────────────────

  Future<void> _openBill(Bill bill) async {
    setState(() {
      _selectedBill = bill;
      _error = null;
      _activeMode = 'return';
      _returnedQtyMap.clear();
      _replaceCartItems = [];
    });
    _disposeReturnControllers();
    await _loadBillItems(bill.id!);
    if (_catalogSearchResults.isEmpty) {
      _loadCatalogProducts();
    }
  }

  void _backToBillList() {
    _disposeReturnControllers();
    setState(() {
      _selectedBill = null;
      _billItems = [];
      _returnedQtyMap.clear();
      _replaceCartItems = [];
    });
  }

  Future<void> _loadBillItems(int billId) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _billItems = [];
      _returnedQtyMap.clear();
      _replaceCartItems = [];
    });
    _disposeReturnControllers();

    try {
      final repo = ref.read(returnRepositoryProvider);
      final items = await repo.getBillItems(billId);
      if (!mounted) return;

      // Initialise per-item input controllers
      for (final item in items) {
        if (item.id != null && !item.isReturned && item.qty > 0) {
          _getOrCreateReturnController(item.id!);
        }
      }

      setState(() {
        _billItems = items;
        _replaceCartItems = items
            .where((e) => !e.isReturned && e.qty > 0)
            .map((e) => BillItem(
                  id: e.id,
                  billId: e.billId,
                  productId: e.productId,
                  productNameSnapshot: e.productNameSnapshot,
                  unitTypeSnapshot: e.unitTypeSnapshot,
                  sellPriceSnapshot: e.sellPriceSnapshot,
                  qty: e.qty,
                  amount: e.amount,
                  isReturned: e.isReturned,
                ))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Unit helpers ──────────────────────────────────────────────────────────

  String _unitName(String? unit) => ReturnRepository.formatUnitName(unit);
  bool _isKilo(String? unit) => ReturnRepository.isKiloUnit(unit);
  bool _isGram(String? unit) => ReturnRepository.isGramUnit(unit);
  bool _isLiter(String? unit) => ReturnRepository.isLiterUnit(unit);
  bool _isDecimal(String? unit) => ReturnRepository.isDecimalUnit(unit);

  String _formatQtyWithUnit(double qty, String? unitType) {
    final u = _unitName(unitType);
    if (_isKilo(unitType)) {
      final grams = (qty * 1000).round();
      if (grams < 1000) {
        return '$grams ગ્રામ';
      }
      if (grams % 1000 == 0) {
        return '${(grams ~/ 1000)} $u';
      }
      return '${qty.toStringAsFixed(3)} $u ($grams ગ્રામ)';
    }
    if (_isGram(unitType)) {
      return '${qty.round()} $u';
    }
    if (_isLiter(unitType)) {
      return qty % 1 == 0 ? '${qty.toInt()} $u' : '${qty.toStringAsFixed(2)} $u';
    }
    return qty % 1 == 0 ? '${qty.toInt()} $u' : '${qty.toStringAsFixed(2)} $u';
  }

  String _formatRateWithUnit(double rate, String? unitType) {
    final u = _unitName(unitType);
    return '₹${rate.toStringAsFixed(2)} / $u';
  }

  /// Parses user's raw input number into base units (kg for kilo, grams for gram, liters for liter, count for discrete)
  double? _parseReceivedBaseQty(double rawInput, BillItem item) {
    if (rawInput <= 0) return null;
    if (_isKilo(item.unitTypeSnapshot)) {
      // If user typed in grams (e.g. 500 for 500g where item.qty is 1kg):
      if (rawInput > item.qty && (rawInput / 1000.0) <= item.qty + 0.0001) {
        return rawInput / 1000.0;
      }
      // If user typed directly in kg (e.g. 0.25, 0.5, 1, 1.5, 2):
      if (rawInput <= item.qty + 0.0001) {
        return rawInput;
      }
      // Also allow gram inputs like 10, 50, 100, 250, 500 if within range:
      if (rawInput >= 10 && (rawInput / 1000.0) <= item.qty + 0.0001) {
        return rawInput / 1000.0;
      }
      return null;
    }
    if (_isGram(item.unitTypeSnapshot) || _isLiter(item.unitTypeSnapshot)) {
      if (rawInput <= item.qty + 0.0001) return rawInput;
      return null;
    }
    // Discrete unit: must be whole number
    if (rawInput % 1 != 0) return null;
    if (rawInput <= item.qty + 0.0001) return rawInput;
    return null;
  }

  // ─── Return computed getters ───────────────────────────────────────────────

  double get _totalRefundAmount {
    double total = 0;
    for (final item in _billItems) {
      final retQty = _returnedQtyMap[item.id] ?? 0;
      total += retQty * (item.sellPriceSnapshot ?? 0);
    }
    return total;
  }

  double get _billGrandTotal =>
      _billItems.fold(0.0, (sum, i) => sum + i.amount);

  bool get _isFullyReturnedBill {
    if (_selectedBill?.paymentStatus == 'fully_returned') return true;
    if (_billItems.isNotEmpty &&
        _billItems.every((i) => i.isReturned || i.qty <= 0)) {
      return true;
    }
    return false;
  }

  // ─── Inline return row logic ───────────────────────────────────────────────

  void _toggleExpandRow(BillItem item) {
    if (item.id == null || item.isReturned || _isFullyReturnedBill) return;
    if (_expandedItemId == item.id) {
      setState(() {
        _expandedItemId = null; // collapse
      });
      return;
    }

    setState(() {
      _expandedItemId = item.id;
      _returnInputErrors[item.id!] = null;
      // Pre-fill controller with committed value (if any)
      final ctrl = _getOrCreateReturnController(item.id!);
      final committed = _returnedQtyMap[item.id] ?? 0.0;
      if (committed > 0) {
        if (_isKilo(item.unitTypeSnapshot)) {
          final grams = (committed * 1000).round();
          ctrl.text = (committed >= 1 && grams % 1000 == 0)
              ? committed.toStringAsFixed(0)
              : grams.toString();
        } else if (_isGram(item.unitTypeSnapshot)) {
          ctrl.text = committed.round().toString();
        } else if (_isLiter(item.unitTypeSnapshot)) {
          ctrl.text = committed % 1 == 0
              ? committed.toInt().toString()
              : committed.toStringAsFixed(2);
        } else {
          ctrl.text = committed.toInt().toString();
        }
      }
    });

    // Request focus on the quantity textbox immediately and select existing text
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final fn = _getOrCreateFocusNode(item.id!);
      fn.requestFocus();
      final ctrl = _getOrCreateReturnController(item.id!);
      ctrl.selection =
          TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
    });
  }

  void _returnEntireProduct(BillItem item) {
    if (item.id == null || item.isReturned || _isFullyReturnedBill) return;
    final ctrl = _getOrCreateReturnController(item.id!);
    if (_isKilo(item.unitTypeSnapshot)) {
      final grams = (item.qty * 1000).round();
      ctrl.text = (item.qty >= 1 && grams % 1000 == 0)
          ? item.qty.toStringAsFixed(0)
          : grams.toString();
    } else if (_isGram(item.unitTypeSnapshot)) {
      ctrl.text = item.qty.round().toString();
    } else if (_isLiter(item.unitTypeSnapshot)) {
      ctrl.text = item.qty % 1 == 0
          ? item.qty.toInt().toString()
          : item.qty.toStringAsFixed(2);
    } else {
      ctrl.text = item.qty.toInt().toString();
    }
    setState(() {
      _returnedQtyMap[item.id!] = item.qty;
      _returnInputErrors[item.id!] = null;
      _expandedItemId = null; // collapse row cleanly
    });
  }

  void _returnAllProducts() {
    if (_isFullyReturnedBill) return;
    for (final item in _billItems) {
      if (item.id != null && !item.isReturned && item.qty > 0) {
        final ctrl = _getOrCreateReturnController(item.id!);
        if (_isKilo(item.unitTypeSnapshot)) {
          final grams = (item.qty * 1000).round();
          ctrl.text = (item.qty >= 1 && grams % 1000 == 0)
              ? item.qty.toStringAsFixed(0)
              : grams.toString();
        } else if (_isGram(item.unitTypeSnapshot)) {
          ctrl.text = item.qty.round().toString();
        } else if (_isLiter(item.unitTypeSnapshot)) {
          ctrl.text = item.qty % 1 == 0
              ? item.qty.toInt().toString()
              : item.qty.toStringAsFixed(2);
        } else {
          ctrl.text = item.qty.toInt().toString();
        }
        _returnedQtyMap[item.id!] = item.qty;
        _returnInputErrors[item.id!] = null;
      }
    }
    setState(() {
      _expandedItemId = null;
    });
  }

  void _clearRowReturn(BillItem item) {
    if (item.id == null) return;
    final ctrl = _returnInputControllers[item.id!];
    setState(() {
      ctrl?.clear();
      _returnedQtyMap.remove(item.id);
      _returnInputErrors[item.id!] = null;
      _expandedItemId = null;
    });
  }

  void _confirmRowReturn(BillItem item) {
    if (item.id == null) return;
    final ctrl = _returnInputControllers[item.id!];
    if (ctrl == null) return;

    final rawText = ctrl.text.trim();
    final rawInput = double.tryParse(rawText);

    if (rawInput == null || rawInput <= 0) {
      setState(() => _returnInputErrors[item.id!] = 'માન્ય સંખ્યા દાખલ કરો');
      return;
    }

    final u = _unitName(item.unitTypeSnapshot);
    if (!_isDecimal(item.unitTypeSnapshot) && rawInput % 1 != 0) {
      setState(() => _returnInputErrors[item.id!] =
          '$u માટે પૂર્ણ સંખ્યા (whole number) દાખલ કરો');
      return;
    }

    final receivedBase = _parseReceivedBaseQty(rawInput, item);
    if (receivedBase == null || receivedBase > item.qty + 0.0001) {
      final maxDisplay = _formatQtyWithUnit(item.qty, item.unitTypeSnapshot);
      setState(() => _returnInputErrors[item.id!] =
          'ખરીદેલ માત્રા ($maxDisplay) થી વધુ ન હોઈ શકે');
      return;
    }

    setState(() {
      _returnedQtyMap[item.id!] = receivedBase;
      _returnInputErrors[item.id!] = null;
      _expandedItemId = null; // collapse after confirm
    });
  }

  // ─── Return submit ─────────────────────────────────────────────────────────

  Future<void> _confirmReturn() async {
    if (_selectedBill == null) return;
    if (_returnedQtyMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('મહેરબાની કરીને પરત કરવા માટે ઓછામાં ઓછું એક ઉત્પાદન પસંદ કરો')),
      );
      return;
    }

    final lines = <ReturnLine>[];
    for (final item in _billItems) {
      if (item.id == null) continue;
      final retQty = _returnedQtyMap[item.id];
      if (retQty != null && retQty > 0) {
        lines.add(ReturnLine(
          billItemId: item.id!,
          productId: item.productId,
          productName: item.productNameSnapshot,
          unitType: item.unitTypeSnapshot,
          qtyReturned: retQty,
          sellPriceSnapshot: item.sellPriceSnapshot ?? 0,
        ));
      }
    }

    final mode = ref.read(returnModeProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('પરત લેવાની ખાતરી કરો'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('બિલ #: ${_selectedBill!.billNumber}'),
            const SizedBox(height: 8),
            Text(
              'કુલ રિફંડ: ${formatCurrency(_totalRefundAmount)}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
                'મોડ: ${mode == 'cash_refund' ? 'કેશ રિફંડ' : 'ઉધાર ક્રેડિટ'}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('રદ')),
          ElevatedButton(
            onPressed: () => ctx.pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            child: const Text('સાચવો'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(returnRepositoryProvider);
      await repo.createReturn(
        billId: _selectedBill!.id!,
        customerId: _selectedBill!.customerId,
        lines: lines,
        returnMode: mode,
      );
      if (!mounted) return;
      ref.invalidate(returnBillListProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('પરત સફળતાપૂર્વક લેવાયું અને સ્ટોક અપડેટ થયો')),
      );
      _backToBillList();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Replace logic ─────────────────────────────────────────────────────────

  double get _originalBillTotal =>
      _billItems.fold(0.0, (sum, i) => sum + i.amount);
  double get _newReplaceTotal =>
      _replaceCartItems.fold(0.0, (sum, i) => sum + i.amount);
  double get _replacePriceDiff => _newReplaceTotal - _originalBillTotal;

  Future<void> _loadCatalogProducts({String query = ''}) async {
    setState(() => _isSearchingCatalog = true);
    try {
      final repo = ref.read(returnRepositoryProvider);
      final results = await repo.getProducts(
        query: query.trim().isEmpty ? null : query.trim(),
      );
      if (!mounted) return;
      setState(() => _catalogSearchResults = results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'ઉત્પાદન લાવવામાં ભૂલ: $e');
    } finally {
      if (mounted) setState(() => _isSearchingCatalog = false);
    }
  }

  Future<bool> _checkReplaceStock({
    required Product item,
    required double newQtyGrams,
  }) async {
    double existingCartQty = 0.0;
    for (final ci in _replaceCartItems) {
      if (ci.productId == item.id) {
        existingCartQty += ci.qty;
      }
    }

    final double requestedStock;
    final unit = item.unitType.trim().toLowerCase();
    if (unit == 'weight_kg' ||
        unit.contains('કિલો') ||
        unit == 'kg' ||
        unit.contains('kilo')) {
      requestedStock = newQtyGrams / 1000.0;
    } else if (unit == 'weight_gram' ||
        unit.contains('ગ્રામ') ||
        unit == 'g' ||
        unit.contains('gram')) {
      requestedStock = newQtyGrams;
    } else {
      requestedStock = newQtyGrams;
    }

    return (existingCartQty + requestedStock) <= item.stockQty;
  }

  Future<void> _onSelectProductForReplace(Product item) async {
    if (item.id == null) return;

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
            '${item.nameGujarati} નો સ્ટોક ઓછો છે.\nહાલ સ્ટોક: ${item.stockQty % 1 == 0 ? item.stockQty.toInt() : item.stockQty.toStringAsFixed(2)} ${item.unitType}',
          ),
          actions: [
            TextButton(
              onPressed: () => ctx.pop(false),
              child: const Text('રદ કરો'),
            ),
            ElevatedButton(
              onPressed: () => ctx.pop(true),
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
      checkStock: (id, qty) => _checkReplaceStock(item: item, newQtyGrams: qty),
    );

    if (result != null && mounted) {
      final qtyGrams = result.$1;
      final amount = result.$2;

      final double finalQty;
      final unit = item.unitType.trim().toLowerCase();
      if (unit == 'weight_kg' ||
          unit.contains('કિલો') ||
          unit == 'kg' ||
          unit.contains('kilo')) {
        finalQty = qtyGrams / 1000.0;
      } else {
        finalQty = qtyGrams;
      }

      setState(() {
        final existingIndex =
            _replaceCartItems.indexWhere((i) => i.productId == item.id);
        if (existingIndex >= 0) {
          final existing = _replaceCartItems[existingIndex];
          final newQty = existing.qty + finalQty;
          final newAmount = existing.amount + amount;
          _replaceCartItems[existingIndex] = BillItem(
            id: existing.id,
            billId: existing.billId,
            productId: existing.productId,
            productNameSnapshot: existing.productNameSnapshot,
            unitTypeSnapshot: existing.unitTypeSnapshot,
            sellPriceSnapshot: existing.sellPriceSnapshot,
            qty: newQty,
            amount: newAmount,
            isReturned: existing.isReturned,
          );
        } else {
          _replaceCartItems.add(BillItem(
            billId: _selectedBill?.id ?? 0,
            productId: item.id!,
            productNameSnapshot: item.nameGujarati,
            unitTypeSnapshot: item.unitType,
            sellPriceSnapshot: item.sellPrice,
            qty: finalQty,
            amount: amount,
            isReturned: false,
          ));
        }
      });
    }
  }

  void _editReplaceCartItem(int index) {
    final item = _replaceCartItems[index];
    final u = _unitName(item.unitTypeSnapshot);
    final isKilo = _isKilo(item.unitTypeSnapshot);
    final isGram = _isGram(item.unitTypeSnapshot);
    final isLiter = _isLiter(item.unitTypeSnapshot);
    final isDecimal = _isDecimal(item.unitTypeSnapshot);

    final qtyCtrl = TextEditingController(
      text: isKilo
          ? (item.qty * 1000).toStringAsFixed(0)
          : (isDecimal
              ? (item.qty % 1 == 0 ? item.qty.toInt().toString() : item.qty.toStringAsFixed(2))
              : item.qty.toInt().toString()),
    );
    final priceCtrl = TextEditingController(
      text: (item.sellPriceSnapshot ?? 0).toStringAsFixed(2),
    );

    final String qtyLabel;
    final String qtySuffix;
    if (isKilo) {
      qtyLabel = 'વજન (ગ્રામ)';
      qtySuffix = 'ગ્રામ';
    } else if (isGram) {
      qtyLabel = 'વજન (ગ્રામ)';
      qtySuffix = 'ગ્રામ';
    } else if (isLiter) {
      qtyLabel = 'માત્રા (લીટર)';
      qtySuffix = 'લીટર';
    } else {
      qtyLabel = 'માત્રા ($u)';
      qtySuffix = u;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDlg) => AlertDialog(
          title: Text('${item.productNameSnapshot ?? 'ઉત્પાદન'} સુધારો'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: qtyLabel,
                  suffixText: qtySuffix,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'ભાવ (₹ / $u)',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                ctx.pop();
                setState(() => _replaceCartItems.removeAt(index));
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('દૂર કરો'),
            ),
            TextButton(onPressed: () => ctx.pop(), child: const Text('રદ')),
            ElevatedButton(
              onPressed: () {
                final rawQty = double.tryParse(qtyCtrl.text) ?? 0.0;
                final finalQty = isKilo ? rawQty / 1000.0 : rawQty;
                final price = double.tryParse(priceCtrl.text) ?? 0.0;
                if (finalQty <= 0) return;
                ctx.pop();
                setState(() {
                  _replaceCartItems[index] = BillItem(
                    id: item.id,
                    billId: item.billId,
                    productId: item.productId,
                    productNameSnapshot: item.productNameSnapshot,
                    unitTypeSnapshot: item.unitTypeSnapshot,
                    sellPriceSnapshot: price,
                    qty: finalQty,
                    amount: finalQty * price,
                    isReturned: item.isReturned,
                  );
                });
              },
              child: const Text('સાચવો'),
            ),
          ],
        ),
      ),
    ).then((_) {
      qtyCtrl.dispose();
      priceCtrl.dispose();
    });
  }

  Future<void> _confirmReplace() async {
    if (_selectedBill == null) return;
    if (_replaceCartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('બદલી બિલમાં ઓછામાં ઓછું એક ઉત્પાદન હોવું જોઇએ')),
      );
      return;
    }

    final mode = ref.read(replaceModeProvider);
    final diff = _replacePriceDiff;
    String diffText = '₹0.00 (સરખું રકમ)';
    if (diff > 0) {
      diffText = 'ગ્રાહકે ₹${diff.toStringAsFixed(2)} વધુ ચૂકવશે';
    } else if (diff < 0) {
      diffText = 'દુકાનદારે ₹${(-diff).toStringAsFixed(2)} રિફંડ કરવાના';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('બિલ બદલી ની ખાતરી કરો'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('જૂનું ટોટલ: ${formatCurrency(_originalBillTotal)}'),
            Text(
              'નવું ટોટલ: ${formatCurrency(_newReplaceTotal)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(diffText,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: diff > 0
                        ? Colors.green
                        : (diff < 0 ? Colors.red : Colors.black))),
            const SizedBox(height: 8),
            Text('મોડ: ${mode == 'cash_refund' ? 'કેશ' : 'ઉધાર'}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('રદ')),
          ElevatedButton(
            onPressed: () => ctx.pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            child: const Text('સાચવો'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(returnRepositoryProvider);
      await repo.replaceBill(
        billId: _selectedBill!.id!,
        customerId: _selectedBill!.customerId,
        newItems: _replaceCartItems,
        paymentMode: mode,
      );
      if (!mounted) return;
      ref.invalidate(returnBillListProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('બિલ સફળતાપૂર્વક બદલાયું અને સ્ટોક અપડેટ થયો')),
      );
      _backToBillList();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(returnBillListProvider(_queryParams));

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedBill == null
            ? 'રિટર્ન / બદલો'
            : 'બિલ નં: ${_selectedBill!.billNumber}'),
        leading: _selectedBill != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'પાછા જાઓ (બિલ યાદી)',
                onPressed: _backToBillList,
              )
            : null,
      ),
      body: PopScope(
        canPop: _selectedBill == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _selectedBill != null) {
            _backToBillList();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: _selectedBill == null
              ? _buildBillSelectionView(billsAsync)
              : _buildDetailView(),
        ),
      ),
    );
  }

  // ─── Bill selection view ───────────────────────────────────────────────────

  Widget _buildBillSelectionView(AsyncValue<List<Bill>> billsAsync) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: AppColors.primary),
              hintText: 'બિલ નંબર, ગ્રાહકનું નામ, અથવા રકમ શોધો...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchCtrl.clear();
                        _scheduleSearch();
                      },
                    )
                  : null,
            ),
            onChanged: (_) => _scheduleSearch(),
          ),
        ),
        const SizedBox(height: 12),
        _buildStatusChips(),
        const SizedBox(height: 10),
        _buildDateRow(),
        const SizedBox(height: 12),
        Expanded(child: _buildBillList(billsAsync)),
      ],
    );
  }

  Widget _buildStatusChips() {
    const statuses = <String, String>{
      'all': 'બધા',
      'paid': 'ચૂકવેલ',
      'partial': 'આંશિક',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: statuses.entries.map((entry) {
          final selected = _status == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(entry.value),
              selected: selected,
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: selected ? Colors.white : const Color(0xFF334155),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              side: BorderSide(
                color: selected ? AppColors.primary : const Color(0xFFCBD5E1),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              onSelected: (_) => setState(() => _status = entry.key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateRow() {
    final fromLabel = _fromDate == null
        ? 'તારીખ થી'
        : DateFormat('dd/MM/yyyy').format(_fromDate!);
    final toLabel = _toDate == null
        ? 'તારીખ સુધી'
        : DateFormat('dd/MM/yyyy').format(_toDate!);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _pickFromDate,
            icon: const Icon(Icons.date_range, size: 18, color: AppColors.primary),
            label: Text(
              fromLabel,
              style: TextStyle(
                fontWeight:
                    _fromDate != null ? FontWeight.bold : FontWeight.normal,
                color: _fromDate != null ? AppColors.primaryDark : null,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              side: BorderSide(
                color: _fromDate != null
                    ? AppColors.primary
                    : const Color(0xFFCBD5E1),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              backgroundColor: _fromDate != null
                  ? AppColors.primaryLight.withValues(alpha: 0.08)
                  : Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _pickToDate,
            icon: const Icon(Icons.date_range, size: 18, color: AppColors.primary),
            label: Text(
              toLabel,
              style: TextStyle(
                fontWeight:
                    _toDate != null ? FontWeight.bold : FontWeight.normal,
                color: _toDate != null ? AppColors.primaryDark : null,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              side: BorderSide(
                color: _toDate != null
                    ? AppColors.primary
                    : const Color(0xFFCBD5E1),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              backgroundColor: _toDate != null
                  ? AppColors.primaryLight.withValues(alpha: 0.08)
                  : Colors.white,
            ),
          ),
        ),
        if (_hasDateFilter) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: _clearDates,
            icon: const Icon(Icons.close, color: Colors.red),
            tooltip: 'Clear dates',
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.red.shade200),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBillList(AsyncValue<List<Bill>> billsAsync) {
    return billsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('ભૂલ: $e')),
      data: (bills) {
        if (bills.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_hasActiveFilters ? Icons.search : Icons.shopping_cart,
                    size: 42),
                const SizedBox(height: 8),
                Text(_hasActiveFilters
                    ? 'કોઈ બિલ મળ્યું નથી'
                    : 'હજુ કોઈ બિલ નથી'),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long,
                      size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    'કુલ બિલ: ${bills.length}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const Spacer(),
                  if (_hasActiveFilters)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _searchCtrl.clear();
                          _query = '';
                          _status = 'all';
                          _fromDate = null;
                          _toDate = null;
                        });
                      },
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text('રીસેટ ફિલ્ટર',
                          style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: Colors.red,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: bills.length,
                itemBuilder: (context, index) {
                  final bill = bills[index];
                  return _BillCard(bill: bill, onTap: () => _openBill(bill));
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Detail view ───────────────────────────────────────────────────────────

  Widget _buildDetailView() {
    return Column(
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _backToBillList,
              icon: const Icon(Icons.arrow_back),
              label: const Text('બિલ યાદી'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const Spacer(),
            SegmentedButton<String>(
              segments: [
                const ButtonSegment(value: 'return', label: Text('↩️ રિટર્ન')),
                ButtonSegment(
                  value: 'replace',
                  enabled: !_isFullyReturnedBill,
                  label:
                      Text('🔄 બદલો${_isFullyReturnedBill ? ' (બંધ)' : ''}'),
                ),
              ],
              selected: {_activeMode},
              onSelectionChanged: (val) {
                if (_isFullyReturnedBill) return;
                final newMode = val.first;
                setState(() => _activeMode = newMode);
                if (newMode == 'replace' && _catalogSearchResults.isEmpty) {
                  _loadCatalogProducts();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_isFullyReturnedBill) _buildFullyReturnedReadOnlyBanner(),
        const SizedBox(height: 10),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
        ],
        if (_isLoading) const LinearProgressIndicator(),
        Expanded(
          child: _activeMode == 'return'
              ? _buildReturnModeBody()
              : _buildReplaceModeBody(),
        ),
      ],
    );
  }

  Widget _buildFullyReturnedReadOnlyBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_clock_outlined,
              color: Color(0xFF475569), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'આ બિલ સંપૂર્ણ પરત થઈ ગયેલ છે (ફક્ત જોવા માટે)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'આ બિલનું સમગ્ર રિફંડ પ્રક્રિયા પૂર્ણ થયેલ છે. તેથી તેમાં કોઈ સુધારો કે ફેરફાર થઈ શકશે નહીં.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF94A3B8)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility_outlined,
                    size: 14, color: Color(0xFF475569)),
                SizedBox(width: 4),
                Text(
                  'Read-Only',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RETURN MODE BODY
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildReturnModeBody() {
    if (_billItems.isEmpty && !_isLoading) {
      return const Center(child: Text('આ બિલ માટે કોઈ ઉત્પાદન ઉપલબ્ધ નથી'));
    }

    return Column(
      children: [
        // Column headers
        _buildItemListHeader(),
        const SizedBox(height: 4),
        // Item rows
        Expanded(
          child: ListView.builder(
            itemCount: _billItems.length,
            itemBuilder: (ctx, i) => _buildReturnItemCard(_billItems[i]),
          ),
        ),
        // Pinned summary bar
        _buildReturnSummaryBar(),
      ],
    );
  }

  Widget _buildItemListHeader() {
    final anyReturnable = !_isFullyReturnedBill &&
        _billItems.any((e) => e.id != null && !e.isReturned && e.qty > 0);
    final hasAnyReturned = _returnedQtyMap.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const Expanded(
              flex: 4,
              child: Text('ઉત્પાદન',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          const Expanded(
              flex: 2,
              child: Text('માત્રા',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  textAlign: TextAlign.center)),
          const Expanded(
              flex: 2,
              child: Text('ભાવ',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  textAlign: TextAlign.center)),
          const Expanded(
              flex: 2,
              child: Text('કુલ',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  textAlign: TextAlign.end)),
          const SizedBox(width: 8),
          if (anyReturnable)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasAnyReturned)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _returnedQtyMap.clear();
                        for (final ctrl in _returnInputControllers.values) {
                          ctrl.clear();
                        }
                      });
                    },
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('બધા ક્લિયર',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _returnAllProducts,
                  icon: const Icon(Icons.done_all, size: 16),
                  label: const Text('બધા પરત',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            )
          else if (_isFullyReturnedBill)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: const Text(
                'પૂર્ણ પરત',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54),
              ),
            )
          else
            const SizedBox(width: 80),
        ],
      ),
    );
  }

  Widget _buildReturnItemCard(BillItem item) {
    if (item.id == null) return const SizedBox.shrink();

    final isExpanded = _expandedItemId == item.id;
    final committedQty = _returnedQtyMap[item.id] ?? 0.0;
    final hasCommittedReturn = committedQty > 0;
    final isFullyReturned = item.isReturned;
    final isLocked = _isFullyReturnedBill || isFullyReturned;

    final qtyDisplay = _formatQtyWithUnit(item.qty, item.unitTypeSnapshot);
    final priceDisplay =
        _formatRateWithUnit(item.sellPriceSnapshot ?? 0, item.unitTypeSnapshot);
    final displayName = (item.productNameSnapshot != null &&
            item.productNameSnapshot!.trim().isNotEmpty &&
            item.productNameSnapshot != '—' &&
            item.productNameSnapshot != '-')
        ? item.productNameSnapshot!
        : 'ઉત્પાદન #${item.productId}';

    Color cardColor = Colors.white;
    if (isFullyReturned) {
      cardColor = Colors.grey.shade100;
    } else if (isExpanded) {
      cardColor = const Color(0xFFE8F5E9);
    } else if (hasCommittedReturn) {
      cardColor = const Color(0xFFE3F2FD);
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      color: cardColor,
      elevation: isExpanded ? 3 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isExpanded
              ? Colors.green.shade400
              : hasCommittedReturn
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.divider,
          width: isExpanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Collapsed row ──────────────────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: isLocked ? null : () => _toggleExpandRow(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Product name + return badge
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            decoration: isFullyReturned
                                ? TextDecoration.lineThrough
                                : null,
                            color: isFullyReturned ? Colors.grey : null,
                          ),
                        ),
                        if (hasCommittedReturn && !isFullyReturned) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.undo,
                                  size: 14, color: AppColors.primary),
                              const SizedBox(width: 3),
                              Text(
                                'પરત: ${_formatQtyWithUnit(committedQty, item.unitTypeSnapshot)}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                        if (isFullyReturned) ...[
                          const SizedBox(height: 3),
                          const Text(
                            'પહેલેથી સંપૂર્ણ પરત',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Qty
                  Expanded(
                    flex: 2,
                    child: Text(
                      qtyDisplay,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isFullyReturned ? Colors.grey : null),
                    ),
                  ),
                  // Rate
                  Expanded(
                    flex: 2,
                    child: Text(
                      priceDisplay,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isFullyReturned
                              ? Colors.grey
                              : Colors.black87),
                    ),
                  ),
                  // Total amount
                  Expanded(
                    flex: 2,
                    child: Text(
                      formatCurrency(item.amount),
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: isFullyReturned ? Colors.grey : null,
                      ),
                    ),
                  ),
                  // Entire product return button / committed badge
                  if (!isLocked) ...[
                    const SizedBox(width: 8),
                    if (hasCommittedReturn)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Text(
                              (committedQty >= item.qty - 0.0001)
                                  ? '✓ સંપૂર્ણ પરત'
                                  : '✓ પરત: ${_formatQtyWithUnit(committedQty, item.unitTypeSnapshot)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                size: 18, color: Colors.red),
                            tooltip: 'પરત રદ કરો',
                            splashRadius: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _clearRowReturn(item),
                          ),
                        ],
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: () => _returnEntireProduct(item),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('સંપૂર્ણ પરત',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          elevation: 0,
                        ),
                      ),
                  ],
                  // Expand indicator
                  if (!isLocked) ...[
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 22,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Expanded inline input panel ────────────────────────────────
          if (isExpanded && !isLocked)
            _buildInlineReturnPanel(item),
        ],
      ),
    );
  }

  Widget _buildInlineReturnPanel(BillItem item) {
    final ctrl = _returnInputControllers[item.id!];
    final error = _returnInputErrors[item.id];
    final u = _unitName(item.unitTypeSnapshot);
    final isKilo = _isKilo(item.unitTypeSnapshot);
    final isGram = _isGram(item.unitTypeSnapshot);
    final isLiter = _isLiter(item.unitTypeSnapshot);

    // Live calculation from what user has typed
    final rawText = ctrl?.text.trim() ?? '';
    final rawInput = double.tryParse(rawText) ?? 0.0;
    final receivedBase = _parseReceivedBaseQty(rawInput, item);
    final isValid = receivedBase != null && receivedBase > 0 && receivedBase <= item.qty + 0.0001;
    final remainingBase =
        isValid ? (item.qty - receivedBase).clamp(0.0, double.maxFinite) : item.qty;
    final refundAmount =
        isValid ? receivedBase * (item.sellPriceSnapshot ?? 0) : 0.0;

    final maxDisplay = _formatQtyWithUnit(item.qty, item.unitTypeSnapshot);
    final remainingDisplay = _formatQtyWithUnit(remainingBase, item.unitTypeSnapshot);

    final String labelText;
    final String hintText;
    final String suffixText;

    if (isKilo) {
      labelText = 'પરત આપેલ વજન';
      hintText = 'ગ્રામ અથવા કિલો માં (દા.ત. 500 અથવા 0.5)';
      suffixText = 'કિલો / ગ્રામ';
    } else if (isGram) {
      labelText = 'પરત આપેલ વજન (ગ્રામ)';
      hintText = 'ગ્રામ માં (દા.ત. 100)';
      suffixText = 'ગ્રામ';
    } else if (isLiter) {
      labelText = 'પરત આપેલ માત્રા (લીટર)';
      hintText = 'લીટર માં (દા.ત. 1 અથવા 0.5)';
      suffixText = 'લીટર';
    } else {
      labelText = 'પરત આપેલ માત્રા ($u)';
      hintText = '$u માં (દા.ત. 1)';
      suffixText = u;
    }

    return Container(
      margin: const EdgeInsets.only(top: 0),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: Colors.green.shade200, width: 1)),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),

          // ── Info strip ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ઉપલબ્ધ:  $maxDisplay',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isKilo
                            ? 'ભાવ:  ₹${(item.sellPriceSnapshot ?? 0).toStringAsFixed(2)} / $u'
                                '  =  ₹${((item.sellPriceSnapshot ?? 0) / 1000).toStringAsFixed(4)} / ગ્રામ'
                            : 'ભાવ:  ${_formatRateWithUnit(item.sellPriceSnapshot ?? 0, item.unitTypeSnapshot)}',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade800),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _returnEntireProduct(item),
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: const Text('સંપૂર્ણ પરત',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Input field ───────────────────────────────────────────────────
          TextField(
            controller: ctrl,
            focusNode: _getOrCreateFocusNode(item.id!),
            autofocus: true,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _confirmRowReturn(item),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: labelText,
              hintText: hintText,
              suffixText: suffixText,
              labelStyle: const TextStyle(fontSize: 14),
              border: const OutlineInputBorder(),
              errorText: error,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
            ),
          ),

          const SizedBox(height: 10),

          // ── Live result display ───────────────────────────────────────────
          if (isValid) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'પરત: ${_formatQtyWithUnit(receivedBase, item.unitTypeSnapshot)}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'રિફંડ: ${formatCurrency(refundAmount)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'બિલ પર બાકી:  $remainingDisplay',
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // ── Action buttons ────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _clearRowReturn(item),
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('ક્લિયર', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _confirmRowReturn(item),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('સાચવો', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReturnSummaryBar() {
    final mode = ref.watch(returnModeProvider);
    final hasAny = _returnedQtyMap.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Bill total + refund info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'બિલ ટોટલ:  ${formatCurrency(_billGrandTotal)}',
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'રિફંડ:  ${formatCurrency(_totalRefundAmount)}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: hasAny ? Colors.green.shade700 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              // Mode selector (hidden if fully returned)
              if (!_isFullyReturnedBill)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('રિફંડ મોડ:',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    DropdownButton<String>(
                      value: mode,
                      isDense: true,
                      items: const [
                        DropdownMenuItem(
                            value: 'cash_refund', child: Text('💵 કેશ')),
                        DropdownMenuItem(
                            value: 'khata_credit',
                            child: Text('📒 ખાતા જમા')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          ref.read(returnModeProvider.notifier).state = v;
                        }
                      },
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_isFullyReturnedBill)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 20, color: Color(0xFF475569)),
                  SizedBox(width: 8),
                  Text(
                    'આ બિલ સંપૂર્ણ પરત થયેલ હોવાથી નવો ફેરફાર શક્ય નથી (ફક્ત જોવા માટે)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: (_isLoading || !hasAny) ? null : _confirmReturn,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  hasAny
                      ? 'Return Process કરો  (${formatCurrency(_totalRefundAmount)})'
                      : 'Return Process કરો',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REPLACE MODE BODY
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildReplaceModeBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 5, child: _buildReplaceCatalogPanel()),
              const VerticalDivider(width: 20, thickness: 1.5),
              Expanded(flex: 7, child: _buildReplaceCartPanel()),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 5, child: _buildReplaceCatalogPanel()),
            const VerticalDivider(width: 12, thickness: 1),
            Expanded(flex: 6, child: _buildReplaceCartPanel()),
          ],
        );
      },
    );
  }

  Widget _buildReplaceCatalogPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.inventory_2_outlined,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Text(
              'ઉત્પાદન યાદી',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Spacer(),
            if (_catalogSearchResults.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'કુલ: ${_catalogSearchResults.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _catalogSearchCtrl,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'ઉત્પાદન શોધો (ગુજરાતી / અંગ્રેજી / બારકોડ)...',
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            suffixIcon: _catalogSearchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _catalogSearchCtrl.clear();
                      _loadCatalogProducts(query: '');
                    },
                  )
                : null,
          ),
          onChanged: (v) => _scheduleCatalogSearch(v),
        ),
        const SizedBox(height: 8),
        if (_isSearchingCatalog) const LinearProgressIndicator(),
        Expanded(
          child: _catalogSearchResults.isEmpty
              ? Center(
                  child: Text(
                    _isSearchingCatalog
                        ? 'ઉત્પાદનો લોડ થઈ રહ્યા છે...'
                        : 'કોઈ ઉત્પાદન મળ્યું નથી',
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.separated(
                  itemCount: _catalogSearchResults.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final p = _catalogSearchResults[index];
                    final u = _unitName(p.unitType);
                    return Card(
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(
                            color: Color(0xFFCBD5E1), width: 1.2),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _onSelectProductForReplace(p),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.nameGujarati,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '₹${p.sellPrice.toStringAsFixed(2)} / $u',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.green.shade700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: (p.stockQty <= 0)
                                                ? Colors.red.shade50
                                                : (p.isLowStock
                                                    ? Colors.orange.shade50
                                                    : Colors.blue.shade50),
                                            borderRadius:
                                                BorderRadius.circular(5),
                                            border: Border.all(
                                              color: (p.stockQty <= 0)
                                                  ? Colors.red.shade300
                                                  : (p.isLowStock
                                                      ? Colors.orange.shade300
                                                      : Colors.blue.shade300),
                                            ),
                                          ),
                                          child: Text(
                                            'સ્ટોક: ${p.stockQty % 1 == 0 ? p.stockQty.toInt() : p.stockQty.toStringAsFixed(2)} $u',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: (p.stockQty <= 0)
                                                  ? Colors.red.shade700
                                                  : (p.isLowStock
                                                      ? Colors.orange.shade800
                                                      : Colors.blue.shade700),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.add_circle_outline,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReplaceCartPanel() {
    final diff = _replacePriceDiff;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('બદલી બિલ વિગત:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('જૂનું ટોટલ: ${formatCurrency(_originalBillTotal)}',
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _replaceCartItems.isEmpty
              ? const Center(child: Text('કોઈ ઉત્પાદન નથી'))
              : ListView.builder(
                  itemCount: _replaceCartItems.length,
                  itemBuilder: (context, index) {
                    final item = _replaceCartItems[index];
                    final u = _unitName(item.unitTypeSnapshot);
                    final qtyDisplay =
                        _formatQtyWithUnit(item.qty, item.unitTypeSnapshot);
                    final displayName = (item.productNameSnapshot != null &&
                            item.productNameSnapshot!.trim().isNotEmpty &&
                            item.productNameSnapshot != '—' &&
                            item.productNameSnapshot != '-')
                        ? item.productNameSnapshot!
                        : 'ઉત્પાદન #${item.productId}';
                    return Card(
                      child: ListTile(
                        title: Text(displayName),
                        subtitle: Text(
                            '$qtyDisplay  ×  ₹${(item.sellPriceSnapshot ?? 0).toStringAsFixed(2)} / $u'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(formatCurrency(item.amount),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 20, color: Colors.red),
                              tooltip: 'દૂર કરો',
                              onPressed: () => setState(
                                  () => _replaceCartItems.removeAt(index)),
                            ),
                          ],
                        ),
                        onTap: () => _editReplaceCartItem(index),
                      ),
                    );
                  },
                ),
        ),
        const Divider(),
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('નવું ટોટલ:'),
                Text(formatCurrency(_newReplaceTotal),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ભાવ ફરક:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  diff.abs() < 0.01
                      ? '₹0.00'
                      : diff > 0
                          ? 'ગ્રાહક ₹${diff.toStringAsFixed(2)} વધુ આપે'
                          : 'દુકાનદારે ₹${(-diff).toStringAsFixed(2)} આપવાના',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: diff > 0
                        ? Colors.green
                        : (diff < 0 ? Colors.red : Colors.black),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('મોડ: '),
                DropdownButton<String>(
                  value: ref.watch(replaceModeProvider),
                  items: const [
                    DropdownMenuItem(value: 'cash_refund', child: Text('💵 કેશ')),
                    DropdownMenuItem(
                        value: 'khata_credit', child: Text('📒 ખાતા જમા')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(replaceModeProvider.notifier).state = v;
                    }
                  },
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isLoading ? null : _confirmReplace,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12)),
                  child: const Text('બદલી સાચવો'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BILL CARD (Bill selection list)
// ═══════════════════════════════════════════════════════════════════════════

class _BillCard extends StatelessWidget {
  const _BillCard({required this.bill, required this.onTap});

  final Bill bill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isReturned = bill.paymentStatus == 'fully_returned';
    final customerName =
        (bill.customerNameSnapshot?.trim().isNotEmpty ?? false)
            ? bill.customerNameSnapshot!
            : 'અજ્ઞાત ગ્રાહક';
    final dateText = _formatDate(bill.billDate);

    final normalized = (bill.paymentStatus ?? '').trim();
    final (statusLabel, statusColor, statusBg) = switch (normalized) {
      'paid' => ('ચૂકવાયું', const Color(0xFF16A34A), const Color(0xFFDCFCE7)),
      'partial' => ('આંશિક', const Color(0xFFD97706), const Color(0xFFFEF3C7)),
      'partial_return' =>
        ('આંશિક પરત', const Color(0xFF2563EB), const Color(0xFFDBEAFE)),
      'fully_returned' =>
        ('પૂર્ણ પરત', const Color(0xFF475569), const Color(0xFFF1F5F9)),
      _ => (
        normalized.isEmpty ? 'અજ્ઞાત' : normalized,
        const Color(0xFF64748B),
        const Color(0xFFF8FAFC)
      ),
    };

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isReturned
              ? const Color(0xFFCBD5E1)
              : statusColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: statusColor,
                width: 5,
              ),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      isReturned
                          ? Icons.assignment_turned_in_outlined
                          : Icons.receipt_long,
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'બિલ #${bill.billNumber}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            if (isReturned) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: const Color(0xFF94A3B8)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.visibility,
                                        size: 11, color: Color(0xFF475569)),
                                    SizedBox(width: 3),
                                    Text(
                                      'ફક્ત જોવા માટે',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.person_outline,
                                size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.calendar_today_outlined,
                                size: 13, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              dateText,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _StatusBadge(status: bill.paymentStatus),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          formatCurrency(bill.totalAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isReturned ? 'વિગત જુઓ' : 'પસંદ કરો',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isReturned
                                  ? const Color(0xFF475569)
                                  : AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: isReturned
                                ? const Color(0xFF475569)
                                : AppColors.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String rawDate) {
    final parsed = DateTime.tryParse(rawDate);
    if (parsed != null) {
      return DateFormat('dd/MM/yyyy').format(parsed.toLocal());
    }
    final intEpoch = int.tryParse(rawDate);
    if (intEpoch != null) {
      return DateFormat('dd/MM/yyyy')
          .format(DateTime.fromMillisecondsSinceEpoch(intEpoch).toLocal());
    }
    return rawDate;
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final normalized = (status ?? '').trim();
    final (label, color, bg) = switch (normalized) {
      'paid' => ('ચૂકવાયું', const Color(0xFF16A34A), const Color(0xFFDCFCE7)),
      'partial' => ('આંશિક', const Color(0xFFD97706), const Color(0xFFFEF3C7)),
      'partial_return' =>
        ('આંશિક પરત', const Color(0xFF2563EB), const Color(0xFFDBEAFE)),
      'fully_returned' =>
        ('પૂર્ણ પરત', const Color(0xFF475569), const Color(0xFFF1F5F9)),
      _ => (
        normalized.isEmpty ? 'અજ્ઞાત' : normalized,
        const Color(0xFF64748B),
        const Color(0xFFF8FAFC)
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
