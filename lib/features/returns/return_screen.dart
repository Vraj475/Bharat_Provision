import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_format.dart';
import '../../data/repositories/return_repository.dart';
import '../../shared/models/bill_item_model.dart';
import '../../shared/models/bill_model.dart';
import 'returns_providers.dart';

class ReturnScreen extends ConsumerStatefulWidget {
  const ReturnScreen({super.key});

  @override
  ConsumerState<ReturnScreen> createState() => _ReturnScreenState();
}

class _ReturnScreenState extends ConsumerState<ReturnScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _searchDebounce;

  String _query = '';
  String _status = 'all';
  DateTime? _fromDate;
  DateTime? _toDate;

  Bill? _selectedBill;
  List<BillItem> _billItems = [];
  final Map<int, TextEditingController> _qtyControllers = {};
  final Set<int> _selectedItemIds = {};

  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _scrollController.dispose();
    for (final controller in _qtyControllers.values) {
      controller.dispose();
    }
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
      _selectedItemIds.clear();
    });
  }

  Future<void> _loadBillItems(int billId) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _billItems = [];
      _selectedItemIds.clear();
      for (final controller in _qtyControllers.values) {
        controller.dispose();
      }
      _qtyControllers.clear();
    });
    try {
      final repo = ref.read(returnRepositoryProvider);
      final items = await repo.getBillItems(billId);
      for (final item in items) {
        _qtyControllers[item.id!] = TextEditingController(
          text: item.qty.toStringAsFixed(2),
        );
      }
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

  double get _refundTotal {
    double total = 0;
    for (final item in _billItems) {
      if (!_selectedItemIds.contains(item.id)) continue;
      final qty = double.tryParse(_qtyControllers[item.id!]!.text) ?? 0;
      total += qty * (item.sellPriceSnapshot ?? 0);
    }
    return total;
  }

  Future<void> _confirmReturn() async {
    if (_selectedBill == null) return;

    if (_selectedBill!.paymentStatus == 'fully_returned') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('આ બિલ પહેલેથી સંપૂર્ણ પાછું આવ્યું છે')),
      );
      return;
    }

    final selectedLineIds = _selectedItemIds.toList();
    if (selectedLineIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('કમ સે કમ એક આઇટમ પસંદ કરો')),
      );
      return;
    }

    final lines = <ReturnLine>[];
    for (final item in _billItems) {
      if (!_selectedItemIds.contains(item.id)) continue;
      final qty = double.tryParse(_qtyControllers[item.id!]!.text) ?? 0;
      if (qty <= 0) continue;
      final maxQty = item.qty;
      final finalQty = qty > maxQty ? maxQty : qty;
      lines.add(
        ReturnLine(
          billItemId: item.id!,
          productId: item.productId,
          qtyReturned: finalQty,
          sellPriceSnapshot: item.sellPriceSnapshot ?? 0,
        ),
      );
    }

    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('માન્યતા માટે યોગ્ય આઇટમ અને માત્રા પસંદ કરો'),
        ),
      );
      return;
    }

    final mode = ref.read(returnModeProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('પાછું લેવાનું પ્રમાણિત કરો'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('બિલ #: ${_selectedBill!.billNumber}'),
              const SizedBox(height: 8),
              Text('મોટો રકમ: ${formatCurrency(_refundTotal)}'),
              Text(
                'રીફંડ મોડ: ${mode == 'cash_refund' ? 'કેશ રિફંડ' : 'ઉધાર ક્રેડિટ'}',
              ),
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
        const SnackBar(content: Text('રિફંડ સફળતાપૂર્વક લેવામાં આવ્યું')),
      );
      await _loadBillItems(_selectedBill!.id!);
      setState(() {
        _selectedItemIds.clear();
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
      appBar: AppBar(title: const Text('પાછું આપવું')),
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
                    child: _buildReturnDetail(),
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

  Widget _buildReturnDetail() {
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
        const SizedBox(height: 8),
        if (_billItems.isEmpty)
          const Expanded(
            child: Center(child: Text('આ બિલ માટે કોઈ આઇટમ મળ્યાં નથી')),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _billItems.length,
              itemBuilder: (context, index) {
                final item = _billItems[index];
                final alreadyReturned = item.isReturned;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.productNameSnapshot ?? 'ઉત્પાદન',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: alreadyReturned
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            if (alreadyReturned)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('પહેલેથી પરત'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Qty: ${item.qty.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Text(
                              '₹${(item.sellPriceSnapshot ?? 0).toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (!alreadyReturned) ...[
                          Row(
                            children: [
                              Checkbox(
                                value: _selectedItemIds.contains(item.id),
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selectedItemIds.add(item.id!);
                                    } else {
                                      _selectedItemIds.remove(item.id);
                                    }
                                  });
                                },
                              ),
                              const Text('પાછું લેવારું'),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: _qtyControllers[item.id!],
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'માત્રા (qty)',
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                          if (_selectedItemIds.contains(item.id))
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'રીફંડ રકમ: ${formatCurrency((double.tryParse(_qtyControllers[item.id!]!.text) ?? 0) * (item.sellPriceSnapshot ?? 0))}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('રીફંડ મોડ:'),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: ref.watch(returnModeProvider),
              items: const [
                DropdownMenuItem(
                  value: 'cash_refund',
                  child: Text('કેશ રિફંડ'),
                ),
                DropdownMenuItem(
                  value: 'udhaar_credit',
                  child: Text('ઉધાર ક્રેડિટ'),
                ),
              ],
              onChanged: (v) {
                if (v != null) {
                  ref.read(returnModeProvider.notifier).state = v;
                }
              },
            ),
            const Spacer(),
            Text('ટોટલ: ${formatCurrency(_refundTotal)}'),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _isLoading ? null : _confirmReturn,
          child: const Text('રિફંડ પ્રોસેસ કરો'),
        ),
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
