import '../../core/database/database_helper.dart';
import '../../shared/models/product_model.dart';
import '../../shared/models/bill_model.dart';

class ReportRepository {
  ReportRepository([DatabaseHelper? dbHelper])
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  Future<SalesSummary> getSalesSummary(int startEpoch, int endEpoch) async {
    final startIso = DateTime.fromMillisecondsSinceEpoch(startEpoch).toIso8601String();
    final endIso = DateTime.fromMillisecondsSinceEpoch(endEpoch).toIso8601String();

    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      '''
      SELECT
        COUNT(*) as bill_count,
        COALESCE(SUM(total_amount), 0)
          - COALESCE((
              SELECT SUM(total_return_value) FROM returns
              WHERE return_date >= ? AND return_date <= ?
            ), 0) as total_sales,
        COALESCE(AVG(total_amount), 0) as avg_bill
      FROM bills
      WHERE created_at >= ? AND created_at <= ?
      ''',
      [startIso, endIso, startIso, endIso],
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
        out.add(
          OutstandingCustomer(
            id: id,
            name: (c['name_gujarati'] as String?) ??
                (c['name_english'] as String?) ??
                'Customer #$id',
            balance: balance,
          ),
        );
      }
    }
    out.sort((a, b) => b.balance.compareTo(a.balance));
    return out;
  }

  Future<double> getTodaysSales() async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));
    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(total_amount), 0) as sales
      FROM bills
      WHERE created_at >= ? AND created_at < ? AND payment_mode IN ('cash', 'upi', 'card')
      ''',
      [startIso, endIso],
    );
    return (result.first['sales'] as num?)?.toDouble() ?? 0;
  }

  Future<double> getTodaysExpenses() async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));
    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) as expenses
      FROM expenses
      WHERE expense_date >= ? AND expense_date < ?
      ''',
      [startIso, endIso],
    );
    return (result.first['expenses'] as num?)?.toDouble() ?? 0;
  }

  Future<double> getTodaysUdhaarCollected() async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));
    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) as collected
      FROM udhaar_ledger
      WHERE transaction_type = 'payment' AND created_at >= ? AND created_at < ?
      ''',
      [startIso, endIso],
    );
    return (result.first['collected'] as num?)?.toDouble() ?? 0;
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
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));

    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      '''
      SELECT
        DATE(created_at) as date,
        COALESCE(SUM(total_amount), 0) as sales
      FROM bills
      WHERE created_at >= ? AND created_at < ? AND payment_mode IN ('cash', 'upi', 'card')
      GROUP BY DATE(created_at)
      ORDER BY DATE(created_at) ASC
      ''',
      [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    final salesMap = <String, double>{};
    for (final row in result) {
      if (row['date'] != null) {
        salesMap[row['date'] as String] = (row['sales'] as num?)?.toDouble() ?? 0;
      }
    }

    final out = <DailySales>[];
    for (int i = 0; i < 7; i++) {
      final date = startDate.add(Duration(days: i));
      final dateStr = date.toIso8601String().split('T').first;
      out.add(DailySales(date: date, sales: salesMap[dateStr] ?? 0));
    }
    return out;
  }

  Future<double> getTotalUdhaarOutstanding() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(total_outstanding), 0) as total
      FROM customers
      WHERE is_active = 1 AND total_outstanding > 0
      ''');
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<double> getTodaysNetProfit() async {
    final sales = await getTodaysSales();
    final expenses = await getTodaysExpenses();
    final collected = await getTodaysUdhaarCollected();
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));
    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    final db = await _dbHelper.database;
    final returnsResult = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(total_return_value), 0) as returns
      FROM returns
      WHERE return_date >= ? AND return_date < ?
      ''',
      [startIso, endIso],
    );
    final returns = (returnsResult.first['returns'] as num?)?.toDouble() ?? 0;

    return sales + collected - expenses - returns;
  }

  Future<int> getTodaysBillCount() async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));
    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count
      FROM bills
      WHERE created_at >= ? AND created_at < ?
      ''',
      [startIso, endIso],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<PLSummary> getPLSummary(int startEpoch, int endEpoch) async {
    final startIso = DateTime.fromMillisecondsSinceEpoch(startEpoch).toIso8601String();
    final endIso = DateTime.fromMillisecondsSinceEpoch(endEpoch).toIso8601String();

    final db = await _dbHelper.database;
    final salesResult = await db.rawQuery(
      '''
      SELECT payment_mode, SUM(total_amount) as amount
      FROM bills
      WHERE created_at >= ? AND created_at <= ? AND payment_mode IN ('cash', 'upi', 'card')
      GROUP BY payment_mode
      ''',
      [startIso, endIso],
    );
    final salesByMode = <String, double>{};
    for (final row in salesResult) {
      if (row['payment_mode'] != null) {
        salesByMode[row['payment_mode'] as String] =
            (row['amount'] as num?)?.toDouble() ?? 0;
      }
    }

    final udhaarResult = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) as collected
      FROM udhaar_ledger
      WHERE transaction_type = 'payment' AND created_at >= ? AND created_at <= ?
      ''',
      [startIso, endIso],
    );
    final udhaarCollected =
        (udhaarResult.first['collected'] as num?)?.toDouble() ?? 0;

    final expensesResult = await db.rawQuery(
      '''
      SELECT COALESCE(ea.account_name_gujarati, 'Other') as name, SUM(e.amount) as amount
      FROM expenses e
      LEFT JOIN expense_accounts ea ON e.expense_account_id = ea.id
      WHERE e.expense_date >= ? AND e.expense_date <= ?
      GROUP BY COALESCE(ea.account_name_gujarati, 'Other')
      ''',
      [startIso, endIso],
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
      WHERE return_date >= ? AND return_date <= ?
      ''',
      [startIso, endIso],
    );
    final returns = (returnsResult.first['returns'] as num?)?.toDouble() ?? 0;

    final totalSales =
        salesByMode.values.fold(0.0, (a, b) => a + b) + udhaarCollected;
    final totalExpenses = expensesByAccount.values.fold(0.0, (a, b) => a + b);
    final netProfit = totalSales - totalExpenses - returns;

    return PLSummary(
      salesByMode: salesByMode,
      udhaarCollected: udhaarCollected,
      expensesByAccount: expensesByAccount,
      returns: returns,
      totalSales: totalSales,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
    );
  }

  Future<List<DailyPL>> getDailyPL(int startEpoch, int endEpoch) async {
    final startIso = DateTime.fromMillisecondsSinceEpoch(startEpoch).toIso8601String();
    final endIso = DateTime.fromMillisecondsSinceEpoch(endEpoch).toIso8601String();

    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      '''
      SELECT
        DATE(b.created_at) as date,
        COALESCE(SUM(CASE WHEN b.payment_mode IN ('cash', 'upi', 'card') THEN b.total_amount ELSE 0 END), 0) as sales,
        COALESCE((SELECT SUM(ul.amount) FROM udhaar_ledger ul WHERE ul.transaction_type = 'payment' AND DATE(ul.created_at) = DATE(b.created_at)), 0) as udhaar_collected,
        COALESCE((SELECT SUM(e.amount) FROM expenses e WHERE DATE(e.expense_date) = DATE(b.created_at)), 0) as expenses,
        COALESCE((SELECT SUM(r.total_return_value) FROM returns r WHERE DATE(r.return_date) = DATE(b.created_at)), 0) as returns
      FROM bills b
      WHERE b.created_at >= ? AND b.created_at <= ?
      GROUP BY DATE(b.created_at)
      ORDER BY DATE(b.created_at) ASC
      ''',
      [startIso, endIso],
    );

    return result.map((row) {
      final sales = (row['sales'] as num?)?.toDouble() ?? 0;
      final udhaar = (row['udhaar_collected'] as num?)?.toDouble() ?? 0;
      final expenses = (row['expenses'] as num?)?.toDouble() ?? 0;
      final returns = (row['returns'] as num?)?.toDouble() ?? 0;
      final net = sales + udhaar - expenses - returns;
      final dateStr = row['date'] as String? ?? DateTime.now().toIso8601String().split('T').first;
      return DailyPL(
        date: DateTime.parse(dateStr),
        netProfit: net,
      );
    }).toList();
  }

  Future<DailyReportData> getDailyReport(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    final db = await _dbHelper.database;

    final billsResult = await db.query(
      'bills',
      where: 'created_at >= ? AND created_at < ?',
      whereArgs: [startIso, endIso],
      orderBy: 'created_at DESC',
    );
    final bills = billsResult.map((row) => Bill.fromMap(row)).toList();

    final billCount = bills.length;

    final salesByMode = <String, double>{};
    for (final bill in bills) {
      if (bill.paymentMode != null && bill.paymentMode != 'udhaar') {
        salesByMode[bill.paymentMode!] =
            (salesByMode[bill.paymentMode!] ?? 0) + bill.totalAmount;
      }
    }

    final udhaarGiven = bills
        .where((b) => b.paymentMode == 'udhaar')
        .fold(0.0, (sum, b) => sum + b.totalAmount);

    final udhaarResult = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) as collected
      FROM udhaar_ledger
      WHERE transaction_type = 'payment' AND created_at >= ? AND created_at < ?
      ''',
      [startIso, endIso],
    );
    final udhaarCollected = (udhaarResult.first['collected'] as num?)?.toDouble() ?? 0;

    final expensesResult = await db.rawQuery(
      '''
      SELECT COALESCE(ea.account_name_gujarati, 'Other') as name, SUM(e.amount) as amount
      FROM expenses e
      LEFT JOIN expense_accounts ea ON e.expense_account_id = ea.id
      WHERE e.expense_date >= ? AND e.expense_date < ?
      GROUP BY COALESCE(ea.account_name_gujarati, 'Other')
      ''',
      [startIso, endIso],
    );
    final expensesByCategory = <String, double>{};
    for (final row in expensesResult) {
      if (row['name'] != null) {
        expensesByCategory[row['name'] as String] =
            (row['amount'] as num?)?.toDouble() ?? 0;
      }
    }

    final totalSales = salesByMode.values.fold(0.0, (a, b) => a + b);
    final totalExpenses = expensesByCategory.values.fold(0.0, (a, b) => a + b);
    final netPL = totalSales + udhaarCollected - totalExpenses;

    return DailyReportData(
      billCount: billCount,
      totalSales: totalSales,
      salesByMode: salesByMode,
      udhaarGiven: udhaarGiven,
      udhaarCollected: udhaarCollected,
      expensesByCategory: expensesByCategory,
      totalExpenses: totalExpenses,
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
    required this.udhaarCollected,
    required this.expensesByAccount,
    required this.returns,
    required this.totalSales,
    required this.totalExpenses,
    required this.netProfit,
  });
  final Map<String, double> salesByMode;
  final double udhaarCollected;
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
    required this.udhaarGiven,
    required this.udhaarCollected,
    required this.expensesByCategory,
    required this.totalExpenses,
    required this.netPL,
    required this.bills,
  });
  final int billCount;
  final double totalSales;
  final Map<String, double> salesByMode;
  final double udhaarGiven;
  final double udhaarCollected;
  final Map<String, double> expensesByCategory;
  final double totalExpenses;
  final double netPL;
  final List<Bill> bills;
}
