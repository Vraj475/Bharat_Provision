import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_format.dart';
import '../../core/utils/date_time_format.dart';
import '../../data/repositories/udhaar_repository.dart';
import '../../routing/app_router.dart';
import '../../shared/models/bill_item_model.dart';
import '../../shared/models/customer_model.dart';
import 'reminder_bottom_sheet.dart';
import 'udhaar_providers.dart';
import 'package:go_router/go_router.dart';

class CustomerLedgerScreen extends ConsumerStatefulWidget {
  const CustomerLedgerScreen({super.key, required this.customerId});
  final int customerId;

  @override
  ConsumerState<CustomerLedgerScreen> createState() =>
      _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends ConsumerState<CustomerLedgerScreen> {
  String? _selectedMonth; // null = all
  List<LedgerRow> _ledgerRows = [];
  bool _loadingLedger = false;
  String? _ledgerError;
  // Tracks which bill rows are expanded: keyed by udhaar_ledger entry id
  final Set<int> _expandedBillIds = {};
  // Cache of loaded bill items
  final Map<int, List<BillItem>> _billItemsCache = {};

  @override
  void initState() {
    super.initState();
    _loadLedger();
  }

  Future<void> _loadLedger() async {
    setState(() {
      _loadingLedger = true;
      _ledgerError = null;
    });
    try {
      final repo = ref.read(udhaarRepositoryProvider);
      final rows = await repo.getLedgerEntries(
        widget.customerId,
        monthYear: _selectedMonth,
      );
      if (mounted) {
        setState(() {
          _ledgerRows = rows;
          _loadingLedger = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ledgerError = e.toString();
          _loadingLedger = false;
        });
      }
    }
  }

  Future<void> _loadBillItems(int billId) async {
    if (_billItemsCache.containsKey(billId)) return;
    final repo = ref.read(udhaarRepositoryProvider);
    final items = await repo.getBillItems(billId);
    if (mounted) {
      setState(() => _billItemsCache[billId] = items);
    }
  }

  Future<void> _convertToRegular() async {
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('નિયમિત ગ્રાહક બનાવો'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneCtrl,
              autofocus: true,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'ફોન નંબર *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressCtrl,
              decoration: const InputDecoration(
                labelText: 'સરનામું (વૈકલ્પિક)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('રદ'),
          ),
          ElevatedButton(
            onPressed: () => ctx.pop(true),
            child: const Text('સ્વીકારો'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final phone = phoneCtrl.text.trim();
    if (phone.isEmpty) return;
    try {
      await ref
          .read(udhaarRepositoryProvider)
          .convertToRegular(widget.customerId, phone, addressCtrl.text.trim());
      ref.invalidate(udhaarCustomerProvider(widget.customerId));
      ref.invalidate(udhaarCustomerListProvider);
      await _loadLedger();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ખાતું નિયમિત ગ્રાહક બન્યું')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ભૂલ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerAsync = ref.watch(udhaarCustomerProvider(widget.customerId));

    return Scaffold(
      appBar: AppBar(
        title: customerAsync.when(
          data: (c) => Text(c?.nameGujarati ?? 'ઉધાર ખાતું'),
          loading: () => const Text('ઉધાર ખાતું'),
          error: (_, _) => const Text('ઉધાર ખાતું'),
        ),
      ),
      body: customerAsync.when(
        data: (customer) {
          if (customer == null) {
            return const Center(child: Text('ગ્રાહક મળ્યો નહીં'));
          }
          return _buildBody(customer);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('ભૂલ: $e')),
      ),
    );
  }

  Widget _buildBody(Customer customer) {
    final isWalkin = customer.accountType == 'walkin';

    return Column(
      children: [
        // ── Customer header ─────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: customer.totalOutstanding > 0
              ? AppColors.alert.withValues(alpha: 0.08)
              : AppColors.success.withValues(alpha: 0.08),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      customer.nameGujarati,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isWalkin)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '👤 નવો',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              if (customer.phone != null && customer.phone!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    customer.phone!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                'બાકી: ${formatCurrency(customer.totalOutstanding)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: customer.totalOutstanding > 0
                      ? AppColors.alert
                      : AppColors.success,
                ),
              ),
              if (isWalkin)
                TextButton.icon(
                  onPressed: _convertToRegular,
                  icon: const Icon(Icons.upgrade, size: 18),
                  label: const Text('નિયમિત ગ્રાહક બનાવો'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: AppColors.primary,
                  ),
                ),
            ],
          ),
        ),
        // ── Action buttons ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.payments,
                  label: 'ચૂકવણી લો',
                  color: AppColors.success,
                  onPressed: () => context.push(
                        AppRouter.udhaarCollect,
                        extra: widget.customerId,
                      )
                      .then((_) {
                        ref.invalidate(
                          udhaarCustomerProvider(widget.customerId),
                        );
                        ref.invalidate(udhaarCustomerListProvider);
                        _loadLedger();
                      }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.receipt_long,
                  label: 'Final Total',
                  color: AppColors.primary,
                  onPressed: () => context.push(
                    AppRouter.udhaarFinal,
                    extra: widget.customerId,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.notifications_active,
                  label: 'રિમાઇન્ડર',
                  color: AppColors.warning,
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder: (_) => ReminderBottomSheet(customer: customer),
                  ),
                ),
              ),
            ],
          ),
        ),
        // ── Month filter ─────────────────────────────────────────────────
        _MonthFilter(
          customerId: widget.customerId,
          selectedMonth: _selectedMonth,
          onChanged: (month) {
            setState(() => _selectedMonth = month);
            _loadLedger();
          },
        ),
        const Divider(height: 1),
        // ── Ledger list ──────────────────────────────────────────────────
        Expanded(
          child: _loadingLedger
              ? const Center(child: CircularProgressIndicator())
              : _ledgerError != null
              ? Center(child: Text('ભૂલ: $_ledgerError'))
              : _ledgerRows.isEmpty
              ? const Center(child: Text('કોઈ એન્ટ્રી નથી'))
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: _ledgerRows.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 16),
                  itemBuilder: (ctx, i) {
                    final row = _ledgerRows[i];
                    return _LedgerTile(
                      row: row,
                      isExpanded:
                          row.entry.billId != null &&
                          _expandedBillIds.contains(row.entry.billId),
                      billItems: row.entry.billId != null
                          ? _billItemsCache[row.entry.billId!]
                          : null,
                      onToggle: row.entry.billId == null
                          ? null
                          : () async {
                              final billId = row.entry.billId!;
                              if (!_expandedBillIds.contains(billId)) {
                                await _loadBillItems(billId);
                              }
                              setState(() {
                                if (_expandedBillIds.contains(billId)) {
                                  _expandedBillIds.remove(billId);
                                } else {
                                  _expandedBillIds.add(billId);
                                }
                              });
                            },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── Month filter dropdown ────────────────────────────────────────────────────

class _MonthFilter extends ConsumerWidget {
  const _MonthFilter({
    required this.customerId,
    required this.selectedMonth,
    required this.onChanged,
  });
  final int customerId;
  final String? selectedMonth;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthsAsync = ref.watch(availableMonthsProvider(customerId));
    return monthsAsync.when(
      data: (months) {
        if (months.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: DropdownButtonFormField<String?>(
            initialValue: selectedMonth,
            isDense: true,
            decoration: const InputDecoration(
              labelText: 'મહિના પ્રમાણે ફિલ્ટર',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('બધા')),
              ...months.map(
                (m) => DropdownMenuItem<String?>(
                  value: m,
                  child: Text(_formatMonth(m)),
                ),
              ),
            ],
            onChanged: onChanged,
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  String _formatMonth(String monthYear) {
    final parts = monthYear.split('-');
    if (parts.length < 2) return monthYear;
    const months = [
      '',
      'જાન્યુ',
      'ફેબ્રુ',
      'માર્ચ',
      'એપ્રિ',
      'મે',
      'જૂન',
      'જુલાઈ',
      'ઓગ',
      'સ્પ્ટે',
      'ઓક્ટો',
      'નવે',
      'ડિસે',
    ];
    final mn = int.tryParse(parts[1]) ?? 0;
    final name = mn >= 1 && mn <= 12 ? months[mn] : parts[1];
    return '$name ${parts[0]}';
  }
}

// ─── Ledger tile ──────────────────────────────────────────────────────────────

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({
    required this.row,
    required this.isExpanded,
    required this.billItems,
    required this.onToggle,
  });
  final LedgerRow row;
  final bool isExpanded;
  final List<BillItem>? billItems;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final entry = row.entry;
    final isCredit = entry.transactionType == 'credit';
    final color = isCredit ? AppColors.alert : AppColors.success;
    final label = isCredit
        ? 'ખરીદી${row.billNumber != null ? ' #${row.billNumber}' : ''}'
        : '✓ ચૂક્વ્યું';
    final sign = isCredit ? '+' : '-';

    DateTime? date;
    try {
      date = DateTime.parse(entry.createdAt);
    } catch (_) {}

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main row
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Date column
                SizedBox(
                  width: 60,
                  child: Text(
                    date != null ? formatDateDDMMYYYY(date) : '',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(width: 8),
                // Label + expand chevron
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isCredit && onToggle != null) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 16,
                          color: Colors.grey[500],
                        ),
                      ],
                    ],
                  ),
                ),
                // Amount
                Text(
                  '$sign${formatCurrency(entry.amount)}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(width: 12),
                // Running balance
                Text(
                  'બા: ${formatCurrency(entry.runningBalance)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
        // Expanded bill line items
        if (isExpanded) _BillItemsPanel(billItems: billItems),
      ],
    );
  }
}

// ─── Expanded bill items panel ────────────────────────────────────────────────

class _BillItemsPanel extends StatelessWidget {
  const _BillItemsPanel({required this.billItems});
  final List<BillItem>? billItems;

  @override
  Widget build(BuildContext context) {
    if (billItems == null) {
      return const Padding(
        padding: EdgeInsets.only(left: 84, bottom: 8),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (billItems!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(left: 84, bottom: 8),
        child: Text(
          'આઈટ્મ વિગત ઉપલ્બ્ધ નથી',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(left: 68, right: 16, bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: billItems!.map((item) {
          final returned = item.isReturned;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.productNameSnapshot ??
                                  'ઉત્પાદ #${item.productId}',
                              style: TextStyle(
                                fontSize: 13,
                                decoration: returned
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          if (returned)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'પાછું આવ્યું',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (returned) const SizedBox(height: 2),
                    ],
                  ),
                ),
                Text(
                  '${item.qty}',
                  style: TextStyle(
                    fontSize: 13,
                    decoration: returned ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  formatCurrency(item.amount),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: returned ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Action button ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: color),
      label: Text(
        label,
        style: TextStyle(color: color, fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        minimumSize: const Size(0, 44),
      ),
    );
  }
}
