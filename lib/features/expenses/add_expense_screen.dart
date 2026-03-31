import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/expense_repository.dart';
import '../../shared/models/expense_account_model.dart';
import '../../shared/models/expense_model.dart';
import '../../core/utils/currency_format.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key, this.expense});

  final Expense? expense;

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  ExpenseAccount? _selectedAccount;
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _amountEdited = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.expense;
    if (initial != null) {
      _amountController.text = initial.amount.toString();
      _descriptionController.text = initial.description ?? '';
      _selectedDate = DateTime.tryParse(initial.expenseDate) ?? DateTime.now();
      _amountEdited = true;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense == null ? 'Add Expense' : 'Edit Expense'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildAccountDropdown(),
              const SizedBox(height: 16),
              _buildAmountField(),
              const SizedBox(height: 16),
              _buildDescriptionField(),
              const SizedBox(height: 16),
              _buildDateField(),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveExpense,
                child: Text(
                  widget.expense == null ? 'Save Expense' : 'Update Expense',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountDropdown() {
    return ref.watch(expenseRepositoryProvider).when(
      data: (repo) => FutureBuilder<List<ExpenseAccount>>(
        future: repo.getExpenseAccounts(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const CircularProgressIndicator();
          final accounts = snapshot.data!;
          if (_selectedAccount == null && widget.expense?.expenseAccountId != null) {
            _selectedAccount = accounts
                .where((a) => a.id == widget.expense!.expenseAccountId)
                .firstOrNull;
          }
          return DropdownButtonFormField<ExpenseAccount>(
            decoration: const InputDecoration(
              labelText: 'Expense Account',
              border: OutlineInputBorder(),
            ),
            initialValue: _selectedAccount,
            items: accounts.map((account) {
              return DropdownMenuItem(
                value: account,
                child: Text(account.accountNameGujarati),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedAccount = value;
                if (!_amountEdited && value != null) {
                  _amountController.text = value.typicalAmount.toString();
                }
              });
            },
            validator: (value) {
              return value == null ? 'Please select an account' : null;
            },
          );
        },
      ),
      error: (error, stack) => Text('Error: $error'),
      loading: () => const CircularProgressIndicator(),
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      decoration: InputDecoration(
        labelText: 'Amount',
        border: const OutlineInputBorder(),
        hintText: _selectedAccount != null && !_amountEdited
            ? formatCurrency(_selectedAccount!.typicalAmount)
            : null,
        hintStyle: const TextStyle(color: Colors.grey),
      ),
      keyboardType: TextInputType.number,
      onChanged: (value) {
        if (!_amountEdited && value != _selectedAccount?.typicalAmount.toString()) {
          setState(() => _amountEdited = true);
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter amount';
        final amount = double.tryParse(value);
        if (amount == null || amount <= 0) return 'Please enter valid amount';
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: 'Description (Optional)',
        border: OutlineInputBorder(),
      ),
      maxLines: 3,
    );
  }

  Widget _buildDateField() {
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
              setState(() => _selectedDate = date);
            }
          },
          child: Text(_selectedDate.toString().split(' ')[0]),
        ),
      ],
    );
  }

  void _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccount == null) return;

    final amount = double.parse(_amountController.text);
    final expense = Expense(
      id: widget.expense?.id,
      expenseAccountId: _selectedAccount!.id!,
      accountNameSnapshot: _selectedAccount!.accountNameGujarati,
      amount: amount,
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
      expenseDate: _selectedDate.toIso8601String(),
      createdAt: widget.expense?.createdAt ?? DateTime.now().toIso8601String(),
    );

    final repo = await ref.read(expenseRepositoryProvider.future);
    if (widget.expense == null) {
      await repo.addExpense(expense);
    } else {
      await repo.updateExpense(expense);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.expense == null
                ? 'Expense added successfully'
                : 'Expense updated successfully',
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }
}

final expenseRepositoryProvider = FutureProvider<ExpenseRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return ExpenseRepository(db);
});