import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_format.dart';
import '../../shared/models/bill_model.dart';
import 'bill_history_providers.dart';

class BillHistoryCard extends ConsumerWidget {
  const BillHistoryCard({super.key, required this.bill, required this.onTap});

  final Bill bill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerName = (bill.customerNameSnapshot?.trim().isNotEmpty ?? false)
        ? bill.customerNameSnapshot!
        : 'અજ્ઞાત ગ્રાહક';
    final dateText = _formatDate(bill.billDate);

    return Card(
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
                    GestureDetector(
                      onTap: () => _onDateTap(context, ref),
                      child: Text(
                        dateText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customerName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    BillHistoryStatusBadge(status: bill.paymentStatus),
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onDateTap(BuildContext context, WidgetRef ref) async {
    final parsed = DateTime.tryParse(bill.billDate);
    final initialDate = parsed ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (picked != null) {
      final newDateStr = DateFormat('yyyy-MM-dd').format(picked);

      if (bill.id == null) return;

      try {
        // Update bill date through the bills provider notifier
        final billsNotifier = ref.read(billsProvider.notifier);
        await billsNotifier.updateBillDate(bill.id!, newDateStr);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('બિલ તારીખ અપડેટ કરવામાં આવી'),
              duration: Duration(milliseconds: 1500),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ભૂલ: $e')),
          );
        }
      }
    }
  }

  String _formatDate(String rawDate) {
    final parsed = DateTime.tryParse(rawDate);
    if (parsed != null) {
      return DateFormat('dd/MM/yyyy').format(parsed.toLocal());
    }
    return rawDate;
  }
}

class BillHistoryStatusBadge extends StatelessWidget {
  const BillHistoryStatusBadge({super.key, required this.status});

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