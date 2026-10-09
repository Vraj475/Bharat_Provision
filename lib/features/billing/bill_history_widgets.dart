import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/currency_format.dart';
import '../../shared/models/bill_model.dart';
import 'bill_history_providers.dart';

class BillHistoryCard extends ConsumerWidget {
  const BillHistoryCard({super.key, required this.bill, required this.onTap});

  final Bill bill;
  final VoidCallback onTap;

  Color _getStatusColor(String? status) {
    final normalized = (status ?? '').trim().toLowerCase();
    return switch (normalized) {
      'paid' => const Color(0xFF16A34A), // Rich Green
      'udhaar' => const Color(0xFFEA580C), // Deep Orange
      'partial' => const Color(0xFFD97706), // Amber
      'partial_return' => const Color(0xFF2563EB), // Blue
      'fully_returned' => const Color(0xFF64748B), // Slate Grey
      _ => const Color(0xFF64748B),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _getStatusColor(bill.paymentStatus);
    final dateText = _formatDate(bill.billDate);

    final normalizedMode = (bill.paymentMode ?? '').trim().toLowerCase();
    final normalizedStatus = (bill.paymentStatus ?? '').trim().toLowerCase();
    final hasCustomerName =
        bill.customerNameSnapshot != null &&
        bill.customerNameSnapshot!.trim().isNotEmpty;

    final isUdhaar =
        normalizedStatus == 'udhaar' ||
        normalizedMode == 'udhaar' ||
        bill.udhaarAmount > 0;

    final isCash =
        !isUdhaar &&
        (normalizedMode == 'cash' ||
            normalizedMode.isEmpty ||
            (!hasCustomerName && normalizedStatus == 'paid'));

    final isOnline = !isUdhaar && !isCash && (normalizedMode == 'upi' || normalizedMode == 'online' || normalizedMode == 'card');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      color: Colors.white,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withValues(alpha: 0.35), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left status accent stripe for instant bill recognition
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              // Card main content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Bill Number & Amount Pill
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.receipt_long_rounded,
                                  size: 16,
                                  color: statusColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'બિલ #${bill.billNumber}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
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
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Middle Row: Prominent Customer / Cash Display (Not Muted!)
                      if (isCash)
                        _buildCashBadge(hasCustomerName)
                      else if (isUdhaar)
                        _buildUdhaarBadge(hasCustomerName)
                      else if (isOnline)
                        _buildOnlineBadge(hasCustomerName)
                      else
                        _buildGenericCustomerBadge(hasCustomerName),

                      const SizedBox(height: 10),

                      // Bottom Row: Date (tappable) & Status Badge & Chevron indicator
                      Row(
                        children: [
                          // Tappable Date Pill
                          InkWell(
                            onTap: () => _onDateTap(context, ref),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 12,
                                    color: Color(0xFF475569),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    dateText,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.edit_calendar_outlined,
                                    size: 12,
                                    color: Color(0xFF2563EB),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          BillHistoryStatusBadge(status: bill.paymentStatus),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCashBadge(bool hasCustomerName) {
    final label = hasCustomerName
        ? 'રોકડ (${bill.customerNameSnapshot!.trim()})'
        : 'રોકડ';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.payments_outlined,
            size: 15,
            color: Color(0xFF15803D),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF15803D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUdhaarBadge(bool hasCustomerName) {
    final customerName = hasCustomerName
        ? bill.customerNameSnapshot!.trim()
        : 'ઉધાર ગ્રાહક';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEDD5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFFDBA74)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person,
                size: 15,
                color: Color(0xFFC2410C),
              ),
              const SizedBox(width: 5),
              Text(
                customerName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9A3412),
                ),
              ),
            ],
          ),
        ),
        if (bill.udhaarAmount > 0) ...[
          const SizedBox(width: 8),
          Text(
            'બાકી: ${formatCurrency(bill.udhaarAmount)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFFEA580C),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOnlineBadge(bool hasCustomerName) {
    final label = hasCustomerName
        ? 'ઓનલાઇન (${bill.customerNameSnapshot!.trim()})'
        : 'ઓનલાઇન / UPI';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            size: 15,
            color: Color(0xFF1D4ED8),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1D4ED8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericCustomerBadge(bool hasCustomerName) {
    final customerName = hasCustomerName
        ? bill.customerNameSnapshot!.trim()
        : 'ગ્રાહક';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_outline,
            size: 15,
            color: Color(0xFF334155),
          ),
          const SizedBox(width: 5),
          Text(
            customerName,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
        ],
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('ભૂલ: $e')));
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
    final normalized = (status ?? '').trim().toLowerCase();
    final (label, color) = switch (normalized) {
      'paid' => ('ચૂકવાયું', const Color(0xFF16A34A)),
      'udhaar' => ('ઉધાર', const Color(0xFFEA580C)),
      'partial' => ('આંશિક', const Color(0xFFD97706)),
      'partial_return' => ('આંશિક પરત', const Color(0xFF2563EB)),
      'fully_returned' => ('પૂર્ણ પરત', const Color(0xFF64748B)),
      _ => (normalized.isEmpty ? 'અજ્ઞાત' : normalized, const Color(0xFF64748B)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28), width: 1),
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
