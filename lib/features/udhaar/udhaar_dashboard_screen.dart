import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/role_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_format.dart';
import '../../data/repositories/udhaar_repository.dart';
import '../../routing/app_router.dart';
import '../../shared/models/customer_model.dart';
import 'reminder_bottom_sheet.dart';
import 'udhaar_providers.dart';

class UdhaarDashboardScreen extends ConsumerStatefulWidget {
  const UdhaarDashboardScreen({super.key});

  @override
  ConsumerState<UdhaarDashboardScreen> createState() =>
      _UdhaarDashboardScreenState();
}

class _UdhaarDashboardScreenState extends ConsumerState<UdhaarDashboardScreen> {
  Color _daysColor(int days) {
    if (days <= 0) return AppColors.success;
    if (days <= 15) return AppColors.success;
    if (days <= 30) return AppColors.warning;
    return AppColors.alert;
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentRoleProvider);
    if (!canAccessUdhaar(role)) {
      return Scaffold(
        appBar: AppBar(title: const Text('ઉધાર')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: AppColors.alert),
              const SizedBox(height: 16),
              Text(
                'ઉધાર ફક્ત Admin / Superadmin માટે',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: AppColors.alert),
              ),
            ],
          ),
        ),
      );
    }

    final totalAsync = ref.watch(udhaarTotalOutstandingProvider);
    final customersAsync = ref.watch(udhaarCustomerListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ઉધાર'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'રિફ્રેશ',
            onPressed: () {
              ref.invalidate(udhaarTotalOutstandingProvider);
              ref.invalidate(udhaarCustomerListProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Total outstanding summary card ──────────────────────────────
          totalAsync.when(
            data: (total) => _TotalCard(total: total),
            loading: () => const SizedBox(
              height: 80,
              child: Center(child: LinearProgressIndicator()),
            ),
            error: (_, _) => const SizedBox.shrink(),
          ),
          // ── Customer list ───────────────────────────────────────────────
          Expanded(
            child: customersAsync.when(
              data: (customers) => customers.isEmpty
                  ? Center(
                      child: Text(
                        'કોઈ ઉધાર ખાતા નથી',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    )
                  : ListView.builder(
                      itemCount: customers.length,
                      padding: const EdgeInsets.only(bottom: 80),
                      itemBuilder: (ctx, i) {
                        final row = customers[i];
                        return _CustomerTile(
                          row: row,
                          daysColor: _daysColor(row.daysSinceOldestUnpaid),
                          onTap: () => Navigator.of(context).pushNamed(
                            AppRouter.udhaarCustomer,
                            arguments: row.customer.id,
                          ),
                          onBell: () => _openReminder(row.customer),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('ભૂલ: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCustomerDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('ગ્રાહક ઉમેરો'),
      ),
    );
  }

  void _openReminder(Customer customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ReminderBottomSheet(customer: customer),
    );
  }

  Future<void> _showAddCustomerDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String accountType = 'regular';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('નવો ગ્રાહક ઉમેરો'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'ગ્રાહકનું નામ (ગુજ.) *',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'ફોન નંબર (વૈકલ્પિક)',
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: 'regular',
                      label: Text('નિયમિત ગ્રાહક'),
                    ),
                    ButtonSegment<String>(
                      value: 'walkin',
                      label: Text('👤 વૉક-ઇન ગ્રાહક (નવો)'),
                    ),
                  ],
                  selected: {accountType},
                  onSelectionChanged: (selection) {
                    setDlgState(() => accountType = selection.first);
                  },
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
              child: const Text('ઉમેરો'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    final repo = ref.read(udhaarRepositoryProvider);

    // Duplicate check
    final similar = await repo.findSimilarCustomers(name);
    if (!mounted) return;
    if (similar.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('સમાન ગ્રાહક મળ્યો'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('આ ગ્રાહક પહેલેથી હોઈ શકે:'),
              const SizedBox(height: 8),
              ...similar
                  .take(3)
                  .map(
                    (c) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.person),
                      title: Text(c.nameGujarati),
                      subtitle: Text(c.phone ?? ''),
                    ),
                  ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('રદ'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('છતાં ઉમેરો'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    try {
      await repo.addCustomer(
        nameGujarati: name,
        phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
        accountType: accountType,
      );
      ref.invalidate(udhaarCustomerListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ગ્રાહક સફળતાપૂર્વક ઉમેરાયો')),
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
}

// ─── Total outstanding card ───────────────────────────────────────────────────

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total});
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.alert.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.alert.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'કુલ બાકી ઉધાર',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.alert),
          ),
          const SizedBox(height: 4),
          Text(
            formatCurrency(total),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: AppColors.alert,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Customer tile ────────────────────────────────────────────────────────────

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({
    required this.row,
    required this.daysColor,
    required this.onTap,
    required this.onBell,
  });
  final CustomerSummaryRow row;
  final Color daysColor;
  final VoidCallback onTap;
  final VoidCallback onBell;

  @override
  Widget build(BuildContext context) {
    final c = row.customer;
    final isWalkin = c.accountType == 'walkin';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                backgroundColor: c.totalOutstanding > 0
                    ? AppColors.alert.withValues(alpha: 0.15)
                    : AppColors.success.withValues(alpha: 0.15),
                child: Icon(
                  Icons.person,
                  color: c.totalOutstanding > 0
                      ? AppColors.alert
                      : AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              // Name + badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            c.nameGujarati,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isWalkin) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '👤 નવો',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (row.daysSinceOldestUnpaid > 0)
                      Text(
                        '${row.daysSinceOldestUnpaid} દિવ્સ',
                        style: TextStyle(
                          fontSize: 12,
                          color: daysColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              // Outstanding amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency(c.totalOutstanding),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: c.totalOutstanding > 0
                          ? AppColors.alert
                          : AppColors.success,
                    ),
                  ),
                ],
              ),
              // Bell icon
              IconButton(
                icon: const Icon(Icons.notifications_none),
                color: AppColors.warning,
                tooltip: 'રિમાઇન્ડર',
                onPressed: onBell,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
