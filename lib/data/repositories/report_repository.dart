import 'package:intl/intl.dart';

import '../../core/database/database_helper.dart';
import '../../shared/models/product_model.dart';
import '../../shared/models/bill_model.dart';

class ReportRepository {
  ReportRepository([DatabaseHelper? dbHelper])
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  Future<SalesSummary> getSalesSummary(int startEpoch, int endEpoch) async {
    final start = DateTime.fromMillisecondsSinceEpoch(startEpoch);
    final end = DateTime.fromMillisecondsSinceEpoch(endEpoch);
    final startDateStr = DateFormat('yyyy-MM-dd').format(start);
    final endDateStr = DateFormat('yyyy-MM-dd').format(end);

    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      '''
      SELECT
        COUNT(*) as bill_count,
        COALESCE(SUM(total_amount), 0)
          - COALESCE((
              SELECT SUM(total_return_value) FROM returns
              WHERE DATE(return_date) >= ? AND DATE(return_date) <= ?
            ), 0) as total_sales,
        COALESCE(AVG(total_amount), 0) as avg_bill
      FROM bills
      WHERE DATE(COALESCE(bill_date, created_at)) >= ? 
        AND DATE(COALESCE(bill_date, created_at)) <= ?
      ''',
      [startDateStr, endDateStr, startDateStr, endDateStr],
    );
    final row = result.first;
    return SalesSummary(
      billCount: row['bill_count'] as int? ?? 0,
      totalSales: (row['total_sales'] as num?)?.toDouble() ?? 0,
      avgBillValue: (row['avg_bill'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<List<OutstandingCustomer>> getOutstandingKhata() async {
    final db = await _dbHelper.database;
    final customers = await db.query('customers', where: 'is_active = 1');
    final out = <OutstandingCustomer>[];
    for (final c in customers) {
      final id = c['id'] as int;
      final balance = (c['total_outstanding'] as num?)?.toDouble() ?? 0.0;
      if (balance > 0) {
        final nameGu = (c['name_gujarati'] as String?)?.trim();
        final nameEn = (c['name_english'] as String?)?.trim();
        final name = (nameGu != null && nameGu.isNotEmpty)
            ? nameGu
            : ((nameEn != null && nameEn.isNotEmpty) ? nameEn : 'ગ્રાહક #$id');

        out.add(
          OutstandingCustomer(
            id: id,
            name: name,
            balance: balance,
          ),
        );
      }
    }
    out.sort((a, b) => b.balance.compareTo(a.balance));
    return out;
  }

  Future<double> getTodaysSales() async {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(total_amount), 0) as sales
      FROM bills
      WHERE DATE(COALESCE(bill_date, created_at)) = ?
      ''',
      [todayStr],
    );
    return (result.first['sales'] as num?)?.toDouble() ?? 0;
  }

  Future<double> getTodaysExpenses() async {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) as expenses
      FROM expenses
      WHERE DATE(expense_date) = ?
      ''',
      [todayStr],
    );
    return (result.first['expenses'] as num?)?.toDouble() ?? 0;
  }

  Future<List<Product>> getLowStockProducts() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'products',
      where: 'stock_qty <= min_stock_qty AND is_active = 1',
      orderBy: 'name_gujarati ASC',
    );
    return result.map((row) => Product.fromMap(row)).toList();
  }

  Future<List<DailySales>> get7DaySales() async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 6));
    final startDateOnly = DateTime(start.year, start.month, start.day);
    final endDateOnly = DateTime(now.year, now.month, now.day);
    final startDateStr = DateFormat('yyyy-MM-dd').format(startDateOnly);
    final endDateStr = DateFormat('yyyy-MM-dd').format(endDateOnly);

    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      '''
      SELECT
        DATE(COALESCE(bill_date, created_at)) as date,
        COALESCE(SUM(total_amount), 0) as sales
      FROM bills
      WHERE DATE(COALESCE(bill_date, created_at)) >= ? 
        AND DATE(COALESCE(bill_date, created_at)) <= ?
      GROUP BY DATE(COALESCE(bill_date, created_at))
      ORDER BY DATE(COALESCE(bill_date, created_at)) ASC
      ''',
      [startDateStr, endDateStr],
    );

    final salesMap = <String, double>{};
    for (final row in result) {
      if (row['date'] != null) {
        salesMap[row['date'] as String] = (row['sales'] as num?)?.toDouble() ?? 0;
      }
    }

    final out = <DailySales>[];
    for (int i = 0; i < 7; i++) {
      final date = startDateOnly.add(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      out.add(DailySales(date: date, sales: salesMap[dateStr] ?? 0));
    }
    return out;
  }

  Future<double> getTodaysNetProfit() async {
    final sales = await getTodaysSales();
    final expenses = await getTodaysExpenses();
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final db = await _dbHelper.database;
    final returnsResult = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(total_return_value), 0) as returns
      FROM returns
      WHERE DATE(return_date) = ?
      ''',
      [todayStr],
    );
    final returns = (returnsResult.first['returns'] as num?)?.toDouble() ?? 0;

    return sales - expenses - returns;
  }

  Future<int> getTodaysBillCount() async {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count
      FROM bills
      WHERE DATE(COALESCE(bill_date, created_at)) = ?
      ''',
      [todayStr],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<PLSummary> getPLSummary(int startEpoch, int endEpoch) async {
    final start = DateTime.fromMillisecondsSinceEpoch(startEpoch);
    final end = DateTime.fromMillisecondsSinceEpoch(endEpoch);
    final startDateStr = DateFormat('yyyy-MM-dd').format(start);
    final endDateStr = DateFormat('yyyy-MM-dd').format(end);

    final db = await _dbHelper.database;
    final salesResult = await db.rawQuery(
      '''
      SELECT 
        COALESCE(NULLIF(TRIM(payment_mode), ''), 'cash') as payment_mode, 
        SUM(total_amount) as amount
      FROM bills
      WHERE DATE(COALESCE(bill_date, created_at)) >= ? 
        AND DATE(COALESCE(bill_date, created_at)) <= ?
      GROUP BY COALESCE(NULLIF(TRIM(payment_mode), ''), 'cash')
      ''',
      [startDateStr, endDateStr],
    );
    final salesByMode = <String, double>{};
    for (final row in salesResult) {
      if (row['payment_mode'] != null) {
        salesByMode[row['payment_mode'] as String] =
            (row['amount'] as num?)?.toDouble() ?? 0;
      }
    }

    final expensesResult = await db.rawQuery(
      '''
      SELECT COALESCE(ea.account_name_gujarati, 'Other') as name, SUM(e.amount) as amount
      FROM expenses e
      LEFT JOIN expense_accounts ea ON e.expense_account_id = ea.id
      WHERE DATE(e.expense_date) >= ? AND DATE(e.expense_date) <= ?
      GROUP BY COALESCE(ea.account_name_gujarati, 'Other')
      ''',
      [startDateStr, endDateStr],
    );
    final expensesByAccount = <String, double>{};
    for (final row in expensesResult) {
      if (row['name'] != null) {
        expensesByAccount[row['name'] as String] =
            (row['amount'] as num?)?.toDouble() ?? 0;
      }
    }

    final returnsResult = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(total_return_value), 0) as returns
      FROM returns
      WHERE DATE(return_date) >= ? AND DATE(return_date) <= ?
      ''',
      [startDateStr, endDateStr],
    );
    final returns = (returnsResult.first['returns'] as num?)?.toDouble() ?? 0;

    final totalSales = salesByMode.values.fold(0.0, (a, b) => a + b);
    final totalExpenses = expensesByAccount.values.fold(0.0, (a, b) => a + b);
    final netProfit = totalSales - totalExpenses - returns;

    return PLSummary(
      salesByMode: salesByMode,
      expensesByAccount: expensesByAccount,
      returns: returns,
      totalSales: totalSales,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
    );
  }

  Future<List<DailyPL>> getDailyPL(int startEpoch, int endEpoch) async {
    final start = DateTime.fromMillisecondsSinceEpoch(startEpoch);
    final end = DateTime.fromMillisecondsSinceEpoch(endEpoch);
    final startDateOnly = DateTime(start.year, start.month, start.day);
    final endDateOnly = DateTime(end.year, end.month, end.day);
    final startDateStr = DateFormat('yyyy-MM-dd').format(startDateOnly);
    final endDateStr = DateFormat('yyyy-MM-dd').format(endDateOnly);

    final db = await _dbHelper.database;

    // 1. Fetch daily sales
    final salesResult = await db.rawQuery(
      '''
      SELECT
        DATE(COALESCE(bill_date, created_at)) as date,
        COALESCE(SUM(total_amount), 0) as sales
      FROM bills
      WHERE DATE(COALESCE(bill_date, created_at)) >= ? 
        AND DATE(COALESCE(bill_date, created_at)) <= ?
      GROUP BY DATE(COALESCE(bill_date, created_at))
      ''',
      [startDateStr, endDateStr],
    );
    final salesMap = <String, double>{};
    for (final row in salesResult) {
      final d = row['date'] as String?;
      if (d != null) {
        salesMap[d] = (row['sales'] as num?)?.toDouble() ?? 0;
      }
    }

    // 2. Fetch daily expenses
    final expensesResult = await db.rawQuery(
      '''
      SELECT
        DATE(expense_date) as date,
        COALESCE(SUM(amount), 0) as expenses
      FROM expenses
      WHERE DATE(expense_date) >= ? AND DATE(expense_date) <= ?
      GROUP BY DATE(expense_date)
      ''',
      [startDateStr, endDateStr],
    );
    final expensesMap = <String, double>{};
    for (final row in expensesResult) {
      final d = row['date'] as String?;
      if (d != null) {
        expensesMap[d] = (row['expenses'] as num?)?.toDouble() ?? 0;
      }
    }

    // 3. Fetch daily returns
    final returnsResult = await db.rawQuery(
      '''
      SELECT
        DATE(return_date) as date,
        COALESCE(SUM(total_return_value), 0) as returns
      FROM returns
      WHERE DATE(return_date) >= ? AND DATE(return_date) <= ?
      GROUP BY DATE(return_date)
      ''',
      [startDateStr, endDateStr],
    );
    final returnsMap = <String, double>{};
    for (final row in returnsResult) {
      final d = row['date'] as String?;
      if (d != null) {
        returnsMap[d] = (row['returns'] as num?)?.toDouble() ?? 0;
      }
    }

    // 4. Build continuous daily points from startDateOnly to endDateOnly
    final out = <DailyPL>[];
    final totalDays = endDateOnly.difference(startDateOnly).inDays + 1;
    final cappedDays = totalDays.clamp(1, 90);

    for (int i = 0; i < cappedDays; i++) {
      final day = startDateOnly.add(Duration(days: i));
      final dayStr = DateFormat('yyyy-MM-dd').format(day);
      final daySales = salesMap[dayStr] ?? 0.0;
      final dayExpenses = expensesMap[dayStr] ?? 0.0;
      final dayReturns = returnsMap[dayStr] ?? 0.0;
      final net = daySales - dayExpenses - dayReturns;

      out.add(DailyPL(date: day, netProfit: net));
    }

    return out;
  }

  Future<DailyReportData> getDailyReport(DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final db = await _dbHelper.database;

    final billsResult = await db.rawQuery(
      '''
      SELECT * FROM bills
      WHERE DATE(COALESCE(bill_date, created_at)) = ?
      ORDER BY id DESC
      ''',
      [dateStr],
    );
    final bills = billsResult.map((row) => Bill.fromMap(row)).toList();
    final billCount = bills.length;

    final salesByMode = <String, double>{};
    for (final bill in bills) {
      final rawMode = (bill.paymentMode ?? '').trim().toLowerCase();
      final mode = rawMode.isEmpty ? 'cash' : rawMode;
      salesByMode[mode] = (salesByMode[mode] ?? 0.0) + bill.totalAmount;
    }

    final expensesResult = await db.rawQuery(
      '''
      SELECT COALESCE(ea.account_name_gujarati, 'Other') as name, SUM(e.amount) as amount
      FROM expenses e
      LEFT JOIN expense_accounts ea ON e.expense_account_id = ea.id
      WHERE DATE(e.expense_date) = ?
      GROUP BY COALESCE(ea.account_name_gujarati, 'Other')
      ''',
      [dateStr],
    );
    final expensesByCategory = <String, double>{};
    for (final row in expensesResult) {
      if (row['name'] != null) {
        expensesByCategory[row['name'] as String] =
            (row['amount'] as num?)?.toDouble() ?? 0;
      }
    }

    final returnsResult = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(total_return_value), 0) as returns
      FROM returns
      WHERE DATE(return_date) = ?
      ''',
      [dateStr],
    );
    final totalReturns = (returnsResult.first['returns'] as num?)?.toDouble() ?? 0.0;

    final totalSales = bills.fold<double>(0.0, (sum, b) => sum + b.totalAmount);
    final totalExpenses = expensesByCategory.values.fold(0.0, (a, b) => a + b);
    final netPL = totalSales - totalExpenses - totalReturns;

    return DailyReportData(
      billCount: billCount,
      totalSales: totalSales,
      salesByMode: salesByMode,
      expensesByCategory: expensesByCategory,
      totalExpenses: totalExpenses,
      totalReturns: totalReturns,
      netPL: netPL,
      bills: bills,
    );
  }
}

class SalesSummary {
  SalesSummary({
    required this.billCount,
    required this.totalSales,
    required this.avgBillValue,
  });
  final int billCount;
  final double totalSales;
  final double avgBillValue;
}

class OutstandingCustomer {
  OutstandingCustomer({
    required this.id,
    required this.name,
    required this.balance,
  });
  final int id;
  final String name;
  final double balance;
}

class DailySales {
  DailySales({required this.date, required this.sales});
  final DateTime date;
  final double sales;
}

class PLSummary {
  PLSummary({
    required this.salesByMode,
    required this.expensesByAccount,
    required this.returns,
    required this.totalSales,
    required this.totalExpenses,
    required this.netProfit,
  });
  final Map<String, double> salesByMode;
  final Map<String, double> expensesByAccount;
  final double returns;
  final double totalSales;
  final double totalExpenses;
  final double netProfit;
}

class DailyPL {
  DailyPL({required this.date, required this.netProfit});
  final DateTime date;
  final double netProfit;
}

class DailyReportData {
  DailyReportData({
    required this.billCount,
    required this.totalSales,
    required this.salesByMode,
    required this.expensesByCategory,
    required this.totalExpenses,
    this.totalReturns = 0.0,
    required this.netPL,
    required this.bills,
  });
  final int billCount;
  final double totalSales;
  final Map<String, double> salesByMode;
  final Map<String, double> expensesByCategory;
  final double totalExpenses;
  final double totalReturns;
  final double netPL;
  final List<Bill> bills;
}
