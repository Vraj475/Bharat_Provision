import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_format.dart';
import '../../data/providers.dart';
import '../../routing/app_router.dart';
import 'reports_providers.dart';
import 'package:go_router/go_router.dart';

class ReportsHomeScreen extends ConsumerWidget {
  const ReportsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final todayEnd = now.millisecondsSinceEpoch;
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartEpoch = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    ).millisecondsSinceEpoch;
    final monthStart = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.reportsTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            _SalesCard(
              title: AppStrings.todaySales,
              startEpoch: todayStart,
              endEpoch: todayEnd,
            ),
            const SizedBox(height: 12),
            _SalesCard(
              title: AppStrings.weekSales,
              startEpoch: weekStartEpoch,
              endEpoch: todayEnd,
            ),
            const SizedBox(height: 12),
            _SalesCard(
              title: AppStrings.monthSales,
              startEpoch: monthStart,
              endEpoch: todayEnd,
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.outstandingKhata,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ref
                .watch(outstandingKhataProvider)
                .when(
                  data: (customers) {
                    if (customers.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('કોઈ બાકી ખાતા નથી'),
                        ),
                      );
                    }
                    return Card(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: customers.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final c = customers[i];
                          return ListTile(
                            title: Text(c.name),
                            trailing: Text(
                              formatCurrency(c.balance),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.alert,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (e, _) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('${AppStrings.errorGeneric} $e'),
                    ),
                  ),
                ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        context.push(AppRouter.plReport),
                    child: const Text('P&L Report'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        context.push(AppRouter.dailyReport),
                    child: const Text('Daily Report'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesCard extends ConsumerWidget {
  const _SalesCard({
    required this.title,
    required this.startEpoch,
    required this.endEpoch,
  });

  final String title;
  final int startEpoch;
  final int endEpoch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref
          .read(reportRepositoryProvider)
          .getSalesSummary(startEpoch, endEpoch),
      builder: (ctx, snap) {
        final summary = snap.data;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (summary != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${AppStrings.totalSales}: ${formatCurrency(summary.totalSales)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('${AppStrings.billCount}: ${summary.billCount}'),
                    ],
                  )
                else
                  const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
