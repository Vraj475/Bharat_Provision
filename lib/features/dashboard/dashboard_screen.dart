import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/role_provider.dart';
import '../../core/utils/app_data.dart';
import '../../routing/app_router.dart';
import '../../core/utils/currency_format.dart';
import 'dashboard_providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentRoleProvider);

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<String>(
          future: AppData.getShopName(),
          builder: (context, snapshot) {
            return Text(snapshot.data ?? 'My Shop');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go(AppRouter.settings),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (role == 'employee') ..._buildEmployeeView(),
            if (role == 'admin') ..._buildAdminView(),
            if (role == 'superadmin') ..._buildSuperadminView(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildEmployeeView() {
    return [
      _buildLowStockAlert(),
      const SizedBox(height: 32),
      Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
            textStyle: const TextStyle(fontSize: 24),
          ),
          onPressed: () => context.go(AppRouter.billing),
          child: const Text('નવું બિલ'),
        ),
      ),
    ];
  }

  List<Widget> _buildAdminView() {
    return [
      _buildTodaysCards(),
      const SizedBox(height: 16),
      _buildLowStockAlert(),
      const SizedBox(height: 16),
      _build7DayChart(),
      const SizedBox(height: 16),
      _buildQuickActions(),
    ];
  }

  List<Widget> _buildSuperadminView() {
    return [
      _buildTodaysCards(),
      const SizedBox(height: 16),
      _buildNetProfitCard(),
      const SizedBox(height: 16),
      _buildUdhaarOutstandingCard(),
      const SizedBox(height: 16),
      _buildUserActivityCard(),
      const SizedBox(height: 16),
      _buildLowStockAlert(),
      const SizedBox(height: 16),
      _build7DayChart(),
      const SizedBox(height: 16),
      _buildQuickActions(),
    ];
  }

  Widget _buildTodaysCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Today\'s Sales',
            todaysSalesProvider,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Today\'s Expenses',
            todaysExpensesProvider,
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildNetProfitCard() {
    return _buildSummaryCard(
      'Today\'s Net Profit',
      todaysNetProfitProvider,
      Colors.blue,
    );
  }

  Widget _buildUdhaarOutstandingCard() {
    return _buildSummaryCard(
      'Udhaar Outstanding',
      totalUdhaarOutstandingProvider,
      Colors.orange,
    );
  }

  Widget _buildUserActivityCard() {
    return _buildSummaryCard(
      'Today\'s Bills',
      todaysBillCountProvider,
      Colors.purple,
      suffix: ' bills',
    );
  }

  Widget _buildSummaryCard<T>(
    String title,
    ProviderBase<AsyncValue<T>> provider,
    Color color, {
    String suffix = '',
  }) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ref
                .watch(provider)
                .when(
                  data: (value) => Text(
                    suffix.isEmpty
                        ? formatCurrency(value is double ? value : 0.0)
                        : '${value.toString()}$suffix',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (e, s) => Text('Error: $e'),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockAlert() {
    return ref
        .watch(lowStockProductsProvider)
        .when(
          data: (products) {
            if (products.isEmpty) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade100,
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Low Stock Alert: ${products.length} products below minimum stock',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRouter.inventory),
                    child: const Text('View'),
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (e, s) => const SizedBox.shrink(),
        );
  }

  Widget _build7DayChart() {
    return ref
        .watch(sevenDaySalesProvider)
        .when(
          data: (data) {
            if (data.isEmpty) return const SizedBox.shrink();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '7-Day Sales Trend',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: BarChart(
                        BarChartData(
                          barGroups: data.map((d) {
                            return BarChartGroupData(
                              x: d.date.day,
                              barRods: [
                                BarChartRodData(
                                  toY: d.sales,
                                  color: Colors.green,
                                ),
                              ],
                            );
                          }).toList(),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final date = data.firstWhere(
                                    (d) => d.date.day == value.toInt(),
                                    orElse: () => data.first,
                                  );
                                  return Text(
                                    '${date.date.month}/${date.date.day}',
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: true),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(show: false),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (e, s) => Text('Error loading chart: $e'),
        );
  }

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  'નવું બિલ',
                  Icons.receipt,
                  () => context.go(AppRouter.billing),
                ),
                _buildActionButton(
                  'સ્ટોક ઉમેરો',
                  Icons.inventory,
                  () => context.go(AppRouter.stockAdd),
                ),
                _buildActionButton(
                  'ખર્ચ ઉમેરો',
                  Icons.money_off,
                  () => context.go('/expenses/add'),
                ),
                _buildActionButton(
                  'રિપોર્ટ્સ',
                  Icons.bar_chart,
                  () => context.go(AppRouter.reports),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Column(
      children: [
        IconButton(icon: Icon(icon, size: 32), onPressed: onPressed),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
