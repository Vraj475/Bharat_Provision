import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'bill_detail_screen.dart';
import 'bill_history_providers.dart';
import 'bill_history_widgets.dart';

class BillHistoryScreen extends ConsumerStatefulWidget {
  const BillHistoryScreen({super.key});

  @override
  ConsumerState<BillHistoryScreen> createState() => _BillHistoryScreenState();
}

class _BillHistoryScreenState extends ConsumerState<BillHistoryScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  DateTime? _fromDate;
  DateTime? _toDate;
  String _query = '';

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      setState(() => _query = _searchController.text.trim());
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

  String _formatFilterDate(DateTime? date, String fallback) {
    if (date == null) return fallback;
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final params = BillHistoryQueryParams(
      query: _query,
      from: _fromDate != null && _toDate != null ? _fromDate : null,
      to: _fromDate != null && _toDate != null ? _toDate : null,
    );
    final billsAsync = ref.watch(billHistoryProvider(params));

    return Scaffold(
      appBar: AppBar(title: const Text('બિલ ઇતિહાસ')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFilterRow(),
            const SizedBox(height: 12),
            _buildSearchField(),
            const SizedBox(height: 16),
            Expanded(
              child: billsAsync.when(
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
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 42),
                          SizedBox(height: 8),
                          Text('કોઈ બિલ મળ્યું નથી'),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: bills.length,
                    itemBuilder: (context, index) {
                      final bill = bills[index];
                      return BillHistoryCard(
                        bill: bill,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BillDetailScreen(
                                billId: bill.id!,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    final fromLabel = _formatFilterDate(_fromDate, 'તારીખ થી');
    final toLabel = _formatFilterDate(_toDate, 'તારીખ સુધી');

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

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: 'ગ્રાહકનું નામ અથવા બિલ નંબર',
        border: OutlineInputBorder(),
      ),
      onChanged: (_) => _scheduleSearch(),
    );
  }
}