import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_format.dart';
import '../../core/utils/date_time_format.dart';
import '../../core/widgets/numpad.dart';
import '../../data/repositories/udhaar_repository.dart';
import 'udhaar_providers.dart';

class CollectPaymentScreen extends ConsumerStatefulWidget {
  const CollectPaymentScreen({super.key, required this.customerId});
  final int customerId;

  @override
  ConsumerState<CollectPaymentScreen> createState() =>
      _CollectPaymentScreenState();
}

class _CollectPaymentScreenState extends ConsumerState<CollectPaymentScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _amountCtrl = TextEditingController();
  String _paymentMode = 'cash';
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveGeneral() async {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('રકમ દાખલ કરો')));
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(udhaarRepositoryProvider)
          .collectGeneralPayment(
            customerId: widget.customerId,
            amount: amount,
            paymentMode: _paymentMode,
            note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          );
      _invalidateProviders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ચૂકવણી સફળતાપૂર્વક નોંધાઈ')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ભૂલ: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _invalidateProviders() {
    ref.invalidate(udhaarCustomerProvider(widget.customerId));
    ref.invalidate(udhaarCustomerListProvider);
    ref.invalidate(unpaidBillsProvider(widget.customerId));
    ref.invalidate(udhaarTotalOutstandingProvider);
  }

  @override
  Widget build(BuildContext context) {
    final customerAsync = ref.watch(udhaarCustomerProvider(widget.customerId));

    return Scaffold(
      appBar: AppBar(
        title: customerAsync.when(
          data: (c) => Text('ચૂકવણી — ${c?.nameGujarati ?? ''}'),
          loading: () => const Text('ચૂકવણી'),
          error: (_, _) => const Text('ચૂકવણી'),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'એકંદર ચૂકવણી'),
            Tab(text: 'ચોક્કસ બિલ ચૂકવો'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: General payment ─────────────────────────────────
          _GeneralPaymentTab(
            amountCtrl: _amountCtrl,
            noteCtrl: _noteCtrl,
            paymentMode: _paymentMode,
            onPaymentModeChanged: (m) => setState(() => _paymentMode = m),
            onSave: _saving ? null : _saveGeneral,
          ),
          // ── Tab 2: Bill-specific payment ───────────────────────────
          _BillSpecificTab(customerId: widget.customerId),
        ],
      ),
    );
  }
}

// ─── General payment tab ──────────────────────────────────────────────────────

class _GeneralPaymentTab extends StatelessWidget {
  const _GeneralPaymentTab({
    required this.amountCtrl,
    required this.noteCtrl,
    required this.paymentMode,
    required this.onPaymentModeChanged,
    required this.onSave,
  });
  final TextEditingController amountCtrl;
  final TextEditingController noteCtrl;
  final String paymentMode;
  final ValueChanged<String> onPaymentModeChanged;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Amount with numpad
          Text('ચૂકવેલ રકમ', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          NumpadTextField(
            controller: amountCtrl,
            allowDecimal: true,
            decoration: const InputDecoration(
              labelText: 'રકમ (₹)',
              prefixText: '₹ ',
            ),
          ),
          const SizedBox(height: 12),
          NumpadWidget(controller: amountCtrl, allowDecimal: true),
          const SizedBox(height: 16),
          // Payment mode
          Text('ચૂકવણી પ્રકાર', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _PaymentModeChips(
            value: paymentMode,
            onChanged: onPaymentModeChanged,
          ),
          const SizedBox(height: 16),
          // Note
          TextField(
            controller: noteCtrl,
            decoration: const InputDecoration(
              labelText: 'નોંધ (વૈકલ્પિક)',
              prefixIcon: Icon(Icons.note_outlined),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('ચૂકવણી સ્વીકારો'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bill-specific tab ────────────────────────────────────────────────────────

class _BillSpecificTab extends ConsumerWidget {
  const _BillSpecificTab({required this.customerId});
  final int customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(unpaidBillsProvider(customerId));
    return billsAsync.when(
      data: (bills) => bills.isEmpty
          ? const Center(child: Text('બાકી બિલ્સ નથી'))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: bills.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
              itemBuilder: (ctx, i) => _UnpaidBillTile(
                row: bills[i],
                customerId: customerId,
                onPaid: () {
                  ref.invalidate(unpaidBillsProvider(customerId));
                  ref.invalidate(udhaarCustomerProvider(customerId));
                  ref.invalidate(udhaarCustomerListProvider);
                  ref.invalidate(udhaarTotalOutstandingProvider);
                },
              ),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('ભૂલ: $e')),
    );
  }
}

// ─── Unpaid bill tile ─────────────────────────────────────────────────────────

class _UnpaidBillTile extends ConsumerStatefulWidget {
  const _UnpaidBillTile({
    required this.row,
    required this.customerId,
    required this.onPaid,
  });
  final UnpaidBillRow row;
  final int customerId;
  final VoidCallback onPaid;

  @override
  ConsumerState<_UnpaidBillTile> createState() => _UnpaidBillTileState();
}

class _UnpaidBillTileState extends ConsumerState<_UnpaidBillTile> {
  bool _paying = false;

  Future<void> _openPayDialog() async {
    final amountCtrl = TextEditingController(
      text: widget.row.remaining.toStringAsFixed(2),
    );
    String payMode = 'cash';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('બિલ #${widget.row.bill.billNumber} ચૂકવો'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BillSummaryRow(
                  label: 'બિલ રકમ',
                  value: formatCurrency(widget.row.bill.totalAmount),
                ),
                _BillSummaryRow(
                  label: 'ચૂકવ્યુ',
                  value: formatCurrency(widget.row.bill.paidAmount),
                ),
                _BillSummaryRow(
                  label: 'બાકી',
                  value: formatCurrency(widget.row.remaining),
                  valueColor: AppColors.alert,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'ચૂકવવાની રકમ (₹)',
                    prefixText: '₹ ',
                  ),
                ),
                const SizedBox(height: 12),
                _PaymentModeChips(
                  value: payMode,
                  onChanged: (m) => setDlgState(() => payMode = m),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('રદ'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ચૂકવો'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    final amount = double.tryParse(amountCtrl.text) ?? 0;
    if (amount <= 0) return;

    setState(() => _paying = true);
    try {
      await ref
          .read(udhaarRepositoryProvider)
          .collectBillSpecificPayment(
            billId: widget.row.bill.id!,
            customerId: widget.customerId,
            amount: amount,
            paymentMode: payMode,
          );
      widget.onPaid();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ચૂકવણી સ્વીકારાઈ')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ભૂલ: $e')));
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.row.bill;
    final isPaid = widget.row.remaining <= 0.01;

    DateTime? billDate;
    try {
      billDate = DateTime.parse(bill.billDate);
    } catch (_) {}

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isPaid
            ? AppColors.success.withValues(alpha: 0.15)
            : AppColors.alert.withValues(alpha: 0.15),
        child: Icon(
          isPaid ? Icons.check_circle : Icons.receipt,
          color: isPaid ? AppColors.success : AppColors.alert,
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Text(
            '#${bill.billNumber}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          if (isPaid)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '✓ ભરાઈ ગ્યું',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (billDate != null)
            Text(
              formatDateDDMMYYYY(billDate),
              style: const TextStyle(fontSize: 12),
            ),
          Text(
            'કુલ: ${formatCurrency(bill.totalAmount)}  '
            'ભર્યું: ${formatCurrency(bill.paidAmount)}  '
            'બાકી: ${formatCurrency(widget.row.remaining)}',
            style: TextStyle(
              fontSize: 12,
              color: isPaid ? AppColors.success : AppColors.alert,
            ),
          ),
        ],
      ),
      trailing: isPaid
          ? null
          : _paying
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : ElevatedButton(
              onPressed: _openPayDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: const Size(60, 36),
              ),
              child: const Text('ભરો'),
            ),
      isThreeLine: true,
    );
  }
}

// ─── Payment mode chips ───────────────────────────────────────────────────────

class _PaymentModeChips extends StatelessWidget {
  const _PaymentModeChips({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const modes = [
      ('cash', 'નાણાં', Icons.money),
      ('upi', 'UPI', Icons.phone_android),
      ('card', 'કાર્ડ', Icons.credit_card),
    ];
    return Wrap(
      spacing: 8,
      children: modes
          .map(
            (m) => ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    m.$3,
                    size: 16,
                    color: value == m.$1 ? Colors.white : AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(m.$2),
                ],
              ),
              selected: value == m.$1,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(color: value == m.$1 ? Colors.white : null),
              onSelected: (_) => onChanged(m.$1),
            ),
          )
          .toList(),
    );
  }
}

// ─── Bill summary row ─────────────────────────────────────────────────────────

class _BillSummaryRow extends StatelessWidget {
  const _BillSummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: valueColor),
          ),
        ],
      ),
    );
  }
}
