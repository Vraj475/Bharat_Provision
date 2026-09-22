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
  // Map of billItemId -> returnedQty
  final Map<int, double> _returnedQtyMap = {};

  // --- REPLACE MODE STATE ---
  // List of items in the replace cart
  List<BillItem> _replaceCartItems = [];
  final _catalogSearchCtrl = TextEditingController();
  List<Product> _catalogSearchResults = [];
  bool _isSearchingCatalog = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _scrollController.dispose();
    _catalogSearchCtrl.dispose();
    super.dispose();
  }

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

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _fromDate = picked);
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _toDate = picked);
    }
  }

  void _clearDates() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
  }

  Future<void> _openBill(Bill bill) async {
    setState(() {
      _selectedBill = bill;
      _error = null;
      _activeMode = 'return';
      _returnedQtyMap.clear();
      _replaceCartItems = [];
    });
    await _loadBillItems(bill.id!);
  }

  void _backToBillList() {
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
    try {
      final repo = ref.read(returnRepositoryProvider);
      final items = await repo.getBillItems(billId);
      if (!mounted) return;
      setState(() {
        _billItems = items;
        // Clone items for replace cart
        _replaceCartItems = items.map((e) => BillItem(
          id: e.id,
          billId: e.billId,
          productId: e.productId,
          productNameSnapshot: e.productNameSnapshot,
          unitTypeSnapshot: e.unitTypeSnapshot,
          sellPriceSnapshot: e.sellPriceSnapshot,
          qty: e.qty,
          amount: e.amount,
          isReturned: e.isReturned,
        )).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _isWeightUnit(String? unitType) {
    if (unitType == null) return false;
    final u = unitType.trim().toLowerCase();
    return u == 'weight_kg' ||
        u == 'weight_gram' ||
        u.contains('કિલો') ||
        u == 'kg' ||
        u.contains('kilo') ||
        u.contains('ગ્રામ') ||
        u == 'g' ||
        u.contains('gram');
  }

  // --- RETURN LOGIC ---
  double get _totalRefundAmount {
    double total = 0;
    for (final item in _billItems) {
      final retQty = _returnedQtyMap[item.id] ?? 0;
      total += retQty * (item.sellPriceSnapshot ?? 0);
    }
    return total;
  }

  void _openReturnDialog(BillItem item) {
    showDialog(
      context: context,
      builder: (ctx) => _ReturnItemDialog(
        item: item,
        initialReturnedQty: _returnedQtyMap[item.id] ?? 0,
        isWeightProduct: _isWeightUnit(item.unitTypeSnapshot),
        onSave: (returnedQty) {
          setState(() {
            if (returnedQty > 0) {
              _returnedQtyMap[item.id!] = returnedQty;
            } else {
              _returnedQtyMap.remove(item.id);
            }
          });
        },
      ),
    );
  }

  Future<void> _confirmReturn() async {
    if (_selectedBill == null) return;
    if (_returnedQtyMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('મહેરબાની કરીને પરત કરવા માટે કમ સે કમ એક ઉત્પાદન પસંદ કરો')),
      );
      return;
    }

    final lines = <ReturnLine>[];
    for (final item in _billItems) {
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
            Text('કુલ રિફંડ રકમ: ${formatCurrency(_totalRefundAmount)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('મોડ: ${mode == 'cash_refund' ? 'કેશ રિફંડ' : 'ઉધાર ક્રેડિટ'}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('રદ')),
          ElevatedButton(
            onPressed: () => ctx.pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('પરત સફળતાપૂર્વક લેવાયું અને માલ સ્ટોક અપડેટ થયો')),
      );
      await _loadBillItems(_selectedBill!.id!);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- REPLACE LOGIC ---
  double get _originalBillTotal => _selectedBill?.totalAmount ?? 0.0;
  double get _newReplaceTotal => _replaceCartItems.fold(0.0, (sum, i) => sum + i.amount);
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
      // ignore
    } finally {
      if (mounted) setState(() => _isSearchingCatalog = false);
    }
  }

  void _addCatalogProductToReplace(Product p) {
    setState(() {
      final existingIndex = _replaceCartItems.indexWhere((i) => i.productId == p.id);
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
      text: isWeight ? (item.qty * 1000).toStringAsFixed(0) : item.qty.toStringAsFixed(0),
    );
    final priceCtrl = TextEditingController(
      text: (item.sellPriceSnapshot ?? 0).toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${item.productNameSnapshot} સુધારો'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: isWeight ? 'માત્રા / વજન (ગ્રામ માં)' : 'માત્રા (નંગ)',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'ભાવ (₹)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ctx.pop();
              setState(() {
                _replaceCartItems.removeAt(index);
              });
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
    );
  }

  Future<void> _confirmReplace() async {
    if (_selectedBill == null) return;
    if (_replaceCartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('બદલી બિલમાં ઓછામાં ઓછું એક ઉત્પાદન હોવું જોઇએ')),
      );
      return;
    }

    final mode = ref.read(returnModeProvider);
    final diff = _replacePriceDiff;
    String diffText = '₹0.00 (સરખું રકમ)';
    if (diff > 0) {
      diffText = 'ગ્રાહકે ₹${diff.toStringAsFixed(2)} વધુ ચૂકવશે';
    } else if (diff < 0) {
      diffText = 'દુકાનદારે ₹${(-diff).toStringAsFixed(2)} રિફંડ કરવાના રહેશે';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('બિલ બદલી ની ખાતરી કરો'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('જૂનું બિલ ટોટલ: ${formatCurrency(_originalBillTotal)}'),
            Text('નવું બદલી બિલ ટોટલ: ${formatCurrency(_newReplaceTotal)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(diffText, style: TextStyle(fontWeight: FontWeight.bold, color: diff > 0 ? Colors.green : (diff < 0 ? Colors.red : Colors.black))),
            const SizedBox(height: 8),
            Text('મોડ: ${mode == 'cash_refund' ? 'કેશ' : 'ઉધાર'}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('રદ')),
          ElevatedButton(
            onPressed: () => ctx.pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('બિલ સફળતાપૂર્વક બદલાયું અને માલ સ્ટોક અપડેટ થયો')),
      );
      await _loadBillItems(_selectedBill!.id!);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(returnBillListProvider(_queryParams));

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedBill == null ? 'રિટર્ન / બદલો' : 'બિલ નંબર: ${_selectedBill!.billNumber}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: _selectedBill == null
            ? _buildBillSelectionView(billsAsync)
            : _buildDetailView(),
      ),
    );
  }

  // --- BILL SELECTION VIEW ---
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
          onSelected: (_) {
            setState(() {
              _status = entry.key;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildDateRow() {
    final fromLabel = _fromDate == null ? 'તારીખ થી' : DateFormat('dd/MM/yyyy').format(_fromDate!);
    final toLabel = _toDate == null ? 'તારીખ સુધી' : DateFormat('dd/MM/yyyy').format(_toDate!);

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
                Icon(_hasActiveFilters ? Icons.search : Icons.shopping_cart, size: 42),
                const SizedBox(height: 8),
                Text(_hasActiveFilters ? 'કોઈ બિલ મળ્યું નથી' : 'હજુ કોઈ બિલ નથી'),
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

  // --- DETAIL VIEW WITH MODE SWITCH ---
  Widget _buildDetailView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top action bar
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _backToBillList,
              icon: const Icon(Icons.arrow_back),
              label: const Text('બિલ યાદી'),
            ),
            const Spacer(),
            // Mode Toggle Switch
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'return',
                  label: Text('↩️ રિટર્ન'),
                ),
                ButtonSegment(
                  value: 'replace',
                  label: Text('🔄 બદલો'),
                ),
              ],
              selected: {_activeMode},
              onSelectionChanged: (val) {
                setState(() {
                  _activeMode = val.first;
                });
              },
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

  // --- MODE A: RETURN BODY ---
  Widget _buildReturnModeBody() {
    if (_billItems.isEmpty && !_isLoading) {
      return const Center(child: Text('આ બિલ માટે કોઈ ઉત્પાદન ઉપલબ્ધ નથી'));
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _billItems.length,
            itemBuilder: (context, index) {
              final item = _billItems[index];
              final retQty = _returnedQtyMap[item.id] ?? 0.0;
              final isFullyReturned = item.isReturned;
              final isWeight = _isWeightUnit(item.unitTypeSnapshot);

              final purchasedDisplay = isWeight
                  ? '${(item.qty * 1000).toStringAsFixed(0)}g (${item.qty.toStringAsFixed(3)}kg)'
                  : '${item.qty.toStringAsFixed(0)} pcs';

              final returnedDisplay = isWeight
                  ? '${(retQty * 1000).toStringAsFixed(0)}g'
                  : '${retQty.toStringAsFixed(0)} pcs';

              final remainingQty = (item.qty - retQty).clamp(0.0, double.maxFinite);
              final remainingDisplay = isWeight
                  ? '${(remainingQty * 1000).toStringAsFixed(0)}g'
                  : '${remainingQty.toStringAsFixed(0)} pcs';

              return Card(
                color: isFullyReturned ? Colors.grey.shade200 : (retQty > 0 ? AppColors.primaryLight.withValues(alpha: 0.08) : null),
                child: ListTile(
                  title: Text(
                    item.productNameSnapshot ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: isFullyReturned ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ખરીદેલ વજન/માત્રા: $purchasedDisplay | ભાવ: ₹${(item.sellPriceSnapshot ?? 0).toStringAsFixed(2)}'),
                      if (retQty > 0)
                        Text(
                          'પરત મળેલું: $returnedDisplay | બાકી રહેતું: $remainingDisplay | રિફંડ: ₹${(retQty * (item.sellPriceSnapshot ?? 0)).toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                    ],
                  ),
                  trailing: isFullyReturned
                      ? const Chip(label: Text('પહેલેથી પરત', style: TextStyle(fontSize: 10)))
                      : IconButton(
                          icon: Icon(retQty > 0 ? Icons.edit : Icons.subdirectory_arrow_left, color: AppColors.primary),
                          onPressed: () => _openReturnDialog(item),
                        ),
                  onTap: isFullyReturned ? null : () => _openReturnDialog(item),
                ),
              );
            },
          ),
        ),
        const Divider(),
        Row(
          children: [
            const Text('રીફંડ મોડ: ', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: ref.watch(returnModeProvider),
              items: const [
                DropdownMenuItem(value: 'cash_refund', child: Text('કેશ રિફંડ')),
                DropdownMenuItem(value: 'udhaar_credit', child: Text('ઉધાર ક્રેડિટ')),
              ],
              onChanged: (v) {
                if (v != null) ref.read(returnModeProvider.notifier).state = v;
              },
            ),
            const Spacer(),
            Text('કુલ રિફંડ: ${formatCurrency(_totalRefundAmount)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading || _returnedQtyMap.isEmpty ? null : _confirmReturn,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('રિફંડ પ્રોસેસ કરો', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  // --- MODE B: REPLACE BODY (Matching Billing Screen UI) ---
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
          onChanged: (v) => _searchCatalog(v),
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
                      title: Text(p.nameGujarati, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('ભાવ: ₹${p.sellPrice.toStringAsFixed(2)} / ${p.unitType} | સ્ટોક: ${p.stockQty}'),
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
            const Text('બદલી બિલ વિગત:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('જૂનું ટોટલ: ${formatCurrency(_originalBillTotal)}', style: const TextStyle(color: Colors.grey)),
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
                        ? '${(item.qty * 1000).toStringAsFixed(0)}g (${item.qty.toStringAsFixed(3)}kg)'
                        : '${item.qty.toStringAsFixed(0)} pcs';

                    return Card(
                      child: ListTile(
                        title: Text(item.productNameSnapshot ?? ''),
                        subtitle: Text('માત્રા/વજન: $qtyDisplay | ભાવ: ₹${(item.sellPriceSnapshot ?? 0).toStringAsFixed(2)}'),
                        trailing: Text(formatCurrency(item.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                const Text('નવું બિલ ટોટલ:'),
                Text(formatCurrency(_newReplaceTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ભાવ ફરક:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  diff.abs() < 0.01
                      ? '₹0.00'
                      : diff > 0
                          ? 'ગ્રાહક ₹${diff.toStringAsFixed(2)} વધુ આપે'
                          : 'દુકાનદારે ₹${(-diff).toStringAsFixed(2)} આપવાના',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: diff > 0 ? Colors.green : (diff < 0 ? Colors.red : Colors.black),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('મોડ: '),
                DropdownButton<String>(
                  value: ref.watch(returnModeProvider),
                  items: const [
                    DropdownMenuItem(value: 'cash_refund', child: Text('કેશ')),
                    DropdownMenuItem(value: 'udhaar_credit', child: Text('ઉધાર')),
                  ],
                  onChanged: (v) {
                    if (v != null) ref.read(returnModeProvider.notifier).state = v;
                  },
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isLoading ? null : _confirmReplace,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
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

// --- RETURN ITEM DIALOG (RECEIVED WEIGHT INPUT & VALIDATION) ---
class _ReturnItemDialog extends StatefulWidget {
  const _ReturnItemDialog({
    required this.item,
    required this.initialReturnedQty,
    required this.isWeightProduct,
    required this.onSave,
  });

  final BillItem item;
  final double initialReturnedQty;
  final bool isWeightProduct;
  final ValueChanged<double> onSave;

  @override
  State<_ReturnItemDialog> createState() => _ReturnItemDialogState();
}

class _ReturnItemDialogState extends State<_ReturnItemDialog> {
  late TextEditingController _receivedCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initialDisplay = widget.initialReturnedQty > 0
        ? (widget.isWeightProduct
            ? (widget.initialReturnedQty * 1000).toStringAsFixed(0)
            : widget.initialReturnedQty.toStringAsFixed(0))
        : '';
    _receivedCtrl = TextEditingController(text: initialDisplay);
  }

  @override
  void dispose() {
    _receivedCtrl.dispose();
    super.dispose();
  }

  void _fillFullReturn() {
    setState(() {
      if (widget.isWeightProduct) {
        _receivedCtrl.text = (widget.item.qty * 1000).toStringAsFixed(0);
      } else {
        _receivedCtrl.text = widget.item.qty.toStringAsFixed(0);
      }
      _error = null;
    });
  }

  double get _parsedReceivedBaseQty {
    final raw = double.tryParse(_receivedCtrl.text.trim()) ?? 0.0;
    if (widget.isWeightProduct) {
      return raw / 1000.0; // convert grams to kg
    }
    return raw;
  }

  void _handleSave() {
    final rawInput = double.tryParse(_receivedCtrl.text.trim());
    if (rawInput == null || rawInput <= 0) {
      setState(() => _error = 'મહેરબાની કરીને માન્ય માત્રા દાખલ કરો');
      return;
    }

    if (!widget.isWeightProduct && rawInput % 1 != 0) {
      setState(() => _error = 'નંગ વાળી આઇટમ માટે પૂર્ણાંક સંખ્યા (whole number) જ દાખલ કરો');
      return;
    }

    final receivedBase = _parsedReceivedBaseQty;
    if (receivedBase > widget.item.qty + 0.0001) {
      final maxDisplay = widget.isWeightProduct
          ? '${(widget.item.qty * 1000).toStringAsFixed(0)}g'
          : '${widget.item.qty.toStringAsFixed(0)} pcs';
      setState(() => _error = 'પરત મળેલી માત્રા ખરીદેલ માત્રા ($maxDisplay) થી વધુ ન હોઈ શકે');
      return;
    }

    widget.onSave(receivedBase);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final maxGramsOrPcs = widget.isWeightProduct
        ? '${(widget.item.qty * 1000).toStringAsFixed(0)} g (${widget.item.qty.toStringAsFixed(3)} kg)'
        : '${widget.item.qty.toStringAsFixed(0)} pcs';

    final currentReceivedBase = _parsedReceivedBaseQty;
    final remainingBase = (widget.item.qty - currentReceivedBase).clamp(0.0, double.maxFinite);
    final remainingDisplay = widget.isWeightProduct
        ? '${(remainingBase * 1000).toStringAsFixed(0)} g (${remainingBase.toStringAsFixed(3)} kg)'
        : '${remainingBase.toStringAsFixed(0)} pcs';

    final refundAmount = currentReceivedBase * (widget.item.sellPriceSnapshot ?? 0);

    return AlertDialog(
      title: Text(widget.item.productNameSnapshot ?? 'પરત લેવાનું ઉત્પાદન'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ખરીદેલ વજન/માત્રા: $maxGramsOrPcs', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('ભાવ: ₹${(widget.item.sellPriceSnapshot ?? 0).toStringAsFixed(2)} / ${widget.isWeightProduct ? 'kg' : 'pcs'}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _fillFullReturn,
              icon: const Icon(Icons.download_done),
              label: const Text('સંપૂર્ણ પરત કરો (Return Full Product)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _receivedCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: widget.isWeightProduct ? 'મળેલું વજન (Received Weight in Grams)' : 'મળેલી માત્રા (Received Qty in Pcs)',
                hintText: widget.isWeightProduct ? 'દા.ત. 750' : 'દા.ત. 2',
                border: const OutlineInputBorder(),
                suffixText: widget.isWeightProduct ? 'grams' : 'pcs',
                helperText: widget.isWeightProduct
                    ? 'ગ્રાહકે દુકાને પરત આપેલું વજન ગ્રામ માં લખો (દા.ત. 1kg માંથી 750g પરત આપ્યું તો 750 લખો)'
                    : 'ગ્રાહકે આપેલા નંગ લખો',
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            if (currentReceivedBase > 0 && _error == null) ...[
              const Divider(),
              Text('બિલ પર બાકી રહેતું વજન: $remainingDisplay', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              Text('પરત રિફંડ રકમ: ${formatCurrency(refundAmount)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onSave(0);
            Navigator.of(context).pop();
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('પરત ના કરો'),
        ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('રદ')),
        ElevatedButton(
          onPressed: _handleSave,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: const Text('સાચવો'),
        ),
      ],
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.bill, required this.onTap});

  final Bill bill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isReturned = bill.paymentStatus == 'fully_returned';
    final customerName = (bill.customerNameSnapshot?.trim().isNotEmpty ?? false)
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
          onTap: onTap,
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
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(dateText, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(customerName, style: const TextStyle(fontSize: 13, color: Colors.grey)),
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
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    if (isReturned) ...[
                      const SizedBox(height: 6),
                      const Text('પહેલેથી પરત', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
