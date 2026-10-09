import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/utils/currency_format.dart';
import '../../routing/app_router.dart';
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('બિલ ઇતિહાસ')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFilterRow(),
            const SizedBox(height: 12),
            _buildSearchField(),
            const SizedBox(height: 14),
            Expanded(
              child: billsAsync.when(
                loading: () => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 10),
                      Text(
                        'બિલ લોડ થઈ રહ્યા છે...',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 42, color: Colors.red),
                      const SizedBox(height: 8),
                      Text('ભૂલ: $e'),
                    ],
                  ),
                ),
                data: (bills) {
                  if (bills.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFF94A3B8)),
                          SizedBox(height: 12),
                          Text(
                            'કોઈ બિલ મળ્યું નથી',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final totalSum = bills.fold<double>(0, (sum, b) => sum + b.totalAmount);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'કુલ બિલ: ${bills.length}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                            Text(
                              'કુલ રકમ: ${formatCurrency(totalSum)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: bills.length,
                          itemBuilder: (context, index) {
                            final bill = bills[index];
                            return BillHistoryCard(
                              bill: bill,
                              onTap: () {
                                if (bill.id != null) {
                                  context.push(AppRouter.billDetail, extra: bill.id!);
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ],
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
    final hasActiveDates = _fromDate != null || _toDate != null;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _pickFromDate,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 11),
              backgroundColor: _fromDate != null ? const Color(0xFFEFF6FF) : Colors.white,
              side: BorderSide(
                color: _fromDate != null ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: Icon(
              Icons.calendar_today,
              size: 16,
              color: _fromDate != null ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
            label: Text(
              fromLabel,
              style: TextStyle(
                fontWeight: _fromDate != null ? FontWeight.w700 : FontWeight.w500,
                color: _fromDate != null ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _pickToDate,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 11),
              backgroundColor: _toDate != null ? const Color(0xFFEFF6FF) : Colors.white,
              side: BorderSide(
                color: _toDate != null ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: Icon(
              Icons.calendar_today,
              size: 16,
              color: _toDate != null ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
            label: Text(
              toLabel,
              style: TextStyle(
                fontWeight: _toDate != null ? FontWeight.w700 : FontWeight.w500,
                color: _toDate != null ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
              ),
            ),
          ),
        ),
        if (hasActiveDates) ...[
          const SizedBox(width: 4),
          IconButton(
            onPressed: _clearDates,
            icon: const Icon(Icons.close, color: Color(0xFFDC2626)),
            tooltip: 'તારીખો સાફ કરો',
          ),
        ],
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
        hintText: 'ગ્રાહકનું નામ અથવા બિલ નંબર શોધો...',
        hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              )
            : null,
      ),
      onChanged: (_) {
        setState(() {});
        _scheduleSearch();
      },
    );
  }
}
