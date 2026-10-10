import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_format.dart';
import '../../core/utils/date_time_format.dart';
import '../../data/providers.dart';
import '../udhaar/udhaar_providers.dart';
import 'khata_providers.dart';

class CustomerKhataDetailScreen extends ConsumerStatefulWidget {
  const CustomerKhataDetailScreen({super.key, required this.customerId});

  final int customerId;

  @override
  ConsumerState<CustomerKhataDetailScreen> createState() =>
      _CustomerKhataDetailScreenState();
}

class _CustomerKhataDetailScreenState
    extends ConsumerState<CustomerKhataDetailScreen> {
  void _showAddUdhar() => _showEntryDialog('debit');
  void _showRecordPayment() => _showEntryDialog('credit');

  Future<void> _showEntryDialog(String type) async {
    final customerData =
        ref.read(customerWithBalanceProvider(widget.customerId)).valueOrNull;
    final customerName = customerData?.customer.nameGujarati ?? 'ગ્રાહક';
    final currentBalance = customerData?.balance ?? 0.0;

    final result =
        await showDialog<({double amount, String note, int? billId})>(
      context: context,
      builder: (ctx) => _KhataEntryDialog(
        customerId: widget.customerId,
        customerName: customerName,
        currentBalance: currentBalance,
        type: type,
      ),
    );

    if (result == null || !mounted) return;

    try {
      final repo = ref.read(khataRepositoryProvider);
      await repo.addEntry(
        customerId: widget.customerId,
        type: type,
        amount: result.amount,
        relatedBillId: result.billId,
        note: result.note,
      );
      ref.invalidate(customerKhataEntriesProvider(widget.customerId));
      ref.invalidate(customerWithBalanceProvider(widget.customerId));
      ref.invalidate(customerBillsProvider(widget.customerId));
      ref.invalidate(customersProvider);
      ref.invalidate(customerListProvider);
      ref.invalidate(bulkCustomerBalancesProvider);
      ref.invalidate(udhaarProvider);
      ref.invalidate(udhaarTotalOutstandingProvider);
      ref.invalidate(udhaarCustomerListProvider);
      ref.invalidate(udhaarCustomerProvider(widget.customerId));
      if (mounted) {
        final successMsg = type == 'debit'
            ? '₹${result.amount.toStringAsFixed(2)} ઉધાર સફળતાપૂર્વક નોંધાયા'
            : '₹${result.amount.toStringAsFixed(2)} ચુકવણી સફળતાપૂર્વક જમા થઈ';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.errorGeneric} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerAsync = ref.watch(
      customerWithBalanceProvider(widget.customerId),
    );
    final entriesAsync = ref.watch(
      customerKhataEntriesProvider(widget.customerId),
    );

    return Scaffold(
      appBar: AppBar(
        title: customerAsync.when(
          data: (d) => Text('${d.customer.nameGujarati} ખાતું'),
          loading: () => const Text(AppStrings.khataTitle),
          error: (_, _) => const Text(AppStrings.khataTitle),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          customerAsync.when(
            data: (d) => Container(
              padding: const EdgeInsets.all(16),
              color: d.balance > 0
                  ? AppColors.alert.withValues(alpha: 0.15)
                  : AppColors.success.withValues(alpha: 0.15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppStrings.balance,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    formatCurrency(d.balance),
                    style: Theme.of(context).textTheme.titleLarge!.copyWith(
                      fontWeight: FontWeight.bold,
                      color: d.balance > 0
                          ? AppColors.alert
                          : AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
            error: (_, _) => const SizedBox.shrink(),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showAddUdhar,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text(AppStrings.addUdhar),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showRecordPayment,
                    icon: const Icon(Icons.payment, size: 20),
                    label: const Text(AppStrings.recordPayment),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Text(
              'ઇતિહાસ (ખાતાવહી વ્યવહારો)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(
            child: entriesAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return const Center(child: Text('કોઈ એન્ટ્રી નથી'));
                }
                return ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (ctx, i) {
                    final e = entries[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: e.isDebit
                            ? AppColors.alert.withValues(alpha: 0.15)
                            : AppColors.success.withValues(alpha: 0.15),
                        child: Icon(
                          e.isDebit ? Icons.arrow_upward : Icons.arrow_downward,
                          color: e.isDebit ? AppColors.alert : AppColors.success,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        e.isDebit ? 'ઉધાર લીધું' : 'ચુકવણી જમા',
                        style: TextStyle(
                          color: e.isDebit
                              ? AppColors.alert
                              : AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '${formatDateDDMMYYYY(DateTime.fromMillisecondsSinceEpoch(e.dateTime))}${e.note != null && e.note!.isNotEmpty ? ' • ${e.note}' : ''}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatCurrency(e.amount),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: e.isDebit
                                  ? AppColors.alert
                                  : AppColors.success,
                            ),
                          ),
                          Text(
                            'બાકી: ${formatCurrency(e.balanceAfter)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('${AppStrings.errorGeneric} $e')),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Proper Amount Entry Dialog with Full Bill Payment Section ───────────────

class _KhataEntryDialog extends ConsumerStatefulWidget {
  const _KhataEntryDialog({
    required this.customerId,
    required this.customerName,
    required this.currentBalance,
    required this.type,
  });

  final int customerId;
  final String customerName;
  final double currentBalance;
  final String type; // 'debit' or 'credit'

  @override
  ConsumerState<_KhataEntryDialog> createState() => _KhataEntryDialogState();
}

class _KhataEntryDialogState extends ConsumerState<_KhataEntryDialog> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  int? _selectedBillId;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _selectBill(Map<String, dynamic> bill) {
    setState(() {
      final billId = bill['id'] as int?;
      final billNumber = bill['bill_number']?.toString() ?? '';
      final total = (bill['total_amount'] as num?)?.toDouble() ?? 0.0;
      final paid = (bill['paid_amount'] as num?)?.toDouble() ?? 0.0;
      final remaining = (total - paid) > 0 ? (total - paid) : total;

      _selectedBillId = billId;
      _amountCtrl.text = remaining.toStringAsFixed(
        remaining.truncateToDouble() == remaining ? 0 : 2,
      );
      _noteCtrl.text = 'બિલ #$billNumber સંપૂર્ણ ચૂકવણી';
    });
  }

  void _setAmount(double amt) {
    setState(() {
      _amountCtrl.text = amt.toStringAsFixed(
        amt.truncateToDouble() == amt ? 0 : 2,
      );
    });
  }

  void _submit() {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('કૃપા કરી યોગ્ય રકમ દાખલ કરો'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final noteText = _noteCtrl.text.trim().isNotEmpty
        ? _noteCtrl.text.trim()
        : (widget.type == 'debit' ? 'હસ્તચાલિત ઉધાર' : 'ચુકવણી જમા');

    Navigator.of(context).pop((
      amount: amount,
      note: noteText,
      billId: _selectedBillId,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDebit = widget.type == 'debit';
    final themeColor = isDebit ? const Color(0xFFDC2626) : const Color(0xFF16A34A);
    final themeBg = isDebit ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 660),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ─────────────────────────────────────────────
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: themeBg,
                    child: Icon(
                      isDebit ? Icons.add_circle_outline : Icons.check_circle_outline,
                      color: themeColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDebit ? 'ઉધાર નોંધણી (Add Udhaar)' : 'ચુકવણી જમા (Record Payment)',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              widget.customerName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                            const Text(' • ', style: TextStyle(color: Color(0xFF94A3B8))),
                            Text(
                              'બાકી: ${formatCurrency(widget.currentBalance)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: widget.currentBalance > 0
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Section 1: Bill Payment Selection (Only for Payment) ──
                      if (!isDebit) ...[
                        _buildBillSelectionSection(),
                        const SizedBox(height: 16),
                      ],

                      // ── Section 2: Proper Amount Entry Field ──────────
                      Text(
                        isDebit ? 'ઉધાર રકમ દાખલ કરો' : 'ચુકવણી રકમ દાખલ કરો',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            Text(
                              '₹',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: themeColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _amountCtrl,
                                autofocus: true,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: themeColor,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: '0.00',
                                  hintStyle: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                              ),
                            ),
                            if (_amountCtrl.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.cancel, color: Color(0xFF94A3B8), size: 20),
                                onPressed: () {
                                  setState(() {
                                    _amountCtrl.clear();
                                    _selectedBillId = null;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ── Quick amount chips ────────────────────────────
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (!isDebit && widget.currentBalance > 0)
                            ActionChip(
                              avatar: const Icon(Icons.check_circle, size: 16, color: Color(0xFF16A34A)),
                              label: Text(
                                'સંપૂર્ણ બાકી (${formatCurrency(widget.currentBalance)})',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                              backgroundColor: const Color(0xFFDCFCE7),
                              side: const BorderSide(color: Color(0xFF86EFAC)),
                              onPressed: () {
                                _setAmount(widget.currentBalance);
                                _noteCtrl.text = 'સંપૂર્ણ બાકી ચૂકવણી';
                              },
                            ),
                          ..._quickAmounts(isDebit).map(
                            (amt) => ActionChip(
                              label: Text('+₹$amt', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              backgroundColor: const Color(0xFFF1F5F9),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              onPressed: () => _setAmount(amt.toDouble()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Section 3: Note / Description ─────────────────
                      TextField(
                        controller: _noteCtrl,
                        decoration: InputDecoration(
                          labelText: 'નોંધ / વિગત (વૈકલ્પિક)',
                          hintText: isDebit ? 'દા.ત. કરિયાણું, ઘરખર્ચ' : 'દા.ત. રોકડા, Google Pay, UPI',
                          prefixIcon: const Icon(Icons.edit_note, color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // ── Action Buttons ──────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('રદ કરો', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(
                      isDebit ? 'ઉધાર સાચવો' : 'ચુકવણી સાચવો',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  List<int> _quickAmounts(bool isDebit) {
    return isDebit ? [50, 100, 200, 500, 1000] : [100, 200, 500, 1000, 2000];
  }

  Widget _buildBillSelectionSection() {
    final billsAsync = ref.watch(customerBillsProvider(widget.customerId));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long, size: 18, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text(
                'સંપૂર્ણ બિલ ચૂકવણી (Take Full Bill Payment)',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          const Text(
            'નીચેના બિલ પર ક્લિક કરવાથી તે બિલની રકમ આપમેળે ભરાશે',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          billsAsync.when(
            data: (bills) {
              if (bills.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: const Center(
                    child: Text(
                      'આ ગ્રાહક માટે કોઈ બાકી બિલ નથી (બધા બિલ ચુકતે)',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ),
                );
              }

              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: bills.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (ctx, idx) {
                    final b = bills[idx];
                    final billId = b['id'] as int?;
                    final isSelected = _selectedBillId == billId;
                    final total = (b['total_amount'] as num?)?.toDouble() ?? 0.0;
                    final paid = (b['paid_amount'] as num?)?.toDouble() ?? 0.0;
                    final isPending = total > paid;
                    final billNumber = b['bill_number']?.toString() ?? '';
                    final billDate = b['bill_date']?.toString() ?? '';

                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _selectBill(b),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.8 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                              size: 18,
                              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'બિલ #$billNumber',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? const Color(0xFF1E40AF) : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      if (isPending)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEE2E2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'બાકી: ${formatCurrency(total - paid)}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFDC2626),
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'ચુકતે',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF16A34A),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (billDate.isNotEmpty)
                                    Text(
                                      billDate,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatCurrency(total),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected ? const Color(0xFF1E40AF) : const Color(0xFF0F172A),
                                  ),
                                ),
                                const Text(
                                  'બિલ કુલ',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
            error: (e, _) => Center(
              child: Text('બિલ લોડ કરવામાં ભૂલ: $e', style: const TextStyle(fontSize: 11, color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }
}
