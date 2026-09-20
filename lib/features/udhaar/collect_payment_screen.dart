import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

    final customer = await ref.read(udhaarCustomerProvider(widget.customerId).future);
    final outstanding = customer?.totalOutstanding ?? 0.0;
    if (amount > outstanding && outstanding > 0) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('વધુ ચૂકવણીની ચેતવણી'),
          content: Text(
            'કુલ બાકી ${formatCurrency(outstanding)} છે, જ્યારે ચૂકવણી ${formatCurrency(amount)} થઈ રહી છે. શું તમે આગળ વધવા માંગો છો?',
          ),
          actions: [
            TextButton(onPressed: () => ctx.pop(false), child: const Text('ના')),
            ElevatedButton(onPressed: () => ctx.pop(true), child: const Text('હા')),
          ],
        ),
      );
      if (confirm != true) return;
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
        context.pop();
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

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('બિલ #${widget.row.bill.billNumber} ચૂકવો'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'કુલ બિલ: ${formatCurrency(widget.row.bill.totalAmount)}  |  બાકી: ${formatCurrency(widget.row.remaining)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              NumpadTextField(
                controller: amountCtrl,
                allowDecimal: true,
                decoration: const InputDecoration(
                  labelText: 'ચૂકવણી રકમ (₹)',
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
          actions: [
            TextButton(
              onPressed: () => ctx.pop(false),
              child: const Text('કેન્સલ'),
            ),
            ElevatedButton(
              onPressed: () => ctx.pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              child: const Text('ચૂકવો'),
            ),
          ],
        ),
      ),
    );

    if (result != true || !mounted) return;
    final payAmount = double.tryParse(amountCtrl.text) ?? 0;
    if (payAmount <= 0) return;

    if (payAmount > widget.row.remaining) {
      final confirmOverpay = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('વધુ ચૂકવણીની ચેતવણી'),
          content: Text(
            'આ બિલની બાકી રકમ ${formatCurrency(widget.row.remaining)} છે, જ્યારે ચૂકવણી ${formatCurrency(payAmount)} થઈ રહી છે. શું તમે આગળ વધવા માંગો છો?',
          ),
          actions: [
            TextButton(onPressed: () => ctx.pop(false), child: const Text('ના')),
            ElevatedButton(onPressed: () => ctx.pop(true), child: const Text('હા')),
          ],
        ),
      );
      if (confirmOverpay != true) return;
    }

    setState(() => _paying = true);
    try {
      await ref.read(udhaarRepositoryProvider).collectBillSpecificPayment(
            customerId: widget.customerId,
            billId: widget.row.bill.id!,
            amount: payAmount,
            paymentMode: payMode,
          );
      widget.onPaid();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('બિલ ચૂકવણી નોંધાઈ')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ભૂલ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.row.bill;
    final remaining = widget.row.remaining;
    final dt = DateTime.tryParse(bill.billDate);
    final dateStr = dt != null ? formatDateDDMMYYYY(dt) : bill.billDate;

    return ListTile(
      title: Text(
        'બિલ #${bill.billNumber}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        '$dateStr • કુલ: ${formatCurrency(bill.totalAmount)}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'બાકી: ${formatCurrency(remaining)}',
            style: const TextStyle(
              color: AppColors.alert,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 28,
            child: ElevatedButton(
              onPressed: _paying ? null : _openPayDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: _paying
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('ચૂકવો'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Payment mode choice chips ────────────────────────────────────────────────

class _PaymentModeChips extends StatelessWidget {
  const _PaymentModeChips({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const modes = [
      ('cash', 'કેશ', Icons.money),
      ('online', 'ઓનલાઇન', Icons.qr_code),
      ('bank', 'બેંક', Icons.account_balance),
    ];

    return Row(
      children: modes.map((m) {
        final selected = value == m.$1;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            selected: selected,
            onSelected: (_) => onChanged(m.$1),
            avatar: Icon(
              m.$3,
              size: 16,
              color: selected ? Colors.white : AppColors.primary,
            ),
            label: Text(m.$2),
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }
}
