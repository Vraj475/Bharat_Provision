import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/role_provider.dart';
import '../../core/utils/currency_format.dart';
import '../../data/repositories/report_repository.dart';
import '../billing/bill_detail_screen.dart';
import '../dashboard/dashboard_providers.dart';

class DailyReportScreen extends ConsumerStatefulWidget {
  const DailyReportScreen({super.key});

  @override
  ConsumerState<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends ConsumerState<DailyReportScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentRoleProvider);
    if (!canAccess(role)) {
      return const Scaffold(body: Center(child: Text('Access Denied')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Report')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateSelector(),
            const SizedBox(height: 16),
            _buildSummary(),
            const SizedBox(height: 16),
            _buildBillsList(),
          ],
        ),
      ),
    );
  }

  bool canAccess(String role) => role == 'admin' || role == 'superadmin';

  Widget _buildDateSelector() {
    return Row(
      children: [
        const Text('Date: '),
        TextButton(
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (date != null) {
              setState(() {
                _selectedDate = date;
              });
            }
          },
          child: Text(_selectedDate.toString().split(' ')[0]),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    final repoFuture = ref.watch(reportRepositoryProvider.future);
    return FutureBuilder<DailyReportData>(
      future: repoFuture.then((repo) => repo.getDailyReport(_selectedDate)),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final data = snapshot.data!;
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Bills',
                    data.billCount.toDouble(),
                    Colors.blue,
                    suffix: ' bills',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryCard(
                    'Total Sales',
                    data.totalSales,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Udhaar Given',
                    data.udhaarGiven,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryCard(
                    'Udhaar Collected',
                    data.udhaarCollected,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Expenses',
                    data.totalExpenses,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryCard(
                    'Net P&L',
                    data.netPL,
                    data.netPL >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSalesBreakdown(data.salesByMode),
            const SizedBox(height: 16),
            _buildExpensesBreakdown(data.expensesByCategory),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(
    String title,
    double amount,
    Color color, {
    String suffix = '',
  }) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              suffix.isEmpty
                  ? formatCurrency(amount)
                  : '${amount.toStringAsFixed(0)}$suffix',
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

  Widget _buildSalesBreakdown(Map<String, double> salesByMode) {
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
            ...salesByMode.entries.map(
              (e) => ListTile(
                title: Text('${e.key.toUpperCase()} Sales'),
                trailing: Text(formatCurrency(e.value)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesBreakdown(Map<String, double> expensesByCategory) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Expenses by Category',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ...expensesByCategory.entries.map(
              (e) => ListTile(
                title: Text(e.key),
                trailing: Text(formatCurrency(e.value)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillsList() {
    final repoFuture = ref.watch(reportRepositoryProvider.future);
    return FutureBuilder<DailyReportData>(
      future: repoFuture.then((repo) => repo.getDailyReport(_selectedDate)),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final data = snapshot.data!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bills',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                ...data.bills.map(
                  (bill) => ListTile(
                    title: Text('Bill #${bill.id}'),
                    subtitle: Text(
                      'Customer: ${bill.customerNameSnapshot ?? 'N/A'}',
                    ),
                    trailing: Text(formatCurrency(bill.totalAmount)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BillDetailScreen(billId: bill.id!),
                        ),
                      );
                    },
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
