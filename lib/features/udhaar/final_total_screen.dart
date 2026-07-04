import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_format.dart';
import '../../core/utils/date_time_format.dart';
import '../../data/repositories/udhaar_repository.dart';
import '../../routing/app_router.dart';
import 'reminder_bottom_sheet.dart';
import 'udhaar_providers.dart';

class FinalTotalScreen extends ConsumerStatefulWidget {
  const FinalTotalScreen({super.key, required this.customerId});
  final int customerId;

  @override
  ConsumerState<FinalTotalScreen> createState() => _FinalTotalScreenState();
}

class _FinalTotalScreenState extends ConsumerState<FinalTotalScreen> {
  // Tracks which month groups are expanded (by monthKey)
  // Current month is expanded by default; others collapsed
  final Set<String> _expandedMonths = {};
  bool _showItemized = false;
  bool _initialized = false;

  void _ensureCurrentMonthExpanded(FinalTotalData data) {
    if (_initialized) return;
    _initialized = true;
    if (data.months.isNotEmpty) {
      // Expand the last (most recent) month group by default
      _expandedMonths.add(data.months.last.monthKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(finalTotalProvider(widget.customerId));
    final settingsAsync = ref.watch(udhaarSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: dataAsync.when(
          data: (d) => Text(d.customer.nameGujarati),
          loading: () => const Text('Final Total'),
          error: (_, _) => const Text('Final Total'),
        ),
      ),
      body: dataAsync.when(
        data: (data) {
          _ensureCurrentMonthExpanded(data);
          return _buildBody(context, data, settingsAsync);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('ભૂલ: $e')),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    FinalTotalData data,
    AsyncValue<Map<String, String>> settingsAsync,
  ) {
    final settings = settingsAsync.asData?.value ?? {};
    final whatsappEnabled = settings['reminder_whatsapp'] == 'true';
    final smsEnabled = settings['reminder_sms'] == 'true';
    final pdfEnabled = settings['reminder_pdf'] == 'true';

    return Column(
      children: [
        // ── Customer header ──────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppColors.alert.withValues(alpha: 0.08),
          child: Text(
            data.customer.nameGujarati,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        // ── Itemized toggle ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              const Text('આઈટ્મ વિગત દેખાડો'),
              const Spacer(),
              Switch(
                value: _showItemized,
                onChanged: (v) => setState(() => _showItemized = v),
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── Month-wise breakdown ─────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              ...data.months.map(
                (month) => _MonthTile(
                  group: month,
                  isExpanded: _expandedMonths.contains(month.monthKey),
                  showItemized: _showItemized,
                  onToggle: () => setState(() {
                    if (_expandedMonths.contains(month.monthKey)) {
                      _expandedMonths.remove(month.monthKey);
                    } else {
                      _expandedMonths.add(month.monthKey);
                    }
                  }),
                ),
              ),
              const SizedBox(height: 8),
              // ── Grand total ──────────────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.alert.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.alert.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '💰 કુલ બાકી',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      formatCurrency(data.grandTotal),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.alert,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Action buttons ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    if (whatsappEnabled)
                      _ActionButton(
                        icon: Icons.chat,
                        label: 'WhatsApp મોકલો',
                        color: const Color(0xFF25D366),
                        onPressed: () =>
                            _openReminder(context, data, 'whatsapp'),
                      ),
                    if (smsEnabled)
                      _ActionButton(
                        icon: Icons.sms,
                        label: 'SMS',
                        color: AppColors.primary,
                        onPressed: () => _openReminder(context, data, 'sms'),
                      ),
                    if (pdfEnabled)
                      _ActionButton(
                        icon: Icons.picture_as_pdf,
                        label: 'PDF સ્ટેટમેન્ટ',
                        color: AppColors.alert,
                        onPressed: () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('PDF ટૂંક સમયમાં ઉપલ્બ્ધ'),
                              ),
                            ),
                      ),
                    _ActionButton(
                      icon: Icons.payments,
                      label: '₹ ચૂકવણી લો',
                      color: AppColors.success,
                      onPressed: () => Navigator.of(context).pushNamed(
                        AppRouter.udhaarCollect,
                        arguments: widget.customerId,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  void _openReminder(
    BuildContext context,
    FinalTotalData data,
    String reminderType,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ReminderBottomSheet(
        customer: data.customer,
        initialTab: reminderType,
      ),
    );
  }
}

// ─── Month expandable tile ────────────────────────────────────────────────────

class _MonthTile extends StatelessWidget {
  const _MonthTile({
    required this.group,
    required this.isExpanded,
    required this.showItemized,
    required this.onToggle,
  });
  final MonthGroup group;
  final bool isExpanded;
  final bool showItemized;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Month header row
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group.monthLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatCurrency(group.netAmount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: group.netAmount > 0
                            ? AppColors.alert
                            : AppColors.success,
                      ),
                    ),
                    if (group.paymentTotal > 0)
                      Text(
                        'ભર્યું: ${formatCurrency(group.paymentTotal)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Expanded rows
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 40, right: 16, bottom: 8),
            child: Column(
              children: group.rows.map((row) {
                final entry = row.entry;
                final isCredit = entry.transactionType == 'credit';
                DateTime? date;
                try {
                  date = DateTime.parse(entry.createdAt);
                } catch (_) {}
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      if (date != null)
                        SizedBox(
                          width: 70,
                          child: Text(
                            formatDateDDMMYYYY(date),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          isCredit
                              ? 'ખરીદી${row.billNumber != null ? ' #${row.billNumber}' : ''}'
                              : '✓ ચૂક્વ્યું',
                          style: TextStyle(
                            color: isCredit
                                ? AppColors.alert
                                : AppColors.success,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        isCredit
                            ? formatCurrency(entry.amount)
                            : '-${formatCurrency(entry.amount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isCredit ? AppColors.alert : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        const Divider(height: 1, indent: 16),
      ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(label, style: const TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
