import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../shared/models/expense_account_model.dart';
import '../../shared/models/expense_model.dart';

class ExpenseRepository {
  ExpenseRepository([DatabaseHelper? dbHelper])
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  Future<List<ExpenseAccount>> getExpenseAccounts({bool activeOnly = true}) async {
    final db = await _dbHelper.database;
    var results = await db.query(
      'expense_accounts',
      where: activeOnly ? 'is_active = ?' : null,
      whereArgs: activeOnly ? [1] : null,
      orderBy: 'account_name_gujarati ASC',
    );
    if (results.isEmpty) {
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM expense_accounts'),
      );
      if ((count ?? 0) == 0) {
        await resetExpenseAccountsToDefaults();
        results = await db.query(
          'expense_accounts',
          where: activeOnly ? 'is_active = ?' : null,
          whereArgs: activeOnly ? [1] : null,
          orderBy: 'account_name_gujarati ASC',
        );
      }
    }
    return results.map((row) => ExpenseAccount.fromMap(row)).toList();
  }

  Future<int> addExpense(Expense expense, {String paymentMode = 'cash'}) async {
    final db = await _dbHelper.database;
    return db.transaction((txn) async {
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

      final expenseMap = expense.toMap();
      if (expense.accountNameSnapshot == null ||
          expense.accountNameSnapshot!.isEmpty) {
        expenseMap['account_name_snapshot'] = accountName;
      }

      final expenseId = await txn.insert('expenses', expenseMap);

      final dateStr = expense.expenseDate.length >= 10
          ? expense.expenseDate.substring(0, 10)
          : expense.expenseDate;

      await txn.insert('khata_ledger', {
        'entry_type': 'expense',
        'account_name': accountName,
        'customer_id': null,
        'amount': expense.amount,
        'payment_mode': paymentMode,
        'reference_type': 'expense',
        'reference_id': expenseId,
        'note': expense.description,
        'entry_date': dateStr,
        'created_at': DateTime.now().toIso8601String(),
      });

      return expenseId;
    });
  }

  Future<Expense?> getExpenseById(int id) async {
    final db = await _dbHelper.database;
    final rows = await db.query('expenses', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Expense.fromMap(rows.first);
  }

  Future<void> updateExpense(Expense expense, {String paymentMode = 'cash'}) async {
    if (expense.id == null) return;
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
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

      final expenseMap = expense.toMap();
      if (expense.accountNameSnapshot == null ||
          expense.accountNameSnapshot!.isEmpty) {
        expenseMap['account_name_snapshot'] = accountName;
      }

      await txn.update(
        'expenses',
        expenseMap,
        where: 'id = ?',
        whereArgs: [expense.id],
      );

      final dateStr = expense.expenseDate.length >= 10
          ? expense.expenseDate.substring(0, 10)
          : expense.expenseDate;

      final updatedCount = await txn.update(
        'khata_ledger',
        {
          'account_name': accountName,
          'amount': expense.amount,
          'payment_mode': paymentMode,
          'note': expense.description,
          'entry_date': dateStr,
        },
        where: 'reference_type = ? AND reference_id = ?',
        whereArgs: ['expense', expense.id],
      );

      if (updatedCount == 0) {
        await txn.insert('khata_ledger', {
          'entry_type': 'expense',
          'account_name': accountName,
          'customer_id': null,
          'amount': expense.amount,
          'payment_mode': paymentMode,
          'reference_type': 'expense',
          'reference_id': expense.id,
          'note': expense.description,
          'entry_date': dateStr,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<int> addExpenseAccount(ExpenseAccount account) async {
    final db = await _dbHelper.database;
    return db.insert('expense_accounts', account.toMap());
  }

  Future<void> updateExpenseAccount(ExpenseAccount account) async {
    if (account.id == null) return;
    final db = await _dbHelper.database;
    await db.update(
      'expense_accounts',
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<void> toggleExpenseAccountStatus(int id, bool isActive) async {
    final db = await _dbHelper.database;
    await db.update(
      'expense_accounts',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> countExpensesForAccount(int id) async {
    final db = await _dbHelper.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM expenses WHERE expense_account_id = ?',
        [id],
      ),
    );
    return count ?? 0;
  }

  Future<void> deleteExpenseAccount(int id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // 1. Decouple existing expenses so foreign key constraint does not fail,
      // while preserving historical account_name_snapshot on the expense record
      await txn.update(
        'expenses',
        {'expense_account_id': null},
        where: 'expense_account_id = ?',
        whereArgs: [id],
      );

      // 2. Delete the account
      await txn.delete(
        'expense_accounts',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> resetExpenseAccountsToDefaults() async {
    final now = DateTime.now().toIso8601String();
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // Find accounts that are currently referenced by existing expenses to avoid foreign key errors
      final referencedRows = await txn.rawQuery(
        'SELECT DISTINCT expense_account_id FROM expenses WHERE expense_account_id IS NOT NULL',
      );
      final referencedIds = referencedRows
          .map((r) => r['expense_account_id'] as int?)
          .whereType<int>()
          .toSet();

      // Delete only non-referenced accounts
      if (referencedIds.isEmpty) {
        await txn.delete('expense_accounts');
      } else {
        final placeholders = referencedIds.map((_) => '?').join(',');
        await txn.delete(
          'expense_accounts',
          where: 'id NOT IN ($placeholders)',
          whereArgs: referencedIds.toList(),
        );
        // Deactivate referenced accounts that are not default
        await txn.rawUpdate(
          'UPDATE expense_accounts SET is_active = 0 WHERE id IN ($placeholders)',
          referencedIds.toList(),
        );
      }

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
        final existing = await txn.query(
          'expense_accounts',
          where: 'account_name_gujarati = ?',
          whereArgs: [row['account_name_gujarati']],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          final id = existing.first['id'] as int;
          await txn.update(
            'expense_accounts',
            {
              'account_name_english': row['account_name_english'],
              'account_type': row['account_type'],
              'typical_amount': row['typical_amount'],
              'is_active': 1,
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        } else {
          await txn.insert('expense_accounts', {
            ...row,
            'is_active': 1,
            'created_at': now,
          });
        }
      }
    });
  }

  Future<List<Expense>> getExpenses({
    DateTime? startDate,
    DateTime? endDate,
    int? accountId,
  }) async {
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (startDate != null) {
      whereClauses.add('SUBSTR(expense_date, 1, 10) >= ?');
      whereArgs.add(startDate.toIso8601String().substring(0, 10));
    }
    if (endDate != null) {
      whereClauses.add('SUBSTR(expense_date, 1, 10) <= ?');
      whereArgs.add(endDate.toIso8601String().substring(0, 10));
    }
    if (accountId != null) {
      whereClauses.add('expense_account_id = ?');
      whereArgs.add(accountId);
    }

    // Customer returns are not store operating expenses
    whereClauses.add("(created_by IS NULL OR created_by != 'return')");

    final where = whereClauses.join(' AND ');

    final db = await _dbHelper.database;
    final results = await db.query(
      'expenses',
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'expense_date DESC, id DESC',
    );
    return results.map((row) => Expense.fromMap(row)).toList();
  }

  Future<void> deleteExpense(int id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('expenses', where: 'id = ?', whereArgs: [id]);
      await txn.delete(
        'khata_ledger',
        where: 'reference_type = ? AND reference_id = ?',
        whereArgs: ['expense', id],
      );
    });
  }
}
