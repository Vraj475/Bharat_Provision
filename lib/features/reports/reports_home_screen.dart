import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_format.dart';
import '../../data/providers.dart';
import '../../data/repositories/report_repository.dart';
import '../../routing/app_router.dart';
import 'reports_providers.dart';

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
    final todayEnd = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
      59,
      999,
    ).millisecondsSinceEpoch;

    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartEpoch = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    ).millisecondsSinceEpoch;

    final monthStart = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(reportRepositoryProvider);
          ref.invalidate(outstandingKhataProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.reportsTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
              _SalesCard(
                title: AppStrings.todaySales,
                icon: Icons.today_outlined,
                startEpoch: todayStart,
                endEpoch: todayEnd,
              ),
              const SizedBox(height: 12),
              _SalesCard(
                title: AppStrings.weekSales,
                icon: Icons.date_range_outlined,
                startEpoch: weekStartEpoch,
                endEpoch: todayEnd,
              ),
              const SizedBox(height: 12),
              _SalesCard(
                title: AppStrings.monthSales,
                icon: Icons.calendar_month_outlined,
                startEpoch: monthStart,
                endEpoch: todayEnd,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppStrings.outstandingKhata,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton.icon(
                    onPressed: () => context.push(AppRouter.khata),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('બધા ખાતા'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ref.watch(outstandingKhataProvider).when(
                    data: (customers) {
                      if (customers.isEmpty) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: Text(
                                'કોઈ બાકી ખાતા નથી',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: customers.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final c = customers[i];
                            return ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFF1F5F9),
                                child: Icon(Icons.person, color: Color(0xFF475569)),
                              ),
                              title: Text(
                                c.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    formatCurrency(c.balance),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.alert,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                                ],
                              ),
                              onTap: () {
                                context.push(AppRouter.customerKhata, extra: c.id);
                              },
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
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(child: Text('${AppStrings.errorGeneric} $e')),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: () => ref.invalidate(outstandingKhataProvider),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => context.push(AppRouter.plReport),
                      icon: const Icon(Icons.analytics_outlined, size: 20),
                      label: const Text(
                        'P&L Report',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => context.push(AppRouter.dailyReport),
                      icon: const Icon(Icons.event_note_outlined, size: 20),
                      label: const Text(
                        'Daily Report',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => context.push(AppRouter.expenseList),
                  icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                  label: const Text(
                    'ખરીદી અને ખર્ચ (Purchases & Expenses)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SalesCard extends ConsumerWidget {
  const _SalesCard({
    required this.title,
    required this.icon,
    required this.startEpoch,
    required this.endEpoch,
  });

  final String title;
  final IconData icon;
  final int startEpoch;
  final int endEpoch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<SalesSummary>(
      future: ref.read(reportRepositoryProvider).getSalesSummary(startEpoch, endEpoch),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icon, color: const Color(0xFF2563EB)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
            ),
          );
        }

        if (snap.hasError) {
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$title લોડ કરવામાં ભૂલ',
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final summary = snap.data;
        final totalSales = summary?.totalSales ?? 0.0;
        final billCount = summary?.billCount ?? 0;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: const Color(0xFF2563EB), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatCurrency(totalSales),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$billCount બિલ',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
