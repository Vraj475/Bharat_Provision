import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth/role_provider.dart';
import '../../core/utils/currency_format.dart';
import '../../data/repositories/report_repository.dart';
import '../../routing/app_router.dart';
import '../../shared/models/bill_model.dart';
import '../settings/providers/auth_provider.dart';
import 'reports_providers.dart';

class DailyReportScreen extends ConsumerStatefulWidget {
  const DailyReportScreen({super.key});

  @override
  ConsumerState<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends ConsumerState<DailyReportScreen> {
  DateTime _selectedDate = DateTime.now();

  bool canAccess(String? role) => role == 'admin' || role == 'superadmin';

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _nextDay() {
    final tomorrow = _selectedDate.add(const Duration(days: 1));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (!tomorrow.isAfter(today)) {
      setState(() {
        _selectedDate = tomorrow;
      });
    }
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final role = session?.role ?? ref.watch(currentRoleProvider);

    if (!canAccess(role)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Daily Report')),
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

    final reportAsync = ref.watch(dailyReportProvider(_selectedDate));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('દૈનિક રિપોર્ટ (Daily Report)'),
        actions: [
          IconButton(
            tooltip: 'રિફ્રેશ કરો',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(dailyReportProvider(_selectedDate)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dailyReportProvider(_selectedDate));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDateSelector(),
              const SizedBox(height: 16),
              reportAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text(
                          'રિપોર્ટ લોડ થઈ રહ્યો છે...',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ),
                error: (e, _) => Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 36),
                        const SizedBox(height: 8),
                        Text(
                          'ડેટા લોડ કરવામાં ભૂલ: $e',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => ref.invalidate(dailyReportProvider(_selectedDate)),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('ફરી પ્રયાસ કરો'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (data) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSummaryCards(data),
                    if (data.totalReturns > 0) ...[
                      const SizedBox(height: 12),
                      _buildReturnsCard(data.totalReturns),
                    ],
                    const SizedBox(height: 16),
                    _buildSalesBreakdown(data.salesByMode),
                    const SizedBox(height: 16),
                    _buildExpensesBreakdown(data.expensesByCategory),
                    const SizedBox(height: 16),
                    _buildBillsList(data.bills),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isAtMaxDate = !_selectedDate.isBefore(today);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'અગાઉનો દિવસ',
              onPressed: _previousDay,
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                    });
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_today, size: 18, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('dd/MM/yyyy (EEEE)').format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'આગળનો દિવસ',
              onPressed: isAtMaxDate ? null : _nextDay,
            ),
            if (!_isToday)
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedDate = DateTime.now();
                  });
                },
                child: const Text('આજે'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(DailyReportData data) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'કુલ બિલ (Bills)',
                '${data.billCount}',
                const Color(0xFF2563EB),
                const Color(0xFFEFF6FF),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSummaryCard(
                'કુલ વેચાણ (Sales)',
                formatCurrency(data.totalSales),
                const Color(0xFF16A34A),
                const Color(0xFFF0FDF4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'કુલ ખર્ચ (Expenses)',
                formatCurrency(data.totalExpenses),
                const Color(0xFFDC2626),
                const Color(0xFFFEF2F2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSummaryCard(
                'ચોખ્ખો નફો (Net P&L)',
                formatCurrency(data.netPL),
                data.netPL >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                data.netPL >= 0 ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
              ),
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnsCard(double totalReturns) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                'પરત કરેલ રકમ (Returns Deducted):',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFC2410C)),
              ),
            ],
          ),
          Text(
            formatCurrency(totalReturns),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)),
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
              'ચૂકવણી મોડ મુજબ વેચાણ (Sales by Mode)',
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
                  padding: const EdgeInsets.symmetric(vertical: 6),
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

  Widget _buildExpensesBreakdown(Map<String, double> expensesByCategory) {
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
              'કેટેગરી મુજબ ખર્ચ (Expenses by Category)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (expensesByCategory.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('કોઈ ખર્ચ નથી', style: TextStyle(color: Color(0xFF64748B))),
              )
            else
              ...expensesByCategory.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
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

  Widget _buildBillsList(List<Bill> bills) {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'બિલ યાદી (Bills)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${bills.length} બિલ',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (bills.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'આ તારીખે કોઈ બિલ બનેલ નથી',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: bills.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final bill = bills[index];
                  final customerName = bill.customerNameSnapshot?.trim();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'બિલ #${bill.billNumber}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    subtitle: Text(
                      customerName != null && customerName.isNotEmpty ? customerName : 'વોક-ઇન ગ્રાહક',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatCurrency(bill.totalAmount),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                      ],
                    ),
                    onTap: () {
                      if (bill.id != null) {
                        context.push(AppRouter.billDetail, extra: bill.id!);
                      }
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
