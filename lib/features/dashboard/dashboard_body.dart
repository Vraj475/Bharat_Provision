import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auth/role_provider.dart';
import '../../core/utils/currency_format.dart';
import '../../routing/app_router.dart';
import '../billing/bill_detail_screen.dart';
import '../billing/bill_history_providers.dart';
import '../billing/bill_history_widgets.dart';
import 'dashboard_providers.dart';

class DashboardBody extends ConsumerStatefulWidget {
  const DashboardBody({super.key});

  @override
  ConsumerState<DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends ConsumerState<DashboardBody> {
  final _billSearchController = TextEditingController();
  Timer? _billSearchDebounce;
  DateTime? _billFromDate;
  DateTime? _billToDate;
  String _billQuery = '';

  @override
  void dispose() {
    _billSearchDebounce?.cancel();
    _billSearchController.dispose();
    super.dispose();
  }

  void _scheduleBillSearch() {
    _billSearchDebounce?.cancel();
    _billSearchDebounce = Timer(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      setState(() => _billQuery = _billSearchController.text.trim());
    });
  }

  Future<void> _pickBillFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billFromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _billFromDate = picked);
    }
  }

  Future<void> _pickBillToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billToDate ?? _billFromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _billToDate = picked);
    }
  }

  void _clearBillDates() {
    setState(() {
      _billFromDate = null;
      _billToDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentRoleProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (role == 'employee') ..._buildEmployeeView(),
          if (role == 'admin') ..._buildAdminView(),
          if (role == 'superadmin') ..._buildSuperadminView(),
        ],
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
          onPressed: () => Navigator.of(context).pushNamed(AppRouter.billing),
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
      _buildSevenDayChart(),
      const SizedBox(height: 16),
      _buildQuickActions(),
      const SizedBox(height: 16),
      _buildBillHistorySection(),
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
      _buildSevenDayChart(),
      const SizedBox(height: 16),
      _buildQuickActions(),
      const SizedBox(height: 16),
      _buildBillHistorySection(),
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
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRouter.inventory),
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

  Widget _buildSevenDayChart() {
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
                  () => Navigator.of(context).pushNamed(AppRouter.billing),
                ),
                _buildActionButton(
                  'સ્ટોક ઉમેરો',
                  Icons.inventory,
                  () => Navigator.of(context).pushNamed(AppRouter.stockAdd),
                ),
                _buildActionButton(
                  'ખર્ચ ઉમેરો',
                  Icons.money_off,
                  () => Navigator.of(context).pushNamed(AppRouter.addExpense),
                ),
                _buildActionButton(
                  'રિપોર્ટ્સ',
                  Icons.bar_chart,
                  () => Navigator.of(context).pushNamed(AppRouter.reports),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillHistorySection() {
    final hasActiveDates = _billFromDate != null && _billToDate != null;
    final params = BillHistoryQueryParams(
      query: _billQuery,
      from: hasActiveDates ? _billFromDate : null,
      to: hasActiveDates ? _billToDate : null,
      limit: 15,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'બિલ ઇતિહાસ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRouter.billHistory),
                  child: const Text('જુઓ બધા'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickBillFromDate,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _billFromDate == null
                          ? 'તારીખ થી'
                          : DateFormat('dd/MM/yyyy').format(_billFromDate!),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickBillToDate,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _billToDate == null
                          ? 'તારીખ સુધી'
                          : DateFormat('dd/MM/yyyy').format(_billToDate!),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _clearBillDates,
                  icon: const Icon(Icons.close),
                  tooltip: 'Clear dates',
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _billSearchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'ગ્રાહકનું નામ અથવા બિલ નંબર',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _scheduleBillSearch(),
            ),
            const SizedBox(height: 16),
            ref
                .watch(billHistoryPreviewProvider(params))
                .when(
                  loading: () => const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text('બિલ લોડ થઈ રહ્યા છે'),
                      ],
                    ),
                  ),
                  error: (e, _) => Center(child: Text('ભૂલ: $e')),
                  data: (preview) {
                    if (preview.bills.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 36),
                            SizedBox(height: 8),
                            Text('કોઈ બિલ મળ્યું નથી'),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: [
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: preview.bills.length,
                          separatorBuilder: (context, _) =>
                              const SizedBox(height: 0),
                          itemBuilder: (context, index) {
                            final bill = preview.bills[index];
                            return BillHistoryCard(
                              bill: bill,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      BillDetailScreen(billId: bill.id!),
                                ),
                              ),
                            );
                          },
                        ),
                        if (preview.hasMore) ...[
                          const SizedBox(height: 8),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'વધુ બિલ જોવા માટે \'જુઓ બધા\' દબાવો.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
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
