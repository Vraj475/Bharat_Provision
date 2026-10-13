import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth/role_provider.dart';
import '../../core/utils/currency_format.dart';
import '../../data/repositories/report_repository.dart';
import '../settings/providers/auth_provider.dart';
import 'reports_providers.dart';

class PLReportScreen extends ConsumerStatefulWidget {
  const PLReportScreen({super.key});

  @override
  ConsumerState<PLReportScreen> createState() => _PLReportScreenState();
}

class _PLReportScreenState extends ConsumerState<PLReportScreen> {
  String _period = 'today';
  DateTimeRange? _customRange;

  bool canAccess(String? role) => role == 'admin' || role == 'superadmin';

  (DateTime, DateTime) _getDateRange() {
    final now = DateTime.now();
    switch (_period) {
      case 'today':
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return (start, end);
      case 'week':
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(monday.year, monday.month, monday.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return (start, end);
      case 'month':
        final start = DateTime(now.year, now.month, 1);
        final nextMonth = DateTime(now.year, now.month + 1, 1);
        final lastDay = nextMonth.subtract(const Duration(days: 1));
        final end = DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59, 59, 999);
        return (start, end);
      case 'custom':
        if (_customRange != null) {
          final s = _customRange!.start;
          final e = _customRange!.end;
          return (
            DateTime(s.year, s.month, s.day),
            DateTime(e.year, e.month, e.day, 23, 59, 59, 999),
          );
        }
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return (start, end);
      default:
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return (start, end);
    }
  }

  void _showCustomDatePicker() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
    );
    if (range != null) {
      setState(() {
        _customRange = range;
        _period = 'custom';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final role = session?.role ?? ref.watch(currentRoleProvider);

    if (!canAccess(role)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profit & Loss Report')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              const Text(
                'આ રિપોર્ટ જોવા માટે એડમિન પરવાનગી જરૂરી છે',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('પાછા જાઓ'),
              ),
            ],
          ),
        ),
      );
    }

    final (start, end) = _getDateRange();
    final params = PLReportQueryParams(
      startEpoch: start.millisecondsSinceEpoch,
      endEpoch: end.millisecondsSinceEpoch,
    );

    final summaryAsync = ref.watch(plSummaryProvider(params));
    final chartAsync = ref.watch(dailyPLChartProvider(params));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('નફો અને નુકસાન રિપોર્ટ (P&L)'),
        actions: [
          IconButton(
            tooltip: 'રિફ્રેશ કરો',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(plSummaryProvider(params));
              ref.invalidate(dailyPLChartProvider(params));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(plSummaryProvider(params));
          ref.invalidate(dailyPLChartProvider(params));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPeriodSelector(),
              const SizedBox(height: 16),
              summaryAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('ભૂલ: $e', style: const TextStyle(color: Colors.red)),
                  ),
                ),
                data: (summary) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSummaryCards(summary),
                    if (summary.returns > 0) ...[
                      const SizedBox(height: 12),
                      _buildReturnsCard(summary.returns),
                    ],
                    const SizedBox(height: 16),
                    _buildSalesBreakdown(summary.salesByMode),
                    const SizedBox(height: 16),
                    _buildExpensesBreakdown(summary.expensesByAccount),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              chartAsync.when(
                loading: () => const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => const SizedBox.shrink(),
                data: (data) => _buildDailyChart(data),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.date_range, color: Color(0xFF2563EB), size: 20),
            const SizedBox(width: 10),
            const Text(
              'સમયગાળો:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: _period,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'today', child: Text('આજે (Today)')),
                DropdownMenuItem(value: 'week', child: Text('આ અઠવાડિયે (This Week)')),
                DropdownMenuItem(value: 'month', child: Text('આ મહિને (This Month)')),
                DropdownMenuItem(value: 'custom', child: Text('કસ્ટમ તારીખ (Custom)')),
              ],
              onChanged: (value) {
                if (value == null) return;
                if (value == 'custom') {
                  _showCustomDatePicker();
                } else {
                  setState(() {
                    _period = value;
                  });
                }
              },
            ),
            const Spacer(),
            if (_period == 'custom' && _customRange != null)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _showCustomDatePicker,
                icon: const Icon(Icons.edit_calendar, size: 16),
                label: Text(
                  '${DateFormat('dd/MM').format(_customRange!.start)} - ${DateFormat('dd/MM').format(_customRange!.end)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(PLSummary summary) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'કુલ વેચાણ (Sales)',
            formatCurrency(summary.totalSales),
            const Color(0xFF16A34A),
            const Color(0xFFF0FDF4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            'કુલ ખર્ચ (Expenses)',
            formatCurrency(summary.totalExpenses),
            const Color(0xFFDC2626),
            const Color(0xFFFEF2F2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            'ચોખ્ખો નફો (Profit)',
            formatCurrency(summary.netProfit),
            summary.netProfit >= 0 ? const Color(0xFF2563EB) : const Color(0xFFDC2626),
            summary.netProfit >= 0 ? const Color(0xFFEFF6FF) : const Color(0xFFFEF2F2),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    Color textColor,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor.withValues(alpha: 0.85),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildReturnsCard(double returns) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.assignment_return_outlined, size: 18, color: Color(0xFFC2410C)),
              SizedBox(width: 8),
              Text(
                'કુલ પરત કરેલ માલ (Returns Deducted):',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFC2410C)),
              ),
            ],
          ),
          Text(
            formatCurrency(returns),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesBreakdown(Map<String, double> salesByMode) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ચૂકવણી મોડ મુજબ વેચાણ (Sales Breakdown)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (salesByMode.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('કોઈ વેચાણ નથી', style: TextStyle(color: Color(0xFF64748B))),
              )
            else
              ...salesByMode.entries.map((e) {
                final label = switch (e.key.toLowerCase()) {
                  'cash' => 'રોકડ (Cash)',
                  'upi' => 'UPI',
                  'card' => 'કાર્ડ (Card)',
                  'split' => 'સ્પ્લિટ (Split)',
                  'online' => 'ઓનલાઈન (Online)',
                  _ => e.key.toUpperCase(),
                };
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      Text(
                        formatCurrency(e.value),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesBreakdown(Map<String, double> expensesByAccount) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'કેટેગરી મુજબ ખર્ચ (Expenses Breakdown)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (expensesByAccount.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('કોઈ ખર્ચ નથી', style: TextStyle(color: Color(0xFF64748B))),
              )
            else
              ...expensesByAccount.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        Text(
                          formatCurrency(e.value),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyChart(List<DailyPL> data) {
    if (data.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'આ સમયગાળા માટે કોઈ ડેટા નથી',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
          ),
        ),
      );
    }

    double maxVal = 0.0;
    double minVal = 0.0;
    for (final d in data) {
      if (d.netProfit > maxVal) maxVal = d.netProfit;
      if (d.netProfit < minVal) minVal = d.netProfit;
    }

    final double chartMaxY = maxVal > 0 ? maxVal * 1.25 : 100.0;
    final double chartMinY = minVal < 0 ? minVal * 1.25 : 0.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'દૈનિક નફો / નુકસાન આલેખ (Daily Net Profit Chart)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  minY: chartMinY,
                  maxY: chartMaxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        if (groupIndex >= 0 && groupIndex < data.length) {
                          final d = data[groupIndex];
                          final dateStr = DateFormat('dd/MM/yyyy').format(d.date);
                          final profitStr = formatCurrency(d.netProfit);
                          return BarTooltipItem(
                            '$dateStr\n$profitStr',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        }
                        return null;
                      },
                    ),
                  ),
                  barGroups: data.asMap().entries.map((entry) {
                    final index = entry.key;
                    final d = entry.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: d.netProfit,
                          color: d.netProfit >= 0
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                          width: math.max(6.0, 24.0 - data.length * 0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < data.length) {
                            if (data.length > 15 && index % 3 != 0 && index != data.length - 1) {
                              return const SizedBox.shrink();
                            }
                            final d = data[index];
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '${d.date.day}/${d.date.month}',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) {
                            return const Text('0', style: TextStyle(fontSize: 9, color: Color(0xFF64748B)));
                          }
                          return Text(
                            value.abs() >= 1000
                                ? '${(value / 1000).toStringAsFixed(1)}k'
                                : value.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: ((chartMaxY - chartMinY) / 4).clamp(1.0, double.infinity),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: value == 0 ? const Color(0xFF94A3B8) : const Color(0xFFE2E8F0),
                      strokeWidth: value == 0 ? 1.5 : 0.8,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
