import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_format.dart';
import '../../data/repositories/return_repository.dart';
import '../../shared/models/bill_item_model.dart';
import '../../shared/models/bill_model.dart';
import '../../shared/models/product_model.dart';
import 'returns_providers.dart';

class ReplaceScreen extends ConsumerStatefulWidget {
  const ReplaceScreen({super.key});

  @override
  ConsumerState<ReplaceScreen> createState() => _ReplaceScreenState();
}

class _ReplaceScreenState extends ConsumerState<ReplaceScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _searchDebounce;

  String _query = '';
  String _status = 'all';
  DateTime? _fromDate;
  DateTime? _toDate;

  List<BillItem> _billItems = [];
  Bill? _selectedBill;
  BillItem? _selectedReturnItem;
  final _returnQtyCtrl = TextEditingController();

  List<Product> _productSearchResults = [];
  Product? _selectedReplacementProduct;
  final _replacementQtyCtrl = TextEditingController();

  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _scrollController.dispose();
    _returnQtyCtrl.dispose();
    _replacementQtyCtrl.dispose();
    super.dispose();
  }

  bool get _hasDateFilter => _fromDate != null && _toDate != null;

  bool get _hasActiveFilters =>
      _query.isNotEmpty || _status != 'all' || _hasDateFilter;

  BillListQueryParams get _queryParams => BillListQueryParams(
    query: _query,
    status: _status,
    from: _hasDateFilter ? _fromDate : null,
    to: _hasDateFilter ? _toDate : null,
  );

  void _scheduleSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 100), () {
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
    });
    await _loadBillItems(bill.id!);
  }

  void _backToBillList() {
    setState(() {
      _selectedBill = null;
      _billItems = [];
      _selectedReturnItem = null;
      _selectedReplacementProduct = null;
      _productSearchResults = [];
    });
  }

  Future<void> _loadBillItems(int billId) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _billItems = [];
      _selectedReturnItem = null;
      _productSearchResults = [];
      _selectedReplacementProduct = null;
    });
    try {
      final repo = ref.read(returnRepositoryProvider);
      final items = await repo.getBillItems(billId);
      if (!mounted) return;
      setState(() {
        _billItems = items;
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

  Future<void> _searchProducts(String query) async {
    final repo = ref.read(returnRepositoryProvider);
    final results = await repo.getProducts(query: query);
    if (!mounted) return;
    setState(() {
      _productSearchResults = results;
    });
  }

  double get _returnValue {
    if (_selectedReturnItem == null) return 0;
    final qty = double.tryParse(_returnQtyCtrl.text) ?? 0;
    return qty * (_selectedReturnItem!.sellPriceSnapshot ?? 0);
  }

  double get _replacementQtyCalculated {
    if (_selectedReturnItem == null || _selectedReplacementProduct == null) {
      return 0;
    }
    if (_selectedReplacementProduct!.sellPrice <= 0) return 0;
    final returnValue = _returnValue;
    return (returnValue / _selectedReplacementProduct!.sellPrice) * 1000;
  }

  double get _replacementQtyGiven {
    return double.tryParse(_replacementQtyCtrl.text) ??
        _replacementQtyCalculated;
  }

  double get _priceDifference {
    final returnValue = _returnValue;
    final replacementCost =
        (_replacementQtyGiven / 1000) *
        (_selectedReplacementProduct?.sellPrice ?? 0);
    return replacementCost - returnValue;
  }

  Future<void> _confirmReplace() async {
    if (_selectedBill == null ||
        _selectedReturnItem == null ||
        _selectedReplacementProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('સૌ પ્રથમ બિલ, પાછું અને બદલોપટા પસંદ કરો'),
        ),
      );
      return;
    }

    final qtyReturned = double.tryParse(_returnQtyCtrl.text) ?? 0;
    if (qtyReturned <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('મહેરબાની કરીને પાછું માટે માન્ય માત્રા દાખલ કરો'),
        ),
      );
      return;
    }

    final replacementQtyGiven =
        double.tryParse(_replacementQtyCtrl.text) ?? _replacementQtyCalculated;
    if (replacementQtyGiven <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('બદલી માટે માન્ય માત્રા દાખલ કરો')),
      );
      return;
    }

    final returnLine = ReturnLine(
      billItemId: _selectedReturnItem!.id!,
      productId: _selectedReturnItem!.productId,
      qtyReturned: qtyReturned,
      sellPriceSnapshot: _selectedReturnItem!.sellPriceSnapshot ?? 0,
    );

    final replacementInput = ReplacementInput(
      returnedProductId: _selectedReturnItem!.productId,
      returnedQty: qtyReturned,
      returnedPricePerKg: _selectedReturnItem!.sellPriceSnapshot ?? 0,
      replacementProductId: _selectedReplacementProduct!.id!,
      replacementPricePerKg: _selectedReplacementProduct!.sellPrice,
      replacementQtyCalculated: _replacementQtyCalculated,
      replacementQtyGiven: replacementQtyGiven,
      priceDifference: _priceDifference,
      differenceMode: ref.read(returnModeProvider),
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final diff = _priceDifference;
        final diffText = diff.abs() < 0.01
            ? 'કોઈ ભાવ ભેદ નથી'
            : diff > 0
            ? 'ગ્રાહક ₹${diff.toStringAsFixed(2)} વધુ ચૂકવીશે'
            : 'દુકાનદારે ₹${(-diff).toStringAsFixed(2)} પરત આપશે';

        return AlertDialog(
          title: const Text('બદલો પુષ્ટિકરણ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'પાછું: ${_selectedReturnItem!.productNameSnapshot} ${qtyReturned.toStringAsFixed(2)}g',
              ),
              Text(
                'બદલી: ${_selectedReplacementProduct!.nameGujarati} ${replacementQtyGiven.toStringAsFixed(2)}g',
              ),
              const SizedBox(height: 8),
              Text(diffText),
              const SizedBox(height: 8),
              const Text('પ્રગટાવવામાં આવશે વધુ ઉપાય'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('રદ'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('સાચવો'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(returnRepositoryProvider);
      await repo.createReplace(
        billId: _selectedBill!.id!,
        customerId: _selectedBill!.customerId,
        returnLine: returnLine,
        replacement: replacementInput,
        returnMode: ref.read(returnModeProvider),
        notes:
            'Replace: ${_selectedReturnItem!.productNameSnapshot} → ${_selectedReplacementProduct!.nameGujarati}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('બદલી સફળતાપૂર્વક થઈ')));
      await _loadBillItems(_selectedBill!.id!);
      setState(() {
        _selectedReplacementProduct = null;
        _productSearchResults = [];
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

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(returnBillListProvider(_queryParams));

    return Scaffold(
      appBar: AppBar(title: const Text('બદલવું')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 10),
            _buildStatusChips(),
            const SizedBox(height: 10),
            _buildDateRow(),
            const SizedBox(height: 12),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],
            if (_isLoading) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Expanded(
              child: Stack(
                children: [
                  Offstage(
                    offstage: _selectedBill != null,
                    child: _buildBillList(billsAsync),
                  ),
                  Offstage(
                    offstage: _selectedBill == null,
                    child: _buildReplaceForm(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: 'બિલ નંબર, ગ્રાહકનું નામ, અથવા કુલ રકમ',
        border: OutlineInputBorder(),
      ),
      onChanged: (_) => _scheduleSearch(),
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
      loading: () => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text('બિલ લોડ થઈ રહ્યા છે'),
          ],
        ),
      ),
      error: (e, _) => Center(child: Text('ભૂલ: $e')),
      data: (bills) {
        if (bills.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _hasActiveFilters ? Icons.search : Icons.shopping_cart,
                  size: 42,
                ),
                const SizedBox(height: 8),
                Text(
                  _hasActiveFilters ? 'કોઈ બિલ મળ્યું નથી' : 'હજુ કોઈ બિલ નથી',
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          itemCount: bills.length,
          itemBuilder: (context, index) {
            final bill = bills[index];
            return _BillListCard(bill: bill, onTap: () => _openBill(bill));
          },
        );
      },
    );
  }

  Widget _buildReplaceForm() {
    if (_selectedBill == null) {
      return const SizedBox.shrink();
    }

    if (_billItems.isEmpty && _isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text('બિલ લોડ થઈ રહ્યા છે'),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: _backToBillList,
              icon: const Icon(Icons.arrow_back),
              label: const Text('બિલ યાદી પર પાછા જાઓ'),
            ),
            const Spacer(),
            if (_selectedBill?.paymentStatus == 'fully_returned')
              const _GreyReturnedLabel(),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'બિલ #: ${_selectedBill?.billNumber ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        const Text('પાછું લેવારું આઇટમ પસંદ કરો'),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: _billItems.length,
            itemBuilder: (context, index) {
              final item = _billItems[index];
              final isSelected = _selectedReturnItem?.id == item.id;
              final alreadyReturned = item.isReturned;
              return Card(
                color: alreadyReturned ? Colors.grey.shade100 : null,
                child: ListTile(
                  title: Text(
                    item.productNameSnapshot ?? '',
                    style: TextStyle(
                      decoration: alreadyReturned
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: Text('Qty: ${item.qty.toStringAsFixed(2)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (alreadyReturned) const _GreyReturnedLabel(),
                      if (isSelected) const Icon(Icons.check_circle),
                    ],
                  ),
                  onTap: () {
                    setState(() {
                      _selectedReturnItem = item;
                      _returnQtyCtrl.text = item.qty.toStringAsFixed(2);
                    });
                  },
                ),
              );
            },
          ),
        ),
        if (_selectedReturnItem != null) ...[
          const Divider(),
          Text(
            'પાછું ખરીદી મંજુર કરો: ${_selectedReturnItem!.productNameSnapshot}',
          ),
          TextField(
            controller: _returnQtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'પાછું લાખેલી માત્રા (g)',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          const Text('બદલી માટે ઉત્પાદન પસંદ કરો'),
          TextField(
            decoration: const InputDecoration(
              labelText: 'સરફ કોર',
              hintText: 'ઉત્પાદન શોધો',
            ),
            onChanged: (v) => _searchProducts(v),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _productSearchResults.length,
              itemBuilder: (context, index) {
                final prod = _productSearchResults[index];
                final selected = _selectedReplacementProduct?.id == prod.id;
                return ListTile(
                  title: Text(prod.nameGujarati),
                  subtitle: Text('₹${prod.sellPrice.toStringAsFixed(2)}/kg'),
                  trailing: selected ? const Icon(Icons.check_circle) : null,
                  onTap: () {
                    setState(() {
                      _selectedReplacementProduct = prod;
                      _replacementQtyCtrl.text = _replacementQtyCalculated
                          .toStringAsFixed(2);
                    });
                  },
                );
              },
            ),
          ),
          if (_selectedReplacementProduct != null) ...[
            const Divider(),
            Text(
              'બદલી મળતી માત્રા (ગ્રામ): ${_replacementQtyCalculated.toStringAsFixed(2)}',
            ),
            TextField(
              controller: _replacementQtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'બસ મળતી માત્રા (ગ્રામ)',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ભાવ ફરક:'),
                Text(
                  _priceDifference.abs() < 0.01
                      ? '₹0.00'
                      : _priceDifference > 0
                      ? 'ગ્રાહક ₹${_priceDifference.toStringAsFixed(2)} વધુ આપે'
                      : 'દુકાનદારે ₹${(-_priceDifference).toStringAsFixed(2)} આપે',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('મોડ:'),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: ref.watch(returnModeProvider),
                  items: const [
                    DropdownMenuItem(value: 'cash_refund', child: Text('કેશ')),
                    DropdownMenuItem(
                      value: 'udhaar_credit',
                      child: Text('ઉધાર'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(returnModeProvider.notifier).state = v;
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _confirmReplace,
              child: const Text('બદલી પ્રક્રિયા કરો'),
            ),
          ],
        ],
      ],
    );
  }
}

class _BillListCard extends StatelessWidget {
  const _BillListCard({required this.bill, required this.onTap});

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
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(dateText, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        customerName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
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
                    Text(
                      formatCurrency(bill.totalAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (isReturned) ...[
                      const SizedBox(height: 6),
                      const _GreyReturnedLabel(),
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
          decoration: normalized == 'fully_returned'
              ? TextDecoration.lineThrough
              : null,
        ),
      ),
    );
  }
}

class _GreyReturnedLabel extends StatelessWidget {
  const _GreyReturnedLabel();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'પહેલેથી પરત',
      style: TextStyle(
        color: Colors.grey,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
