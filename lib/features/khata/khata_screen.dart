import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/currency_format.dart';
import '../../data/providers.dart';
import '../../routing/app_router.dart';

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

  Future<List<KhataLedgerRow>>? _creditFuture;
  Future<List<KhataLedgerRow>>? _debitFuture;
  Future<List<KhataLedgerRow>>? _allFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _reload();
  }

  void _reload() {
    setState(() {
      _creditFuture = _getCreditEntries();
      _debitFuture = _getDebitEntries();
      _allFuture = _getAllEntries();
    });
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
        title: const Text('ખાતાવહી (Khata)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'રિફ્રેશ કરો',
            onPressed: _reload,
          ),
        ],
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
                    labelText: 'નામ અથવા ખાતા વડે શોધો',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (value) => setState(() => _filterAccount = value.trim()),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _filterType,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('બધું')),
                  DropdownMenuItem(value: 'credit', child: Text('આવક')),
                  DropdownMenuItem(value: 'debit', child: Text('ખર્ચ')),
                ],
                onChanged: (value) => setState(() => _filterType = value!),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('તારીખ ગાળો: ', style: TextStyle(fontWeight: FontWeight.w600)),
              TextButton.icon(
                icon: const Icon(Icons.date_range, size: 18),
                onPressed: _selectDateRange,
                label: Text(
                  _dateRange == null
                      ? 'તમામ તારીખો'
                      : '${_dateRange!.start.toString().split(' ')[0]} થી ${_dateRange!.end.toString().split(' ')[0]}',
                ),
              ),
              if (_dateRange != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  tooltip: 'તારીખ ફિલ્ટર હટાવો',
                  onPressed: () {
                    setState(() => _dateRange = null);
                  },
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
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (range != null) {
      setState(() => _dateRange = range);
    }
  }

  Widget _buildCreditTab() {
    return FutureBuilder<List<KhataLedgerRow>>(
      future: _creditFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('ભૂલ: ${snapshot.error}'));
        }
        final entries = _filterEntries(snapshot.data ?? const []);
        if (entries.isEmpty) {
          return const Center(child: Text('કોઈ આવક નોંધ નથી'));
        }
        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) =>
              _buildEntryTile(entries[index], Colors.green),
        );
      },
    );
  }

  Widget _buildDebitTab() {
    return FutureBuilder<List<KhataLedgerRow>>(
      future: _debitFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('ભૂલ: ${snapshot.error}'));
        }
        final entries = _filterEntries(snapshot.data ?? const []);
        if (entries.isEmpty) {
          return const Center(child: Text('કોઈ ખર્ચ/ઉધાર નોંધ નથી'));
        }
        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) =>
              _buildEntryTile(entries[index], Colors.red),
        );
      },
    );
  }

  Widget _buildCombinedTab() {
    return FutureBuilder<List<KhataLedgerRow>>(
      future: _allFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('ભૂલ: ${snapshot.error}'));
        }
        final entries = _filterEntries(snapshot.data ?? const []);
        if (entries.isEmpty) {
          return const Center(child: Text('કોઈ નોંધ મળી નથી'));
        }
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

  Widget _buildEntryTile(KhataLedgerRow entry, Color color) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(
          entry.type == 'credit' ? Icons.arrow_downward : Icons.arrow_upward,
          color: color,
          size: 20,
        ),
      ),
      title: Text(
        entry.reference.isNotEmpty
            ? '${entry.accountName} (${entry.reference})'
            : entry.accountName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(entry.date.toString().split(' ')[0]),
      trailing: Text(
        formatCurrency(entry.amount),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
      ),
      onTap: () => _openEntrySource(entry),
    );
  }

  List<KhataLedgerRow> _filterEntries(List<KhataLedgerRow> entries) {
    final query = _filterAccount.toLowerCase();
    return entries.where((e) {
      final matchesAccount =
          query.isEmpty ||
          e.accountName.toLowerCase().contains(query) ||
          e.reference.toLowerCase().contains(query);
      final matchesType = _filterType == 'all' || e.type == _filterType;
      final matchesDate =
          _dateRange == null ||
          (!e.date.isBefore(
                DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day),
              ) &&
              !e.date.isAfter(
                DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day, 23, 59, 59),
              ));
      return matchesAccount && matchesType && matchesDate;
    }).toList();
  }

  void _openEntrySource(KhataLedgerRow entry) async {
    switch (entry.source) {
      case 'bill':
        context.push(AppRouter.billDetail, extra: entry.sourceId);
        return;
      case 'expense':
        final repo = ref.read(expenseRepositoryProvider);
        final expense = await repo.getExpenseById(entry.sourceId);
        if (!mounted) return;
        if (expense == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ખર્ચની વિગતો મળી નથી')),
          );
          return;
        }
        context.push(AppRouter.addExpense, extra: expense);
        return;
      case 'payment':
      case 'khata_entry':
        final db = await ref.read(databaseHelperProvider).database;
        final rows = await db.query(
          'khata_entries',
          columns: ['customer_id'],
          where: 'id = ?',
          whereArgs: [entry.sourceId],
          limit: 1,
        );
        if (!mounted) return;
        if (rows.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ખાતાની વિગતો મળી નથી')),
          );
          return;
        }
        final customerId = rows.first['customer_id'] as int;
        context.push(AppRouter.customerKhata, extra: customerId);
        return;
      default:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${entry.accountName}: ${entry.reference}')));
    }
  }

  Future<List<KhataLedgerRow>> _getCreditEntries() async {
    final db = await ref.read(databaseHelperProvider).database;
    final results = await db.rawQuery('''
      SELECT 'bill' as source, b.id as source_id, b.created_at as date, 
             COALESCE(c.name_gujarati, b.customer_name_snapshot, 'સામાન્ય ગ્રાહક') as account_name,
             CASE WHEN b.payment_mode = 'split' THEN b.paid_amount ELSE b.total_amount END as amount,
             b.payment_mode as reference, 'credit' as type
      FROM bills b
      LEFT JOIN customers c ON b.customer_id = c.id
      WHERE b.payment_mode IN ('cash', 'upi', 'card') OR (b.payment_mode = 'split' AND b.paid_amount > 0)
      UNION ALL
      SELECT 'payment' as source, ke.id as source_id, CAST(ke.date_time AS TEXT) as date,
             COALESCE(c.name_gujarati, 'ગ્રાહક') as account_name, ke.amount as amount,
             COALESCE(ke.note, 'ચુકવણી') as reference, 'credit' as type
      FROM khata_entries ke
      LEFT JOIN customers c ON ke.customer_id = c.id
      WHERE ke.type = 'credit'
      ORDER BY date DESC
    ''');
    return results.map((row) => KhataLedgerRow.fromMap(row)).toList();
  }

  Future<List<KhataLedgerRow>> _getDebitEntries() async {
    final db = await ref.read(databaseHelperProvider).database;
    final results = await db.rawQuery('''
      SELECT 'expense' as source, e.id as source_id, e.created_at as date,
             COALESCE(ea.account_name_gujarati, ea.account_name_english, e.account_name_snapshot, 'ખર્ચ') as account_name,
             e.amount as amount,
             COALESCE(e.description, '') as reference, 'debit' as type
      FROM expenses e
      LEFT JOIN expense_accounts ea ON e.expense_account_id = ea.id
      UNION ALL
      SELECT 'khata_entry' as source, ke.id as source_id, CAST(ke.date_time AS TEXT) as date,
             COALESCE(c.name_gujarati, 'ગ્રાહક') as account_name,
             ke.amount as amount,
             COALESCE(ke.note, 'ખાતા નોંધણી') as reference, 'debit' as type
      FROM khata_entries ke
      LEFT JOIN customers c ON ke.customer_id = c.id
      WHERE ke.type = 'debit'
      ORDER BY date DESC
    ''');
    return results.map((row) => KhataLedgerRow.fromMap(row)).toList();
  }

  Future<List<KhataLedgerRow>> _getAllEntries() async {
    final credit = await _getCreditEntries();
    final debit = await _getDebitEntries();
    final all = [...credit, ...debit];
    all.sort((a, b) => b.date.compareTo(a.date));
    return all;
  }
}

class KhataLedgerRow {
  KhataLedgerRow({
    required this.source,
    required this.sourceId,
    required this.date,
    required this.accountName,
    required this.amount,
    required this.reference,
    required this.type,
  });

  factory KhataLedgerRow.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate;
    final rawDate = map['date']?.toString();
    if (rawDate != null && rawDate.isNotEmpty) {
      final parsed = DateTime.tryParse(rawDate);
      if (parsed != null) {
        parsedDate = parsed;
      } else {
        final millis = int.tryParse(rawDate);
        parsedDate = millis != null
            ? DateTime.fromMillisecondsSinceEpoch(millis)
            : DateTime(1970);
      }
    } else {
      parsedDate = DateTime(1970);
    }
    return KhataLedgerRow(
      source: (map['source'] as String?) ?? '',
      sourceId: (map['source_id'] as num?)?.toInt() ?? 0,
      date: parsedDate,
      accountName: (map['account_name'] as String?) ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      reference: (map['reference'] as String?) ?? '',
      type: (map['type'] as String?) ?? 'credit',
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
