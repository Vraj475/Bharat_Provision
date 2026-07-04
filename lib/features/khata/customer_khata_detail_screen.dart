import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_format.dart';
import '../../core/utils/date_time_format.dart';
import '../../core/widgets/numpad.dart';
import '../../data/providers.dart';
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
  void _showAddUdhar() => _showEntryDialog('debit', AppStrings.addUdhar);
  void _showRecordPayment() =>
      _showEntryDialog('credit', AppStrings.recordPayment);

  void _showEntryDialog(String type, String title) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NumpadTextField(
                  controller: ctrl,
                  allowDecimal: true,
                  decoration: InputDecoration(
                    labelText: type == 'debit'
                        ? AppStrings.udharAmount
                        : AppStrings.paymentAmount,
                  ),
                ),
                const SizedBox(height: 16),
                NumpadWidget(
                  controller: ctrl,
                  allowDecimal: true,
                  onSubmit: () => Navigator.pop(ctx, true),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancelButton),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(AppStrings.saveButton),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final amount = double.tryParse(ctrl.text) ?? 0;
    if (amount <= 0) return;

    try {
      final repo = await ref.read(khataRepositoryFutureProvider.future);
      await repo.addEntry(
        customerId: widget.customerId,
        type: type,
        amount: amount,
      );
      ref.invalidate(customerKhataEntriesProvider(widget.customerId));
      ref.invalidate(customerListProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('નોંધાવ્યું')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.errorGeneric} $e')),
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
          data: (d) => Text(d.customer.name),
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
                  ? AppColors.alert.withValues(alpha: 0.2)
                  : AppColors.success.withValues(alpha: 0.2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppStrings.balance,
                    style: Theme.of(context).textTheme.titleLarge,
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
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showAddUdhar,
                    icon: const Icon(Icons.add),
                    label: const Text(AppStrings.addUdhar),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showRecordPayment,
                    icon: const Icon(Icons.payment),
                    label: const Text(AppStrings.recordPayment),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'ઇતિહાસ',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: entriesAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return Center(child: Text('કોઈ એન્ટ્રી નથી'));
                }
                return ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (ctx, i) {
                    final e = entries[i];
                    return ListTile(
                      leading: Icon(
                        e.isDebit ? Icons.arrow_downward : Icons.arrow_upward,
                        color: e.isDebit ? AppColors.alert : AppColors.success,
                      ),
                      title: Text(
                        e.isDebit ? 'ઉધાર' : 'ચુકવણી',
                        style: TextStyle(
                          color: e.isDebit
                              ? AppColors.alert
                              : AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${formatDateDDMMYYYY(DateTime.fromMillisecondsSinceEpoch(e.dateTime))} - ${e.note ?? ''}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatCurrency(e.amount),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'બાકી: ${formatCurrency(e.balanceAfter)}',
                            style: Theme.of(context).textTheme.bodySmall,
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
