import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../shared/models/expense_account_model.dart';
import '../../shared/models/expense_model.dart';

class ExpenseRepository {
  ExpenseRepository(this._db);

  final Database _db;

  Future<List<ExpenseAccount>> getExpenseAccounts() async {
    final results = await _db.query(
      'expense_accounts',
      where: 'is_active = ?',
      whereArgs: [1],
    );
    return results.map((row) => ExpenseAccount.fromMap(row)).toList();
  }

  Future<int> addExpense(Expense expense) async {
    return _db.transaction((txn) async {
      final expenseId = await txn.insert('expenses', expense.toMap());

      String accountName = expense.accountNameSnapshot ?? 'ખર્ચ';
      if (expense.expenseAccountId != null) {
        final accountRows = await txn.query(
          'expense_accounts',
          columns: ['account_name_gujarati'],
          where: 'id = ?',
          whereArgs: [expense.expenseAccountId],
          limit: 1,
        );
        if (accountRows.isNotEmpty) {
          accountName =
              (accountRows.first['account_name_gujarati'] as String?) ??
              accountName;
        }
      }

      final entryDate = expense.expenseDate.split('T').first;
      final createdAt = DateTime.now().toIso8601String();
      await txn.insert('khata_ledger', {
        'entry_type': 'debit',
        'account_name': accountName,
        'customer_id': null,
        'amount': expense.amount,
        'payment_mode': null,
        'reference_type': 'expense',
        'reference_id': expenseId,
        'note': expense.description,
        'entry_date': entryDate,
        'created_at': createdAt,
      });

      return expenseId;
    });
  }

  Future<Expense?> getExpenseById(int id) async {
    final rows = await _db.query('expenses', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Expense.fromMap(rows.first);
  }

  Future<void> updateExpense(Expense expense) async {
    if (expense.id == null) return;
    await _db.transaction((txn) async {
      await txn.update(
        'expenses',
        expense.toMap(),
        where: 'id = ?',
        whereArgs: [expense.id],
      );

      String accountName = expense.accountNameSnapshot ?? 'ખર્ચ';
      if (expense.expenseAccountId != null) {
        final accountRows = await txn.query(
          'expense_accounts',
          columns: ['account_name_gujarati'],
          where: 'id = ?',
          whereArgs: [expense.expenseAccountId],
          limit: 1,
        );
        if (accountRows.isNotEmpty) {
          accountName =
              (accountRows.first['account_name_gujarati'] as String?) ??
              accountName;
        }
      }

      await txn.update(
        'khata_ledger',
        {
          'account_name': accountName,
          'amount': expense.amount,
          'note': expense.description,
          'entry_date': expense.expenseDate.split('T').first,
        },
        where: 'reference_type = ? AND reference_id = ?',
        whereArgs: ['expense', expense.id],
      );
    });
  }

  Future<int> addExpenseAccount(ExpenseAccount account) async {
    return _db.insert('expense_accounts', account.toMap());
  }

  Future<void> updateExpenseAccount(ExpenseAccount account) async {
    if (account.id == null) return;
    await _db.update(
      'expense_accounts',
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<void> toggleExpenseAccountStatus(int id, bool isActive) async {
    await _db.update(
      'expense_accounts',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> resetExpenseAccountsToDefaults() async {
    final now = DateTime.now().toIso8601String();
    await _db.transaction((txn) async {
      await txn.delete('expense_accounts');
      const defaults = [
        {
          'account_name_gujarati': 'ભાડું',
          'account_name_english': 'Rent',
          'account_type': 'fixed',
          'typical_amount': 15000.0,
        },
        {
          'account_name_gujarati': 'વીજળી',
          'account_name_english': 'Electricity',
          'account_type': 'fixed',
          'typical_amount': 3000.0,
        },
        {
          'account_name_gujarati': 'પગાર',
          'account_name_english': 'Salary',
          'account_type': 'fixed',
          'typical_amount': 8000.0,
        },
        {
          'account_name_gujarati': 'ફોન',
          'account_name_english': 'Phone/Internet',
          'account_type': 'fixed',
          'typical_amount': 500.0,
        },
        {
          'account_name_gujarati': 'ખરીદી',
          'account_name_english': 'Purchase',
          'account_type': 'variable',
          'typical_amount': 0.0,
        },
        {
          'account_name_gujarati': 'અન્ય',
          'account_name_english': 'Other',
          'account_type': 'variable',
          'typical_amount': 0.0,
        },
      ];

      for (final row in defaults) {
        await txn.insert('expense_accounts', {
          ...row,
          'is_active': 1,
          'created_at': now,
        });
      }
    });
  }

  Future<List<Expense>> getExpenses({
    DateTime? startDate,
    DateTime? endDate,
    int? accountId,
  }) async {
    String where = '';
    List<dynamic> whereArgs = [];
    if (startDate != null) {
      where += 'date >= ?';
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      if (where.isNotEmpty) where += ' AND ';
      where += 'date < ?';
      whereArgs.add(endDate.toIso8601String());
    }
    if (accountId != null) {
      if (where.isNotEmpty) where += ' AND ';
      where += 'expense_account_id = ?';
      whereArgs.add(accountId);
    }

    final results = await _db.query(
      'expenses',
      where: where.isEmpty ? null : where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'date DESC',
    );
    return results.map((row) => Expense.fromMap(row)).toList();
  }

  Future<void> deleteExpense(int id) async {
    await _db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }
}
