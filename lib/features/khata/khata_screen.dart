import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/currency_format.dart';
import '../../data/providers.dart';
import '../billing/bill_detail_screen.dart';
import '../expenses/add_expense_screen.dart';
import '../expenses/expense_repository_provider.dart';
import '../udhaar/customer_ledger_screen.dart';

class KhataScreen extends ConsumerStatefulWidget {
  const KhataScreen({super.key});

  @override
  ConsumerState<KhataScreen> createState() => _KhataScreenState();
}

class _KhataScreenState extends ConsumerState<KhataScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange? _dateRange;
  String _filterAccount = '';
  String _filterType = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Khata'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'આવક (Credit)'),
            Tab(text: 'ખર્ચ (Debit)'),
            Tab(text: 'બધું'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCreditTab(),
                _buildDebitTab(),
                _buildCombinedTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Filter by account',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _filterAccount = value),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _filterType,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'credit', child: Text('Credit')),
                  DropdownMenuItem(value: 'debit', child: Text('Debit')),
                ],
                onChanged: (value) => setState(() => _filterType = value!),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Date Range: '),
              TextButton(
                onPressed: _selectDateRange,
                child: Text(
                  _dateRange == null
                      ? 'Select Range'
                      : '${_dateRange!.start.toString().split(' ')[0]} - ${_dateRange!.end.toString().split(' ')[0]}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (range != null) {
      setState(() => _dateRange = range);
    }
  }

  Widget _buildCreditTab() {
    // Show credit entries: cash sales, upi, card, udhaar collected
    return FutureBuilder<List<KhataEntry>>(
      future: _getCreditEntries(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final entries = _filterEntries(snapshot.data!);
        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) =>
              _buildEntryTile(entries[index], Colors.green),
        );
      },
    );
  }

  Widget _buildDebitTab() {
    // Show debit entries: expenses
    return FutureBuilder<List<KhataEntry>>(
      future: _getDebitEntries(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final entries = _filterEntries(snapshot.data!);
        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) =>
              _buildEntryTile(entries[index], Colors.red),
        );
      },
    );
  }

  Widget _buildCombinedTab() {
    return FutureBuilder<List<KhataEntry>>(
      future: _getAllEntries(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final entries = _filterEntries(snapshot.data!);
        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final color = entry.type == 'credit' ? Colors.green : Colors.red;
            return _buildEntryTile(entry, color);
          },
        );
      },
    );
  }

  Widget _buildEntryTile(KhataEntry entry, Color color) {
    return ListTile(
      title: Text('${entry.accountName} - ${entry.reference}'),
      subtitle: Text(entry.date.toString().split(' ')[0]),
      trailing: Text(
        formatCurrency(entry.amount),
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
      onTap: () => _openEntrySource(entry),
    );
  }

  List<KhataEntry> _filterEntries(List<KhataEntry> entries) {
    return entries.where((e) {
      final matchesAccount =
          _filterAccount.isEmpty || e.accountName.contains(_filterAccount);
      final matchesType = _filterType == 'all' || e.type == _filterType;
      final matchesDate =
          _dateRange == null ||
          (e.date.isAfter(
                _dateRange!.start.subtract(const Duration(days: 1)),
              ) &&
              e.date.isBefore(_dateRange!.end.add(const Duration(days: 1))));
      return matchesAccount && matchesType && matchesDate;
    }).toList();
  }

  void _openEntrySource(KhataEntry entry) async {
    switch (entry.source) {
      case 'bill':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BillDetailScreen(billId: entry.sourceId),
          ),
        );
        return;
      case 'expense':
        final repo = await ref.read(expenseRepositoryProvider.future);
        final expense = await repo.getExpenseById(entry.sourceId);
        if (!mounted) return;
        if (expense == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense detail not found')),
          );
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddExpenseScreen(expense: expense)),
        );
        return;
      case 'payment':
        final db = await ref.read(databaseProvider.future);
        final rows = await db.query(
          'udhaar_payments',
          columns: ['customer_id'],
          where: 'id = ?',
          whereArgs: [entry.sourceId],
          limit: 1,
        );
        if (!mounted) return;
        if (rows.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment detail not found')),
          );
          return;
        }
        final customerId = rows.first['customer_id'] as int;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerLedgerScreen(customerId: customerId),
          ),
        );
        return;
      default:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Open ${entry.reference}')));
    }
  }

  Future<List<KhataEntry>> _getCreditEntries() async {
    final db = await ref.read(databaseProvider.future);
    final results = await db.rawQuery('''
      SELECT 'bill' as source, b.id as source_id, b.date_time as date, 
             COALESCE(c.name, 'Walk-in') as account_name, b.total_amount as amount,
             b.payment_mode as reference, 'credit' as type
      FROM bills b
      LEFT JOIN customers c ON b.customer_id = c.id
      WHERE b.payment_mode IN ('cash', 'upi', 'card')
      UNION ALL
      SELECT 'payment' as source, up.id as source_id, up.date as date,
             c.name as account_name, up.amount as amount,
             'Udhaar Payment' as reference, 'credit' as type
      FROM udhaar_payments up
      JOIN customers c ON up.customer_id = c.id
      ORDER BY date DESC
    ''');
    return results.map((row) => KhataEntry.fromMap(row)).toList();
  }

  Future<List<KhataEntry>> _getDebitEntries() async {
    final db = await ref.read(databaseProvider.future);
    final results = await db.rawQuery('''
      SELECT 'expense' as source, e.id as source_id, e.date as date,
             ea.name as account_name, e.amount as amount,
             COALESCE(e.description, '') as reference, 'debit' as type
      FROM expenses e
      JOIN expense_accounts ea ON e.expense_account_id = ea.id
      ORDER BY e.date DESC
    ''');
    return results.map((row) => KhataEntry.fromMap(row)).toList();
  }

  Future<List<KhataEntry>> _getAllEntries() async {
    final credit = await _getCreditEntries();
    final debit = await _getDebitEntries();
    final all = [...credit, ...debit];
    all.sort((a, b) => b.date.compareTo(a.date));
    return all;
  }
}

class KhataEntry {
  KhataEntry({
    required this.source,
    required this.sourceId,
    required this.date,
    required this.accountName,
    required this.amount,
    required this.reference,
    required this.type,
  });

  factory KhataEntry.fromMap(Map<String, dynamic> map) {
    return KhataEntry(
      source: map['source'] as String,
      sourceId: map['source_id'] as int,
      date: DateTime.parse(map['date'] as String),
      accountName: map['account_name'] as String,
      amount: (map['amount'] as num).toDouble(),
      reference: map['reference'] as String,
      type: map['type'] as String,
    );
  }

  final String source;
  final int sourceId;
  final DateTime date;
  final String accountName;
  final double amount;
  final String reference;
  final String type;
}
