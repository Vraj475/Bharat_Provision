import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'add_expense_screen.dart';
import '../../shared/models/expense_account_model.dart';
import '../../shared/models/expense_model.dart';
import '../../core/utils/currency_format.dart';
import 'expense_repository_provider.dart';

class ExpenseListScreen extends ConsumerStatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  ExpenseAccount? _selectedAccount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.of(context).pushNamed('/expenses/add'),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(child: _buildExpenseList()),
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
              Expanded(child: _buildAccountDropdown()),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _selectDateRange,
                child: const Text('Date Range'),
              ),
            ],
          ),
          if (_startDate != null && _endDate != null)
            Text(
              '${_startDate!.toString().split(' ')[0]} - ${_endDate!.toString().split(' ')[0]}',
            ),
        ],
      ),
    );
  }

  Widget _buildAccountDropdown() {
    return ref
        .watch(expenseRepositoryProvider)
        .when(
          data: (repo) => FutureBuilder<List<ExpenseAccount>>(
            future: repo.getExpenseAccounts(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final accounts = snapshot.data!;
              return DropdownButton<ExpenseAccount?>(
                value: _selectedAccount,
                hint: const Text('All Accounts'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All Accounts'),
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
          ),
          error: (error, stack) => Text('Error: $error'),
          loading: () => const CircularProgressIndicator(),
        );
  }

  void _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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
    return ref
        .watch(expenseRepositoryProvider)
        .when(
          data: (repo) => FutureBuilder<List<Expense>>(
            future: repo.getExpenses(
              startDate: _startDate,
              endDate: _endDate,
              accountId: _selectedAccount?.id,
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final expenses = snapshot.data!;
              if (expenses.isEmpty) {
                return const Center(child: Text('No expenses found'));
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
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Total: ${formatCurrency(total)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: grouped.length,
                      itemBuilder: (context, index) {
                        final date = grouped.keys.elementAt(index);
                        final dayExpenses = grouped[date]!;
                        final dayTotal = dayExpenses.fold(
                          0.0,
                          (sum, e) => sum + e.amount,
                        );
                        return ExpansionTile(
                          title: Text('$date - ${formatCurrency(dayTotal)}'),
                          children: dayExpenses
                              .map((expense) => _buildExpenseTile(expense))
                              .toList(),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          error: (error, stack) => Center(child: Text('Error: $error')),
          loading: () => const Center(child: CircularProgressIndicator()),
        );
  }

  Widget _buildExpenseTile(Expense expense) {
    return FutureBuilder<ExpenseAccount?>(
      future: _getAccountName(expense.expenseAccountId),
      builder: (context, snapshot) {
        final accountName = snapshot.data?.accountNameGujarati ?? 'Unknown';
        return ListTile(
          title: Text(accountName),
          subtitle: expense.description != null
              ? Text(expense.description!)
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(formatCurrency(expense.amount)),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editExpense(expense),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
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
    final repo = await ref.read(expenseRepositoryProvider.future);
    final accounts = await repo.getExpenseAccounts();
    return accounts.where((a) => a.id == accountId).firstOrNull;
  }

  void _editExpense(Expense expense) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddExpenseScreen(expense: expense)),
    );
    if (!mounted) return;
    setState(() {});
  }

  void _deleteExpense(Expense expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final repo = await ref.read(expenseRepositoryProvider.future);
      await repo.deleteExpense(expense.id!);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Expense deleted')));
    }
  }
}
