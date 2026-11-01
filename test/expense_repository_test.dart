import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:bharat_provision/core/database/database_helper.dart';
import 'package:bharat_provision/data/repositories/expense_repository.dart';
import 'package:bharat_provision/shared/models/expense_account_model.dart';
import 'package:bharat_provision/shared/models/expense_model.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationSupportPath() async {
    final dir = Directory.systemTemp.createTempSync('expense_db_test');
    return dir.path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper dbHelper;
  late ExpenseRepository expenseRepo;
  late Database db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PathProviderPlatform.instance = MockPathProviderPlatform();
    dbHelper = DatabaseHelper.instance;
    db = await dbHelper.database;
  });

  tearDownAll(() async {
    await dbHelper.close();
  });

  setUp(() async {
    await db.delete('expenses');
    await db.delete('khata_ledger');
    await db.delete('expense_accounts');
    expenseRepo = ExpenseRepository(dbHelper);
  });

  tearDown(() async {
    await db.delete('expenses');
    await db.delete('khata_ledger');
    await db.delete('expense_accounts');
  });

  group('ExpenseRepository CRUD & Safety Tests', () {
    test('addExpense creates expense and dual-entry khata_ledger record', () async {
      final accId = await expenseRepo.addExpenseAccount(
        ExpenseAccount(
          accountNameGujarati: 'દુકાન ભાડું',
          accountNameEnglish: 'Shop Rent',
          accountType: 'fixed',
          typicalAmount: 5000.0,
          isActive: true,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      final expenseId = await expenseRepo.addExpense(
        Expense(
          expenseAccountId: accId,
          amount: 5000.0,
          description: 'ઓક્ટોબર મહિનાનું ભાડું',
          expenseDate: '2026-10-26T10:00:00.000',
          createdAt: DateTime.now().toIso8601String(),
        ),
        paymentMode: 'bank',
      );

      expect(expenseId, isPositive);

      // Verify expense record
      final fetched = await expenseRepo.getExpenseById(expenseId);
      expect(fetched, isNotNull);
      expect(fetched!.amount, 5000.0);
      expect(fetched.expenseAccountId, accId);
      expect(fetched.description, 'ઓક્ટોબર મહિનાનું ભાડું');

      // Verify khata_ledger entry
      final ledgerRows = await db.query(
        'khata_ledger',
        where: 'reference_type = ? AND reference_id = ?',
        whereArgs: ['expense', expenseId],
      );
      expect(ledgerRows.length, 1);
      final ledger = ledgerRows.first;
      expect(ledger['entry_type'], 'expense');
      expect(ledger['amount'], 5000.0);
      expect(ledger['payment_mode'], 'bank');
      expect(ledger['account_name'], 'દુકાન ભાડું');
      expect(ledger['entry_date'], '2026-10-26');
    });

    test('updateExpense updates both expense and khata_ledger', () async {
      final accId = await expenseRepo.addExpenseAccount(
        ExpenseAccount(
          accountNameGujarati: 'વીજળી બિલ',
          accountNameEnglish: 'Electricity',
          accountType: 'fixed',
          typicalAmount: 1200.0,
          isActive: true,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      final expenseId = await expenseRepo.addExpense(
        Expense(
          expenseAccountId: accId,
          amount: 1200.0,
          description: 'સપ્ટેમ્બર બિલ',
          expenseDate: '2026-09-15T12:00:00.000',
          createdAt: DateTime.now().toIso8601String(),
        ),
        paymentMode: 'cash',
      );

      // Update amount and description
      await expenseRepo.updateExpense(
        Expense(
          id: expenseId,
          expenseAccountId: accId,
          amount: 1350.0,
          description: 'સપ્ટેમ્બર બિલ + દંડ',
          expenseDate: '2026-09-15T12:00:00.000',
          createdAt: DateTime.now().toIso8601String(),
        ),
        paymentMode: 'bank',
      );

      final updated = await expenseRepo.getExpenseById(expenseId);
      expect(updated!.amount, 1350.0);
      expect(updated.description, 'સપ્ટેમ્બર બિલ + દંડ');

      final ledgerRows = await db.query(
        'khata_ledger',
        where: 'reference_type = ? AND reference_id = ?',
        whereArgs: ['expense', expenseId],
      );
      expect(ledgerRows.length, 1);
      expect(ledgerRows.first['amount'], 1350.0);
      expect(ledgerRows.first['payment_mode'], 'bank');
      expect(ledgerRows.first['note'], 'સપ્ટેમ્બર બિલ + દંડ');
    });

    test('deleteExpense removes both expense and khata_ledger record in transaction', () async {
      final accId = await expenseRepo.addExpenseAccount(
        ExpenseAccount(
          accountNameGujarati: 'ચા-નાસ્તો',
          accountNameEnglish: 'Tea',
          accountType: 'variable',
          typicalAmount: 100.0,
          isActive: true,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      final expenseId = await expenseRepo.addExpense(
        Expense(
          expenseAccountId: accId,
          amount: 150.0,
          description: 'મેહમાન ચા',
          expenseDate: '2026-10-26T11:00:00.000',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      await expenseRepo.deleteExpense(expenseId);

      final fetched = await expenseRepo.getExpenseById(expenseId);
      expect(fetched, isNull);

      final ledgerRows = await db.query(
        'khata_ledger',
        where: 'reference_type = ? AND reference_id = ?',
        whereArgs: ['expense', expenseId],
      );
      expect(ledgerRows, isEmpty);
    });

    test('getExpenses filters accurately by date range and accountId', () async {
      final acc1 = await expenseRepo.addExpenseAccount(
        ExpenseAccount(
          accountNameGujarati: 'પગાર',
          accountType: 'fixed',
          typicalAmount: 8000.0,
          isActive: true,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      final acc2 = await expenseRepo.addExpenseAccount(
        ExpenseAccount(
          accountNameGujarati: 'સ્ટેશનરી',
          accountType: 'variable',
          typicalAmount: 200.0,
          isActive: true,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      // Add expense on 2026-10-20
      await expenseRepo.addExpense(
        Expense(
          expenseAccountId: acc1,
          amount: 8000.0,
          expenseDate: '2026-10-20T10:00:00.000',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      // Add expense on 2026-10-25
      await expenseRepo.addExpense(
        Expense(
          expenseAccountId: acc2,
          amount: 250.0,
          expenseDate: '2026-10-25T14:30:00.000',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      // Add return record (should be excluded from general expenses)
      await db.insert('expenses', {
        'expense_account_id': acc1,
        'account_name_snapshot': 'રીટર્ન',
        'amount': 500.0,
        'expense_date': '2026-10-25T15:00:00.000',
        'created_by': 'return',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Filter: today only (2026-10-26)
      final todayList = await expenseRepo.getExpenses(
        startDate: DateTime(2026, 10, 26),
        endDate: DateTime(2026, 10, 26),
      );
      expect(todayList, isEmpty);

      // Filter: date range 2026-10-20 to 2026-10-25
      final rangeList = await expenseRepo.getExpenses(
        startDate: DateTime(2026, 10, 20),
        endDate: DateTime(2026, 10, 25),
      );
      expect(rangeList.length, 2);

      // Filter by account
      final acc1List = await expenseRepo.getExpenses(accountId: acc1);
      expect(acc1List.length, 1);
      expect(acc1List.first.amount, 8000.0);
    });

    test('resetExpenseAccountsToDefaults safely preserves accounts referenced by expenses', () async {
      // 1. Add custom account
      final customId = await expenseRepo.addExpenseAccount(
        ExpenseAccount(
          accountNameGujarati: 'કસ્ટમ ખાતું',
          accountType: 'variable',
          typicalAmount: 50.0,
          isActive: true,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      // 2. Add an expense referencing this custom account
      await expenseRepo.addExpense(
        Expense(
          expenseAccountId: customId,
          amount: 100.0,
          expenseDate: '2026-10-26T12:00:00.000',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      // 3. Reset to defaults - must NOT throw SQLite foreign key constraint exception
      await expenseRepo.resetExpenseAccountsToDefaults();

      // 4. Verify all accounts: default 6 accounts should exist, and referenced custom account should still exist
      final allAccounts = await expenseRepo.getExpenseAccounts(activeOnly: false);
      expect(allAccounts.any((a) => a.id == customId), isTrue);

      final gujaratiNames = allAccounts.map((a) => a.accountNameGujarati).toSet();
      expect(gujaratiNames.contains('ભાડું'), isTrue);
      expect(gujaratiNames.contains('વીજળી'), isTrue);
      expect(gujaratiNames.contains('પગાર'), isTrue);
      expect(gujaratiNames.contains('ફોન'), isTrue);
      expect(gujaratiNames.contains('ખરીદી'), isTrue);
      expect(gujaratiNames.contains('અન્ય'), isTrue);
    });

    test('addExpenseAccount inserts account and deleteExpenseAccount deletes it from database', () async {
      // 1. Insert new account into SQLite database
      final newAccId = await expenseRepo.addExpenseAccount(
        ExpenseAccount(
          accountNameGujarati: 'પેકિંગ ખર્ચ',
          accountNameEnglish: 'Packing Expense',
          accountType: 'variable',
          typicalAmount: 300.0,
          isActive: true,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      expect(newAccId, isPositive);

      // Verify account exists in database
      var accounts = await expenseRepo.getExpenseAccounts(activeOnly: false);
      expect(accounts.any((a) => a.id == newAccId && a.accountNameGujarati == 'પેકિંગ ખર્ચ'), isTrue);

      // 2. Delete the account from SQLite database
      await expenseRepo.deleteExpenseAccount(newAccId);

      // Verify account no longer exists in database
      accounts = await expenseRepo.getExpenseAccounts(activeOnly: false);
      expect(accounts.any((a) => a.id == newAccId), isFalse);
    });

    test('deleteExpenseAccount safely handles foreign keys with existing expenses', () async {
      // 1. Create account
      final accId = await expenseRepo.addExpenseAccount(
        ExpenseAccount(
          accountNameGujarati: 'ચા-નાસ્તો',
          accountNameEnglish: 'Tea & Snacks',
          accountType: 'variable',
          typicalAmount: 150.0,
          isActive: true,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      // 2. Create expense linked to this account
      final expenseId = await expenseRepo.addExpense(
        Expense(
          expenseAccountId: accId,
          amount: 150.0,
          description: 'નાસ્તો',
          expenseDate: '2026-10-28T10:00:00.000',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      expect(await expenseRepo.countExpensesForAccount(accId), 1);

      // 3. Delete account - should not throw foreign key constraint error
      await expenseRepo.deleteExpenseAccount(accId);

      // Account must be gone
      final accounts = await expenseRepo.getExpenseAccounts(activeOnly: false);
      expect(accounts.any((a) => a.id == accId), isFalse);

      // Expense must still exist with intact amount and snapshot, but nullified expense_account_id
      final expense = await expenseRepo.getExpenseById(expenseId);
      expect(expense, isNotNull);
      expect(expense!.amount, 150.0);
      expect(expense.accountNameSnapshot, 'ચા-નાસ્તો');
      expect(expense.expenseAccountId, isNull);
    });

    test('toggleExpenseAccountStatus updates is_active flag in database', () async {
      final accId = await expenseRepo.addExpenseAccount(
        ExpenseAccount(
          accountNameGujarati: 'સાફ-સફાઈ',
          accountType: 'variable',
          typicalAmount: 200.0,
          isActive: true,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      // Toggle to inactive
      await expenseRepo.toggleExpenseAccountStatus(accId, false);

      var activeAccounts = await expenseRepo.getExpenseAccounts(activeOnly: true);
      expect(activeAccounts.any((a) => a.id == accId), isFalse);

      var allAccounts = await expenseRepo.getExpenseAccounts(activeOnly: false);
      final acc = allAccounts.firstWhere((a) => a.id == accId);
      expect(acc.isActive, isFalse);

      // Toggle back to active
      await expenseRepo.toggleExpenseAccountStatus(accId, true);
      activeAccounts = await expenseRepo.getExpenseAccounts(activeOnly: true);
      expect(activeAccounts.any((a) => a.id == accId), isTrue);
    });
  });
}
