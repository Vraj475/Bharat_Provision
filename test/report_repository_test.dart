import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:bharat_provision/core/database/database_helper.dart';
import 'package:bharat_provision/data/repositories/report_repository.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationSupportPath() async {
    final dir = Directory.systemTemp.createTempSync('report_db_test');
    return dir.path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper dbHelper;
  late ReportRepository reportRepo;
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
    await db.delete('bills');
    await db.delete('expenses');
    await db.delete('returns');
    await db.delete('customers');
    await db.delete('expense_accounts');
    reportRepo = ReportRepository(dbHelper);
  });

  tearDown(() async {
    await db.delete('bills');
    await db.delete('expenses');
    await db.delete('returns');
    await db.delete('customers');
    await db.delete('expense_accounts');
  });

  group('ReportRepository Tests', () {
    test('getSalesSummary accurately calculates sales, bills count, and deducts returns', () async {
      final today = DateTime.now();
      final todayStr = today.toIso8601String().substring(0, 10);

      // Insert 2 bills
      await db.insert('bills', {
        'bill_number': 'B-101',
        'bill_date': todayStr,
        'subtotal': 500.0,
        'discount': 0.0,
        'gst_amount': 0.0,
        'other_charges': 0.0,
        'total_amount': 500.0,
        'paid_amount': 500.0,
        'payment_mode': 'cash',
        'created_at': '${todayStr}T10:00:00.000',
      });

      await db.insert('bills', {
        'bill_number': 'B-102',
        'bill_date': todayStr,
        'subtotal': 300.0,
        'discount': 0.0,
        'gst_amount': 0.0,
        'other_charges': 0.0,
        'total_amount': 300.0,
        'paid_amount': 300.0,
        'payment_mode': 'upi',
        'created_at': '${todayStr}T12:00:00.000',
      });

      // Insert return of 100 Rs
      await db.insert('returns', {
        'return_date': '${todayStr}T14:00:00.000',
        'total_return_value': 100.0,
        'return_mode': 'cash',
      });

      final startEpoch = DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
      final endEpoch = DateTime(today.year, today.month, today.day, 23, 59, 59).millisecondsSinceEpoch;

      final summary = await reportRepo.getSalesSummary(startEpoch, endEpoch);

      expect(summary.billCount, 2);
      expect(summary.totalSales, 700.0); // 500 + 300 - 100
      expect(summary.avgBillValue, 400.0); // 800 / 2
    });

    test('getPLSummary includes split, online, upi, and cash modes and deducts expenses & returns', () async {
      final today = DateTime.now();
      final todayStr = today.toIso8601String().substring(0, 10);

      // Bill 1: cash 400
      await db.insert('bills', {
        'bill_number': 'B-201',
        'bill_date': todayStr,
        'subtotal': 400.0,
        'discount': 0.0,
        'gst_amount': 0.0,
        'total_amount': 400.0,
        'paid_amount': 400.0,
        'payment_mode': 'cash',
        'created_at': '${todayStr}T09:00:00.000',
      });

      // Bill 2: split 600
      await db.insert('bills', {
        'bill_number': 'B-202',
        'bill_date': todayStr,
        'subtotal': 600.0,
        'discount': 0.0,
        'gst_amount': 0.0,
        'total_amount': 600.0,
        'paid_amount': 600.0,
        'payment_mode': 'split',
        'created_at': '${todayStr}T11:00:00.000',
      });

      // Expense Account and Expense of 250
      final accId = await db.insert('expense_accounts', {
        'account_name_gujarati': 'દુકાન ભાડું',
        'is_active': 1,
        'created_at': '${todayStr}T08:00:00.000',
      });

      await db.insert('expenses', {
        'expense_account_id': accId,
        'amount': 250.0,
        'expense_date': todayStr,
        'created_at': '${todayStr}T08:30:00.000',
      });

      // Return of 50
      await db.insert('returns', {
        'return_date': todayStr,
        'total_return_value': 50.0,
      });

      final startEpoch = DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
      final endEpoch = DateTime(today.year, today.month, today.day, 23, 59, 59).millisecondsSinceEpoch;

      final pl = await reportRepo.getPLSummary(startEpoch, endEpoch);

      expect(pl.totalSales, 1000.0); // 400 + 600
      expect(pl.salesByMode['cash'], 400.0);
      expect(pl.salesByMode['split'], 600.0);
      expect(pl.totalExpenses, 250.0);
      expect(pl.returns, 50.0);
      expect(pl.netProfit, 700.0); // 1000 - 250 - 50
    });

    test('getDailyReport calculates all sales, categories, bills list, and returns', () async {
      final today = DateTime.now();
      final todayStr = today.toIso8601String().substring(0, 10);

      // Insert Bill with null payment mode (should categorize gracefully as cash)
      await db.insert('bills', {
        'bill_number': 'B-301',
        'customer_name_snapshot': 'હર્ષ પોશિયા',
        'bill_date': todayStr,
        'subtotal': 350.0,
        'discount': 0.0,
        'gst_amount': 0.0,
        'total_amount': 350.0,
        'paid_amount': 350.0,
        'payment_mode': null,
        'created_at': '${todayStr}T13:00:00.000',
      });

      // Insert Expense
      await db.insert('expenses', {
        'amount': 50.0,
        'expense_date': todayStr,
        'created_at': '${todayStr}T10:00:00.000',
      });

      // Insert Return
      await db.insert('returns', {
        'return_date': todayStr,
        'total_return_value': 20.0,
      });

      final daily = await reportRepo.getDailyReport(today);

      expect(daily.billCount, 1);
      expect(daily.totalSales, 350.0);
      expect(daily.totalExpenses, 50.0);
      expect(daily.totalReturns, 20.0);
      expect(daily.netPL, 280.0); // 350 - 50 - 20
      expect(daily.bills.length, 1);
      expect(daily.bills.first.billNumber, 'B-301');
    });

    test('getOutstandingKhata sorts descending by balance and handles empty names', () async {
      await db.insert('customers', {
        'name_gujarati': '',
        'name_english': 'Ramesh Patel',
        'total_outstanding': 1500.0,
        'is_active': 1,
        'created_at': '2026-10-01T00:00:00.000',
      });

      await db.insert('customers', {
        'name_gujarati': 'હર્ષભાઈ',
        'name_english': 'Harsh',
        'total_outstanding': 3000.0,
        'is_active': 1,
        'created_at': '2026-10-01T00:00:00.000',
      });

      await db.insert('customers', {
        'name_gujarati': 'સુરેશભાઈ',
        'total_outstanding': 0.0, // Zero balance should not appear
        'is_active': 1,
        'created_at': '2026-10-01T00:00:00.000',
      });

      final out = await reportRepo.getOutstandingKhata();

      expect(out.length, 2);
      expect(out.first.name, 'હર્ષભાઈ');
      expect(out.first.balance, 3000.0);
      expect(out[1].name, 'Ramesh Patel'); // fallback to English when Gujarati empty
      expect(out[1].balance, 1500.0);
    });

    test('getDailyPL builds chronological timeline without missing days', () async {
      final now = DateTime.now();
      final day1 = now.subtract(const Duration(days: 2));
      final day1Str = day1.toIso8601String().substring(0, 10);
      final day3 = now;
      final day3Str = day3.toIso8601String().substring(0, 10);

      // Bill on day 1
      await db.insert('bills', {
        'bill_number': 'B-401',
        'bill_date': day1Str,
        'subtotal': 500.0,
        'discount': 0.0,
        'gst_amount': 0.0,
        'total_amount': 500.0,
        'paid_amount': 500.0,
        'payment_mode': 'cash',
        'created_at': '${day1Str}T10:00:00.000',
      });

      // Expense on day 2 (day with 0 bills)
      final day2 = now.subtract(const Duration(days: 1));
      final day2Str = day2.toIso8601String().substring(0, 10);
      await db.insert('expenses', {
        'amount': 150.0,
        'expense_date': day2Str,
        'created_at': '${day2Str}T10:00:00.000',
      });

      // Bill on day 3
      await db.insert('bills', {
        'bill_number': 'B-403',
        'bill_date': day3Str,
        'subtotal': 200.0,
        'discount': 0.0,
        'gst_amount': 0.0,
        'total_amount': 200.0,
        'paid_amount': 200.0,
        'payment_mode': 'upi',
        'created_at': '${day3Str}T10:00:00.000',
      });

      final startEpoch = DateTime(day1.year, day1.month, day1.day).millisecondsSinceEpoch;
      final endEpoch = DateTime(day3.year, day3.month, day3.day, 23, 59, 59).millisecondsSinceEpoch;

      final dailyList = await reportRepo.getDailyPL(startEpoch, endEpoch);

      expect(dailyList.length, 3);
      // Day 1: +500
      expect(dailyList[0].netProfit, 500.0);
      // Day 2: -150 (expense day without bills is not dropped!)
      expect(dailyList[1].netProfit, -150.0);
      // Day 3: +200
      expect(dailyList[2].netProfit, 200.0);
    });
  });
}
