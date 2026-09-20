import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/role_provider.dart';
import '../../core/utils/currency_format.dart';
import '../../data/repositories/report_repository.dart';
import '../../features/dashboard/dashboard_providers.dart';

class PLReportScreen extends ConsumerStatefulWidget {
  const PLReportScreen({super.key});

  @override
  ConsumerState<PLReportScreen> createState() => _PLReportScreenState();
}

class _PLReportScreenState extends ConsumerState<PLReportScreen> {
  String _period = 'today';
  DateTimeRange? _customRange;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentRoleProvider);
    if (!canAccess(role)) {
      return const Scaffold(body: Center(child: Text('Access Denied')));
    }

    final (start, end) = _getDateRange();
    final startEpoch = start.millisecondsSinceEpoch;
    final endEpoch = end.millisecondsSinceEpoch;

    return Scaffold(
      appBar: AppBar(title: const Text('Profit & Loss Report')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPeriodSelector(),
            const SizedBox(height: 16),
            _buildSummary(startEpoch, endEpoch),
            const SizedBox(height: 16),
            _buildSalesBreakdown(startEpoch, endEpoch),
            const SizedBox(height: 16),
            _buildExpensesBreakdown(startEpoch, endEpoch),
            const SizedBox(height: 16),
            _buildDailyChart(startEpoch, endEpoch),
          ],
        ),
      ),
    );
  }

  bool canAccess(String role) => role == 'admin' || role == 'superadmin';

  (DateTime, DateTime) _getDateRange() {
    final now = DateTime.now();
    switch (_period) {
      case 'today':
        final start = DateTime(now.year, now.month, now.day);
        return (start, start.add(const Duration(days: 1)));
      case 'week':
        final start = now.subtract(Duration(days: now.weekday - 1));
        final end = start.add(const Duration(days: 7));
        return (
          DateTime(start.year, start.month, start.day),
          DateTime(end.year, end.month, end.day),
        );
      case 'month':
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 1);
        return (start, end);
      case 'custom':
        if (_customRange != null) {
          return (
            _customRange!.start,
            _customRange!.end.add(const Duration(days: 1)),
          );
        }
        return _getDateRange(); // fallback
      default:
        return _getDateRange();
    }
  }

  Widget _buildPeriodSelector() {
    return Row(
      children: [
        const Text('Period: '),
        DropdownButton<String>(
          value: _period,
          items: const [
            DropdownMenuItem(value: 'today', child: Text('Today')),
            DropdownMenuItem(value: 'week', child: Text('This Week')),
            DropdownMenuItem(value: 'month', child: Text('This Month')),
            DropdownMenuItem(value: 'custom', child: Text('Custom')),
          ],
          onChanged: (value) {
            setState(() {
              _period = value!;
              if (_period == 'custom') {
                _showCustomDatePicker();
              }
            });
          },
        ),
        if (_customRange != null) ...[
          const SizedBox(width: 16),
          Text(
            '${_customRange!.start.toLocal().toString().split(' ')[0]} - ${_customRange!.end.toLocal().toString().split(' ')[0]}',
          ),
        ],
      ],
    );
  }

  void _showCustomDatePicker() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customRange,
    );
    if (range != null) {
      setState(() {
        _customRange = range;
      });
    }
  }

  Widget _buildSummary(int startEpoch, int endEpoch) {
    final repoFuture = ref.watch(reportRepositoryProvider.future);
    return FutureBuilder<PLSummary>(
      future: repoFuture.then(
        (repo) => repo.getPLSummary(startEpoch, endEpoch),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final summary = snapshot.data!;
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Sales',
                    summary.totalSales,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryCard(
                    'Total Expenses',
                    summary.totalExpenses,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryCard(
                    'Net Profit',
                    summary.netProfit,
                    summary.netProfit >= 0 ? Colors.blue : Colors.red,
                  ),
                ),
              ],
            ),
            if (summary.returns > 0) ...[
              const SizedBox(height: 8),
              _buildSummaryCard(
                'Returns Deducted',
                summary.returns,
                Colors.orange,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              formatCurrency(amount),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesBreakdown(int startEpoch, int endEpoch) {
    final repoFuture = ref.watch(reportRepositoryProvider.future);
    return FutureBuilder<PLSummary>(
      future: repoFuture.then(
        (repo) => repo.getPLSummary(startEpoch, endEpoch),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final summary = snapshot.data!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sales Breakdown',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                ...summary.salesByMode.entries.map(
                  (e) => ListTile(
                    title: Text('${e.key.toUpperCase()} Sales'),
                    trailing: Text(formatCurrency(e.value)),
                  ),
                ),
                if (summary.udhaarCollected > 0)
                  ListTile(
                    title: const Text('Udhaar Collected'),
                    trailing: Text(formatCurrency(summary.udhaarCollected)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpensesBreakdown(int startEpoch, int endEpoch) {
    final repoFuture = ref.watch(reportRepositoryProvider.future);
    return FutureBuilder<PLSummary>(
      future: repoFuture.then(
        (repo) => repo.getPLSummary(startEpoch, endEpoch),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final summary = snapshot.data!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Expenses Breakdown',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                ...summary.expensesByAccount.entries.map(
                  (e) => ListTile(
                    title: Text(e.key),
                    trailing: Text(formatCurrency(e.value)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDailyChart(int startEpoch, int endEpoch) {
    final repoFuture = ref.watch(reportRepositoryProvider.future);
    return FutureBuilder<List<DailyPL>>(
      future: repoFuture.then((repo) => repo.getDailyPL(startEpoch, endEpoch)),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final data = snapshot.data!;
        if (data.isEmpty) return const Text('No data for selected period');
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Net Profit',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
                              toY: d.netProfit,
                              color: d.netProfit >= 0
                                  ? Colors.green
                                  : Colors.red,
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
    );
  }
}
