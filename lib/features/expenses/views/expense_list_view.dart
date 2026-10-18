import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_format.dart';
import '../../../../routing/app_router.dart';
import '../../../../shared/models/expense_account_model.dart';
import '../../../../shared/models/expense_model.dart';
import '../expense_repository_provider.dart';

class ExpenseListView extends ConsumerStatefulWidget {
  final bool showAppBar;
  const ExpenseListView({super.key, this.showAppBar = false});

  @override
  ConsumerState<ExpenseListView> createState() => _ExpenseListViewState();
}

class _ExpenseListViewState extends ConsumerState<ExpenseListView> {
  DateTime? _startDate;
  DateTime? _endDate;
  ExpenseAccount? _selectedAccount;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        _buildFilters(),
        const Divider(height: 1),
        Expanded(child: _buildExpenseList()),
      ],
    );

    if (widget.showAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('ખર્ચ (Expenses)'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => context.push(AppRouter.addExpense),
            ),
          ],
        ),
        body: body,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(AppRouter.addExpense),
          icon: const Icon(Icons.add),
          label: const Text('નવો ખર્ચ (Add Expense)'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      );
    }

    return Scaffold(
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRouter.addExpense),
        icon: const Icon(Icons.add),
        label: const Text('નવો ખર્ચ (Add Expense)'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(child: _buildAccountDropdown()),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _selectDateRange,
            icon: const Icon(Icons.date_range, size: 18),
            label: Text(
              _startDate != null && _endDate != null
                  ? '${_startDate!.day}/${_startDate!.month} - ${_endDate!.day}/${_endDate!.month}'
                  : 'તારીખ પસંદ કરો',
            ),
          ),
          if (_startDate != null) ...[
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'તારીખ ફિલ્ટર હટાવો',
              onPressed: () => setState(() {
                _startDate = null;
                _endDate = null;
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountDropdown() {
    final repo = ref.watch(expenseRepositoryProvider);
    return FutureBuilder<List<ExpenseAccount>>(
      future: repo.getExpenseAccounts(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final accounts = snapshot.data!;
        return DropdownButtonFormField<ExpenseAccount?>(
          key: ValueKey(_selectedAccount?.id),
          initialValue: _selectedAccount,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'ખાતું (Account)',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('બધા ખાતા (All Accounts)'),
            ),
            ...accounts.map((account) {
              return DropdownMenuItem(
                value: account,
                child: Text(account.accountNameGujarati),
              );
            }),
          ],
          onChanged: (value) => setState(() => _selectedAccount = value),
        );
      },
    );
  }

  void _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
    }
  }

  Widget _buildExpenseList() {
    final repo = ref.watch(expenseRepositoryProvider);
    return FutureBuilder<List<Expense>>(
      future: repo.getExpenses(
        startDate: _startDate,
        endDate: _endDate,
        accountId: _selectedAccount?.id,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final expenses = snapshot.data ?? [];
        if (expenses.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.money_off_csred_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text(
                  'કોઈ ખર્ચ મળ્યો નથી',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }

        // Group by date
        final grouped = <String, List<Expense>>{};
        for (final expense in expenses) {
          final date = expense.expenseDate.split('T').first;
          grouped.putIfAbsent(date, () => []).add(expense);
        }

        final total = expenses.fold(0.0, (sum, e) => sum + e.amount);

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.grey.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'કુલ નોંધ: ${expenses.length}',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  Text(
                    'કુલ ખર્ચ: ${formatCurrency(total)}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.alert,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: grouped.length,
                itemBuilder: (context, index) {
                  final date = grouped.keys.elementAt(index);
                  final dayExpenses = grouped[date]!;
                  final dayTotal = dayExpenses.fold(
                    0.0,
                    (sum, e) => sum + e.amount,
                  );
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: AppColors.divider),
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      shape: const Border(),
                      title: Text(
                        date,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      trailing: Text(
                        formatCurrency(dayTotal),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.alert,
                        ),
                      ),
                      children: dayExpenses
                          .map((expense) => _buildExpenseTile(expense))
                          .toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExpenseTile(Expense expense) {
    return FutureBuilder<ExpenseAccount?>(
      future: _getAccountName(expense.expenseAccountId),
      builder: (context, snapshot) {
        final accountName = snapshot.data?.accountNameGujarati ??
            expense.accountNameSnapshot ??
            'ખર્ચ';
        return ListTile(
          dense: true,
          title: Text(
            accountName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: expense.description != null ? Text(expense.description!) : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatCurrency(expense.amount),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: () => _editExpense(expense),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.alert),
                onPressed: () => _deleteExpense(expense),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<ExpenseAccount?> _getAccountName(int? accountId) async {
    if (accountId == null) return null;
    final repo = ref.read(expenseRepositoryProvider);
    final accounts = await repo.getExpenseAccounts();
    return accounts.where((a) => a.id == accountId).firstOrNull;
  }

  void _editExpense(Expense expense) async {
    await context.push(AppRouter.addExpense, extra: expense);
    if (!mounted) return;
    setState(() {});
  }

  void _deleteExpense(Expense expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ખર્ચ કાઢી નાખો?'),
        content: const Text('શું તમે ખરેખર આ ખર્ચ કાઢી નાખવા માંગો છો?'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('રદ કરો'),
          ),
          ElevatedButton(
            onPressed: () => context.pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.alert, foregroundColor: Colors.white),
            child: const Text('કાઢી નાખો'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final repo = ref.read(expenseRepositoryProvider);
      await repo.deleteExpense(expense.id!);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ખર્ચ કાઢી નાખવામાં આવ્યો છે.')),
      );
    }
  }
}
