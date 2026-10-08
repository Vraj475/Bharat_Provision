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
  // Map of billItemId -> committed returnedQty (base unit: kg or pcs)
  final Map<int, double> _returnedQtyMap = {};

  // Which item row is currently expanded for inline input
  int? _expandedItemId;

  // Per-item text controllers for the inline return input (key = billItemId)
  final Map<int, TextEditingController> _returnInputControllers = {};

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
      });
      return ctrl;
    });
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
      _searchCatalog(q);
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

  // ─── Unit helper ───────────────────────────────────────────────────────────

  bool _isWeightUnit(String? unitType) => ReturnRepository.isWeightUnit(unitType);

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

  // ─── Inline return row logic ───────────────────────────────────────────────

  void _toggleExpandRow(BillItem item) {
    if (item.id == null || item.isReturned) return;
    setState(() {
      if (_expandedItemId == item.id) {
        _expandedItemId = null; // collapse
      } else {
        _expandedItemId = item.id;
        _returnInputErrors[item.id!] = null;
        // Pre-fill controller with committed value (if any)
        final ctrl = _returnInputControllers[item.id!];
        if (ctrl != null) {
          final committed = _returnedQtyMap[item.id] ?? 0.0;
          if (committed > 0) {
            final isWeight = _isWeightUnit(item.unitTypeSnapshot);
            ctrl.text = isWeight
                ? (committed * 1000).toStringAsFixed(0)
                : committed.toStringAsFixed(0);
          }
          // else leave as-is (user's WIP text)
        }
      }
    });
  }

  void _fillFullReturn(BillItem item) {
    final ctrl = _returnInputControllers[item.id!];
    if (ctrl == null) return;
    final isWeight = _isWeightUnit(item.unitTypeSnapshot);
    setState(() {
      ctrl.text = isWeight
          ? (item.qty * 1000).toStringAsFixed(0)
          : item.qty.toStringAsFixed(0);
      _returnInputErrors[item.id!] = null;
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

    final isWeight = _isWeightUnit(item.unitTypeSnapshot);

    if (!isWeight && rawInput % 1 != 0) {
      setState(() => _returnInputErrors[item.id!] =
          'નંગ માટે પૂર્ણ સંખ્યા (whole number) દાખલ કરો');
      return;
    }

    final receivedBase = isWeight ? rawInput / 1000.0 : rawInput;

    if (receivedBase > item.qty + 0.0001) {
      final maxDisplay = isWeight
          ? '${(item.qty * 1000).toStringAsFixed(0)} g'
          : '${item.qty.toStringAsFixed(0)} pcs';
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
      if (_selectedBill?.id != null) {
        await _loadBillItems(_selectedBill!.id!);
      }
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

  Future<void> _searchCatalog(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _catalogSearchResults = []);
      return;
    }
    setState(() => _isSearchingCatalog = true);
    try {
      final repo = ref.read(returnRepositoryProvider);
      final results = await repo.getProducts(query: q);
      if (!mounted) return;
      setState(() => _catalogSearchResults = results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'ઉત્પાદન શોધવામાં ભૂલ: $e');
    } finally {
      if (mounted) setState(() => _isSearchingCatalog = false);
    }
  }

  void _addCatalogProductToReplace(Product p) {
    setState(() {
      final existingIndex =
          _replaceCartItems.indexWhere((i) => i.productId == p.id);
      if (existingIndex >= 0) {
        final existing = _replaceCartItems[existingIndex];
        final newQty = existing.qty + 1.0;
        _replaceCartItems[existingIndex] = BillItem(
          id: existing.id,
          billId: existing.billId,
          productId: existing.productId,
          productNameSnapshot: existing.productNameSnapshot,
          unitTypeSnapshot: existing.unitTypeSnapshot,
          sellPriceSnapshot: existing.sellPriceSnapshot,
          qty: newQty,
          amount: newQty * (existing.sellPriceSnapshot ?? 0),
          isReturned: existing.isReturned,
        );
      } else {
        _replaceCartItems.add(BillItem(
          billId: _selectedBill?.id ?? 0,
          productId: p.id!,
          productNameSnapshot: p.nameGujarati,
          unitTypeSnapshot: p.unitType,
          sellPriceSnapshot: p.sellPrice,
          qty: 1.0,
          amount: p.sellPrice,
          isReturned: false,
        ));
      }
    });
  }

  void _editReplaceCartItem(int index) {
    final item = _replaceCartItems[index];
    final isWeight = _isWeightUnit(item.unitTypeSnapshot);
    final qtyCtrl = TextEditingController(
      text: isWeight
          ? (item.qty * 1000).toStringAsFixed(0)
          : item.qty.toStringAsFixed(0),
    );
    final priceCtrl = TextEditingController(
      text: (item.sellPriceSnapshot ?? 0).toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDlg) => AlertDialog(
          title: Text('${item.productNameSnapshot} સુધારો'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isWeight ? 'વજન (ગ્રામ)' : 'માત્રા (નંગ)',
                  suffixText: isWeight ? 'g' : 'pcs',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'ભાવ (₹ / kg or pcs)',
                  border: OutlineInputBorder(),
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
                final finalQty = isWeight ? rawQty / 1000.0 : rawQty;
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
      if (_selectedBill?.id != null) {
        await _loadBillItems(_selectedBill!.id!);
      }
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: _selectedBill == null
            ? _buildBillSelectionView(billsAsync)
            : _buildDetailView(),
      ),
    );
  }

  // ─── Bill selection view ───────────────────────────────────────────────────

  Widget _buildBillSelectionView(AsyncValue<List<Bill>> billsAsync) {
    return Column(
      children: [
        TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'બિલ નંબર, ગ્રાહકનું નામ, અથવા રકમ શોધો',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _scheduleSearch(),
        ),
        const SizedBox(height: 10),
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
      'udhaar': 'ઉધાર',
      'partial': 'આંશિક',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: statuses.entries.map((entry) {
        final selected = _status == entry.key;
        return ChoiceChip(
          label: Text(entry.value),
          selected: selected,
          selectedColor: AppColors.primaryLight,
          backgroundColor: Colors.white,
          labelStyle: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
          side: const BorderSide(color: AppColors.divider),
          onSelected: (_) => setState(() => _status = entry.key),
        );
      }).toList(),
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
            icon: const Icon(Icons.date_range),
            label: Text(fromLabel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _pickToDate,
            icon: const Icon(Icons.date_range),
            label: Text(toLabel),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _clearDates,
          icon: const Icon(Icons.close),
          tooltip: 'Clear dates',
        ),
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
        return ListView.builder(
          controller: _scrollController,
          itemCount: bills.length,
          itemBuilder: (context, index) {
            final bill = bills[index];
            return _BillCard(bill: bill, onTap: () => _openBill(bill));
          },
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
            ),
            const Spacer(),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'return', label: Text('↩️ રિટર્ન')),
                ButtonSegment(value: 'replace', label: Text('🔄 બદલો')),
              ],
              selected: {_activeMode},
              onSelectionChanged: (val) =>
                  setState(() => _activeMode = val.first),
            ),
          ],
        ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Expanded(flex: 5, child: Text('ઉત્પાદન', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 2, child: Text('માત્રા', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text('ભાવ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text('કુલ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _buildReturnItemCard(BillItem item) {
    if (item.id == null) return const SizedBox.shrink();

    final isWeight = _isWeightUnit(item.unitTypeSnapshot);
    final isExpanded = _expandedItemId == item.id;
    final committedQty = _returnedQtyMap[item.id] ?? 0.0;
    final hasCommittedReturn = committedQty > 0;
    final isFullyReturned = item.isReturned;

    // Display strings for the collapsed card
    final qtyDisplay = isWeight
        ? '${(item.qty * 1000).toStringAsFixed(0)} g'
        : '${item.qty.toStringAsFixed(0)} pcs';
    final priceDisplay = isWeight
        ? '₹${(item.sellPriceSnapshot ?? 0).toStringAsFixed(0)}/kg'
        : '₹${(item.sellPriceSnapshot ?? 0).toStringAsFixed(2)}/pcs';

    Color cardColor = Colors.white;
    if (isFullyReturned) {
      cardColor = Colors.grey.shade100;
    } else if (isExpanded) {
      cardColor = const Color(0xFFE8F5E9);
    } else if (hasCommittedReturn) {
      cardColor = const Color(0xFFE3F2FD);
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
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
            onTap: isFullyReturned ? null : () => _toggleExpandRow(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Product name + return badge
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productNameSnapshot ?? '—',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            decoration: isFullyReturned
                                ? TextDecoration.lineThrough
                                : null,
                            color: isFullyReturned ? Colors.grey : null,
                          ),
                        ),
                        if (hasCommittedReturn && !isFullyReturned) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.undo, size: 12, color: AppColors.primary),
                              const SizedBox(width: 2),
                              Text(
                                isWeight
                                    ? 'પરત: ${(committedQty * 1000).toStringAsFixed(0)} g'
                                    : 'પરત: ${committedQty.toStringAsFixed(0)} pcs',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                        if (isFullyReturned) ...[
                          const SizedBox(height: 2),
                          const Text(
                            'પહેલેથી સંપૂર્ણ પરત',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
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
                          fontSize: 13,
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
                          fontSize: 12,
                          color: isFullyReturned
                              ? Colors.grey
                              : Colors.black54),
                    ),
                  ),
                  // Total amount
                  Expanded(
                    flex: 2,
                    child: Text(
                      formatCurrency(item.amount),
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isFullyReturned ? Colors.grey : null,
                      ),
                    ),
                  ),
                  // Expand indicator
                  if (!isFullyReturned) ...[
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Expanded inline input panel ────────────────────────────────
          if (isExpanded && !isFullyReturned)
            _buildInlineReturnPanel(item, isWeight),
        ],
      ),
    );
  }

  Widget _buildInlineReturnPanel(BillItem item, bool isWeight) {
    final ctrl = _returnInputControllers[item.id!];
    final error = _returnInputErrors[item.id];

    // Live calculation from what user has typed
    final rawText = ctrl?.text.trim() ?? '';
    final rawInput = double.tryParse(rawText) ?? 0.0;
    final receivedBase = isWeight ? rawInput / 1000.0 : rawInput;
    final isValid = rawInput > 0 && receivedBase <= item.qty + 0.0001;
    final remainingBase =
        isValid ? (item.qty - receivedBase).clamp(0.0, double.maxFinite) : item.qty;
    final refundAmount =
        isValid ? receivedBase * (item.sellPriceSnapshot ?? 0) : 0.0;

    final maxDisplay = isWeight
        ? '${(item.qty * 1000).toStringAsFixed(0)} g  (${item.qty.toStringAsFixed(3)} kg)'
        : '${item.qty.toStringAsFixed(0)} pcs';
    final remainingDisplay = isWeight
        ? '${(remainingBase * 1000).toStringAsFixed(0)} g  (${remainingBase.toStringAsFixed(3)} kg)'
        : '${remainingBase.toStringAsFixed(0)} pcs';

    return Container(
      margin: const EdgeInsets.only(top: 0),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isWeight
                            ? 'ભાવ:  ₹${(item.sellPriceSnapshot ?? 0).toStringAsFixed(2)}/kg'
                                '  =  ₹${((item.sellPriceSnapshot ?? 0) / 1000).toStringAsFixed(4)}/g'
                            : 'ભાવ:  ₹${(item.sellPriceSnapshot ?? 0).toStringAsFixed(2)}/pcs',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _fillFullReturn(item),
                  icon: const Icon(Icons.select_all, size: 14),
                  label: const Text('સંપૂર્ણ', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Input field ───────────────────────────────────────────────────
          TextField(
            controller: ctrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: isWeight
                  ? 'ગ્રાહકે આપેલ વજન'
                  : 'ગ્રાહકે આપેલ નંગ',
              hintText: isWeight ? 'ગ્રામ માં (દા.ત. 728)' : 'નંગ (દા.ત. 2)',
              suffixText: isWeight ? 'grams' : 'pcs',
              border: const OutlineInputBorder(),
              errorText: error,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
            ),
          ),

          const SizedBox(height: 10),

          // ── Live result display ───────────────────────────────────────────
          if (isValid) ...[
            Container(
              padding: const EdgeInsets.all(10),
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
                        isWeight
                            ? 'પરત:  ${rawInput.toStringAsFixed(0)} g'
                            : 'પરત:  ${rawInput.toStringAsFixed(0)} pcs',
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        'રિફંડ: ${formatCurrency(refundAmount)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'બિલ પર બાકી:  $remainingDisplay',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade700),
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
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('ક્લિયર'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _confirmRowReturn(item),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('સાચવો'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
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
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'રિફંડ:  ${formatCurrency(_totalRefundAmount)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: hasAny ? Colors.green.shade700 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              // Mode selector
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('રિફંડ મોડ:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  DropdownButton<String>(
                    value: mode,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(
                          value: 'cash_refund', child: Text('💵 કેશ')),
                      DropdownMenuItem(
                          value: 'udhaar_credit', child: Text('📒 ઉધાર ક્રેડિટ')),
                    ],
                    onChanged: (v) {
                      if (v != null) ref.read(returnModeProvider.notifier).state = v;
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
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
                style: const TextStyle(fontSize: 15),
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
              const VerticalDivider(width: 16),
              Expanded(flex: 7, child: _buildReplaceCartPanel()),
            ],
          );
        }
        return Column(
          children: [
            Expanded(flex: 5, child: _buildReplaceCatalogPanel()),
            const Divider(),
            Expanded(flex: 7, child: _buildReplaceCartPanel()),
          ],
        );
      },
    );
  }

  Widget _buildReplaceCatalogPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _catalogSearchCtrl,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'ઉત્પાદન શોધો (ગુજરાતી / બારકોડ)',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => _scheduleCatalogSearch(v),
        ),
        const SizedBox(height: 8),
        if (_isSearchingCatalog) const LinearProgressIndicator(),
        Expanded(
          child: _catalogSearchResults.isEmpty
              ? const Center(child: Text('ઉત્પાદન ઉમેરવા માટે શોધો'))
              : ListView.builder(
                  itemCount: _catalogSearchResults.length,
                  itemBuilder: (context, index) {
                    final p = _catalogSearchResults[index];
                    return ListTile(
                      title: Text(p.nameGujarati,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          'ભાવ: ₹${p.sellPrice.toStringAsFixed(2)} / ${p.unitType} | સ્ટોક: ${p.stockQty}'),
                      trailing: ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('ઉમેરો'),
                        onPressed: () => _addCatalogProductToReplace(p),
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
                    final isWeight = _isWeightUnit(item.unitTypeSnapshot);
                    final qtyDisplay = isWeight
                        ? '${(item.qty * 1000).toStringAsFixed(0)} g'
                        : '${item.qty.toStringAsFixed(0)} pcs';
                    return Card(
                      child: ListTile(
                        title: Text(item.productNameSnapshot ?? ''),
                        subtitle: Text(
                            '$qtyDisplay  ×  ₹${(item.sellPriceSnapshot ?? 0).toStringAsFixed(2)}'),
                        trailing: Text(formatCurrency(item.amount),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
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
                        value: 'udhaar_credit', child: Text('📒 ઉધાર')),
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

    return Opacity(
      opacity: isReturned ? 0.5 : 1,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.divider, width: 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isReturned ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'બિલ નં. ${bill.billNumber}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(dateText,
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(customerName,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 8),
                      _StatusBadge(status: bill.paymentStatus),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatCurrency(bill.totalAmount),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    if (isReturned) ...[
                      const SizedBox(height: 6),
                      const Text('પહેલેથી પરત',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ],
                ),
              ],
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
    final (label, color) = switch (normalized) {
      'paid' => ('ચૂકવાયું', Colors.green),
      'udhaar' => ('ઉધાર', Colors.orange),
      'partial' => ('આંશિક', Colors.amber),
      'partial_return' => ('આંશિક પરત', Colors.blue),
      'fully_returned' => ('પૂર્ણ પરત', Colors.grey),
      _ => (normalized.isEmpty ? 'અજ્ઞાત' : normalized, Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
