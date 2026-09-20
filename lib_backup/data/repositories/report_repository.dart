import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../shared/models/product_model.dart';
import '../../shared/models/bill_model.dart';

class ReportRepository {
  ReportRepository(this._db);

  final Database _db;

  Future<SalesSummary> getSalesSummary(int startEpoch, int endEpoch) async {
    // Returns should reduce the sales total on the day of return (not original bill date).
    final startIso = DateTime.fromMillisecondsSinceEpoch(
      startEpoch,
    ).toIso8601String();
    final endIso = DateTime.fromMillisecondsSinceEpoch(
      endEpoch,
    ).toIso8601String();

    final result = await _db.rawQuery(
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
      WHERE date_time >= ? AND date_time <= ?
      ''',
      [startIso, endIso, startEpoch, endEpoch],
    );
    final row = result.first;
    return SalesSummary(
      billCount: row['bill_count'] as int? ?? 0,
      totalSales: (row['total_sales'] as num?)?.toDouble() ?? 0,
      avgBillValue: (row['avg_bill'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<List<OutstandingCustomer>> getOutstandingKhata() async {
    final customers = await _db.query('customers');
    final entries = await _db.query(
      'khata_entries',
      orderBy: 'customer_id ASC, date_time DESC, id DESC',
    );
    final latestBalance = <int, double>{};
    for (final row in entries) {
      final cid = row['customer_id'] as int;
      if (!latestBalance.containsKey(cid)) {
        latestBalance[cid] = (row['balance_after'] as num?)?.toDouble() ?? 0;
      }
    }
    final out = <OutstandingCustomer>[];
    for (final c in customers) {
      final id = c['id'] as int;
      final balance = latestBalance[id] ?? 0;
      if (balance > 0) {
        out.add(
          OutstandingCustomer(
            id: id,
            name: c['name'] as String,
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

    // Only cash, upi, card sales, exclude udhaar
    final result = await _db.rawQuery(
      '''
      SELECT COALESCE(SUM(total_amount), 0) as sales
      FROM bills
      WHERE date_time >= ? AND date_time < ? AND payment_mode IN ('cash', 'upi', 'card')
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

    final result = await _db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) as expenses
      FROM expenses
      WHERE date >= ? AND date < ?
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

    final result = await _db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) as collected
      FROM udhaar_payments
      WHERE date >= ? AND date < ?
      ''',
      [startIso, endIso],
    );
    return (result.first['collected'] as num?)?.toDouble() ?? 0;
  }

  Future<List<Product>> getLowStockProducts() async {
    final result = await _db.query(
      'products',
      where: 'current_stock < min_stock',
      orderBy: 'name ASC',
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

    final result = await _db.rawQuery(
      '''
      SELECT
        DATE(date_time) as date,
        COALESCE(SUM(total_amount), 0) as sales
      FROM bills
      WHERE date_time >= ? AND date_time < ? AND payment_mode IN ('cash', 'upi', 'card')
      GROUP BY DATE(date_time)
      ORDER BY DATE(date_time) ASC
      ''',
      [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    final salesMap = <String, double>{};
    for (final row in result) {
      salesMap[row['date'] as String] = (row['sales'] as num?)?.toDouble() ?? 0;
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
    final result = await _db.rawQuery('''
      SELECT COALESCE(SUM(balance_after), 0) as total
      FROM (
        SELECT customer_id, balance_after
        FROM khata_entries
        WHERE (customer_id, date_time, id) IN (
          SELECT customer_id, MAX(date_time), MAX(id)
          FROM khata_entries
          GROUP BY customer_id
        )
      )
      WHERE balance_after > 0
      ''');
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<double> getTodaysNetProfit() async {
    final sales = await getTodaysSales();
    final expenses = await getTodaysExpenses();
    final collected = await getTodaysUdhaarCollected();
    // Net = cash sales + collected udhaar - expenses - returns
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));
    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    final returnsResult = await _db.rawQuery(
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

    final result = await _db.rawQuery(
      '''
      SELECT COUNT(*) as count
      FROM bills
      WHERE date_time >= ? AND date_time < ?
      ''',
      [startIso, endIso],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<PLSummary> getPLSummary(int startEpoch, int endEpoch) async {
    final startIso = DateTime.fromMillisecondsSinceEpoch(
      startEpoch,
    ).toIso8601String();
    final endIso = DateTime.fromMillisecondsSinceEpoch(
      endEpoch,
    ).toIso8601String();

    // Sales by mode
    final salesResult = await _db.rawQuery(
      '''
      SELECT payment_mode, SUM(total_amount) as amount
      FROM bills
      WHERE date_time >= ? AND date_time <= ? AND payment_mode IN ('cash', 'upi', 'card')
      GROUP BY payment_mode
      ''',
      [startIso, endIso],
    );
    final salesByMode = <String, double>{};
    for (final row in salesResult) {
      salesByMode[row['payment_mode'] as String] =
          (row['amount'] as num?)?.toDouble() ?? 0;
    }

    // Udhaar collected
    final udhaarResult = await _db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) as collected
      FROM udhaar_payments
      WHERE date >= ? AND date <= ?
      ''',
      [startIso, endIso],
    );
    final udhaarCollected =
        (udhaarResult.first['collected'] as num?)?.toDouble() ?? 0;

    // Expenses by account
    final expensesResult = await _db.rawQuery(
      '''
      SELECT ea.name, SUM(e.amount) as amount
      FROM expenses e
      JOIN expense_accounts ea ON e.expense_account_id = ea.id
      WHERE e.date >= ? AND e.date <= ?
      GROUP BY ea.name
      ''',
      [startIso, endIso],
    );
    final expensesByAccount = <String, double>{};
    for (final row in expensesResult) {
      expensesByAccount[row['name'] as String] =
          (row['amount'] as num?)?.toDouble() ?? 0;
    }

    // Returns
    final returnsResult = await _db.rawQuery(
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
    final startIso = DateTime.fromMillisecondsSinceEpoch(
      startEpoch,
    ).toIso8601String();
    final endIso = DateTime.fromMillisecondsSinceEpoch(
      endEpoch,
    ).toIso8601String();

    final result = await _db.rawQuery(
      '''
      SELECT
        DATE(b.date_time) as date,
        COALESCE(SUM(CASE WHEN b.payment_mode IN ('cash', 'upi', 'card') THEN b.total_amount ELSE 0 END), 0) as sales,
        COALESCE((SELECT SUM(up.amount) FROM udhaar_payments up WHERE DATE(up.date) = DATE(b.date_time)), 0) as udhaar_collected,
        COALESCE((SELECT SUM(e.amount) FROM expenses e WHERE DATE(e.date) = DATE(b.date_time)), 0) as expenses,
        COALESCE((SELECT SUM(r.total_return_value) FROM returns r WHERE DATE(r.return_date) = DATE(b.date_time)), 0) as returns
      FROM bills b
      WHERE b.date_time >= ? AND b.date_time <= ?
      GROUP BY DATE(b.date_time)
      ORDER BY DATE(b.date_time) ASC
      ''',
      [startIso, endIso],
    );

    return result.map((row) {
      final sales = (row['sales'] as num?)?.toDouble() ?? 0;
      final udhaar = (row['udhaar_collected'] as num?)?.toDouble() ?? 0;
      final expenses = (row['expenses'] as num?)?.toDouble() ?? 0;
      final returns = (row['returns'] as num?)?.toDouble() ?? 0;
      final net = sales + udhaar - expenses - returns;
      return DailyPL(
        date: DateTime.parse(row['date'] as String),
        netProfit: net,
      );
    }).toList();
  }

  Future<DailyReportData> getDailyReport(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final startEpoch = start.millisecondsSinceEpoch;
    final endEpoch = end.millisecondsSinceEpoch;

    // Bills
    final billsResult = await _db.query(
      'bills',
      where: 'date_time >= ? AND date_time < ?',
      whereArgs: [startEpoch, endEpoch],
      orderBy: 'date_time DESC',
    );
    final bills = billsResult.map((row) => Bill.fromMap(row)).toList();

    // Bill count
    final billCount = bills.length;

    // Sales by mode
    final salesByMode = <String, double>{};
    for (final bill in bills) {
      if (bill.paymentMode != null && bill.paymentMode != 'udhaar') {
        salesByMode[bill.paymentMode!] =
            (salesByMode[bill.paymentMode!] ?? 0) + bill.totalAmount;
      }
    }

    // Udhaar given
    final udhaarGiven = bills
        .where((b) => b.paymentMode == 'udhaar')
        .fold(0.0, (sum, b) => sum + b.totalAmount);

    // Udhaar collected
    double udhaarCollected = 0;
    final hasUdhaarPayments = await _tableExists('udhaar_payments');
    if (hasUdhaarPayments) {
      final udhaarResult = await _db.rawQuery(
        '''
        SELECT COALESCE(SUM(amount), 0) as collected
        FROM udhaar_payments
        WHERE date_time >= ? AND date_time < ?
        ''',
        [startEpoch, endEpoch],
      );
      udhaarCollected =
          (udhaarResult.first['collected'] as num?)?.toDouble() ?? 0;
    }

    // Expenses by category
    final hasExpenses = await _tableExists('expenses');
    final hasExpenseAccounts = await _tableExists('expense_accounts');
    final expensesResult = (hasExpenses && hasExpenseAccounts)
        ? await _db.rawQuery(
            '''
            SELECT ea.name, SUM(e.amount) as amount
            FROM expenses e
            JOIN expense_accounts ea ON e.expense_account_id = ea.id
            WHERE e.date_time >= ? AND e.date_time < ?
            GROUP BY ea.name
            ''',
            [startEpoch, endEpoch],
          )
        : <Map<String, Object?>>[];
    final expensesByCategory = <String, double>{};
    for (final row in expensesResult) {
      expensesByCategory[row['name'] as String] =
          (row['amount'] as num?)?.toDouble() ?? 0;
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

  Future<bool> _tableExists(String tableName) async {
    final result = await _db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [tableName],
    );
    return result.isNotEmpty;
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
