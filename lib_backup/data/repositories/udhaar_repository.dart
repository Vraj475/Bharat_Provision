import '../../core/database/database_helper.dart';
import '../../shared/models/bill_item_model.dart';
import '../../shared/models/bill_model.dart';
import '../../shared/models/customer_model.dart';
import '../../shared/models/udhaar_ledger_model.dart';

// ─── Data Transfer Objects ────────────────────────────────────────────────────

class CustomerSummaryRow {
  final Customer customer;
  final int daysSinceOldestUnpaid;
  const CustomerSummaryRow({
    required this.customer,
    required this.daysSinceOldestUnpaid,
  });
}

class LedgerRow {
  final UdhaarLedgerEntry entry;
  final String? billNumber;
  const LedgerRow({required this.entry, this.billNumber});
}

class UnpaidBillRow {
  final Bill bill;
  final double remaining;
  const UnpaidBillRow({required this.bill, required this.remaining});
}

class MonthGroup {
  final String monthKey; // YYYY-MM
  final String monthLabel; // Gujarati display
  final double creditTotal;
  final double paymentTotal;
  final double netAmount;
  final List<LedgerRow> rows;
  const MonthGroup({
    required this.monthKey,
    required this.monthLabel,
    required this.creditTotal,
    required this.paymentTotal,
    required this.netAmount,
    required this.rows,
  });
}

class FinalTotalData {
  final Customer customer;
  final List<MonthGroup> months;
  final double grandTotal;
  const FinalTotalData({
    required this.customer,
    required this.months,
    required this.grandTotal,
  });
}

// ─── Repository ───────────────────────────────────────────────────────────────

class UdhaarRepository {
  UdhaarRepository(this._helper);
  final DatabaseHelper _helper;

  // ── Dashboard ────────────────────────────────────────────────────────────

  Future<double> getTotalOutstanding() async {
    final rows = await _helper.rawQuery(
      'SELECT COALESCE(SUM(total_outstanding), 0) AS total '
      'FROM customers WHERE is_active = 1',
    );
    return (rows.firstOrNull?['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<CustomerSummaryRow>> getAllCustomersSorted() async {
    final rows = await _helper.rawQuery('''
      SELECT c.*,
        COALESCE(
          CAST(julianday('now') - julianday(
            (SELECT MIN(b.bill_date) FROM bills b
             WHERE b.customer_id = c.id
               AND b.payment_status IN ('udhaar', 'partial'))
          ) AS INTEGER), 0
        ) AS days_since_oldest
      FROM customers c
      WHERE c.is_active = 1
      ORDER BY c.total_outstanding DESC, c.name_gujarati ASC
    ''');
    return rows.map((r) {
      final customer = Customer.fromMap(r);
      final days = (r['days_since_oldest'] as num?)?.toInt() ?? 0;
      return CustomerSummaryRow(
        customer: customer,
        daysSinceOldestUnpaid: days,
      );
    }).toList();
  }

  // ── Customer CRUD ─────────────────────────────────────────────────────────

  Future<Customer?> getCustomerById(int id) async {
    final rows = await _helper.rawQuery(
      'SELECT * FROM customers WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    return Customer.fromMap(rows.first);
  }

  Future<int> addCustomer({
    required String nameGujarati,
    String? phone,
    String? address,
    String accountType = 'regular',
  }) async {
    final now = DateTime.now().toIso8601String();
    return _helper.insert('customers', {
      'name_gujarati': nameGujarati,
      'phone': phone,
      'address': address,
      'account_type': accountType,
      'credit_limit': 2000.0,
      'total_outstanding': 0.0,
      'is_active': 1,
      'created_at': now,
    });
  }

  Future<void> convertToRegular(
    int customerId,
    String phone,
    String? address,
  ) async {
    final values = <String, Object?>{'account_type': 'regular', 'phone': phone};
    if (address != null && address.trim().isNotEmpty) {
      values['address'] = address;
    }
    await _helper.update(
      'customers',
      values,
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }

  Future<List<Customer>> findSimilarCustomers(String name) async {
    if (name.trim().isEmpty) return [];
    final q = '%${name.trim()}%';
    final rows = await _helper.rawQuery(
      'SELECT * FROM customers '
      'WHERE name_gujarati LIKE ? OR name_english LIKE ? LIMIT 10',
      [q, q],
    );
    return rows.map((r) => Customer.fromMap(r)).toList();
  }

  Future<void> mergeDuplicate({
    required int fromCustomerId,
    required int toCustomerId,
  }) async {
    await _helper.runInTransaction((txn) async {
      await txn.rawUpdate(
        'UPDATE udhaar_ledger SET customer_id = ? WHERE customer_id = ?',
        [toCustomerId, fromCustomerId],
      );
      await txn.rawUpdate(
        'UPDATE bills SET customer_id = ? WHERE customer_id = ?',
        [toCustomerId, fromCustomerId],
      );
      final balRows =
          await txn.rawQuery(
                'SELECT running_balance FROM udhaar_ledger '
                'WHERE customer_id = ? ORDER BY created_at DESC, id DESC LIMIT 1',
                [toCustomerId],
              )
              as List;
      final newBalance = balRows.isNotEmpty
          ? (balRows.first['running_balance'] as num?)?.toDouble() ?? 0.0
          : 0.0;
      await txn.rawUpdate(
        'UPDATE customers SET total_outstanding = ? WHERE id = ?',
        [newBalance, toCustomerId],
      );
      await txn.rawDelete('DELETE FROM customers WHERE id = ?', [
        fromCustomerId,
      ]);
    });
  }

  // ── Ledger ────────────────────────────────────────────────────────────────

  Future<List<LedgerRow>> getLedgerEntries(
    int customerId, {
    String? monthYear,
  }) async {
    final args = <dynamic>[customerId];
    var monthFilter = '';
    if (monthYear != null && monthYear.isNotEmpty) {
      monthFilter = "AND strftime('%Y-%m', ul.created_at) = ?";
      args.add(monthYear);
    }
    final rows = await _helper.rawQuery('''
      SELECT ul.*, b.bill_number
      FROM udhaar_ledger ul
      LEFT JOIN bills b ON ul.bill_id = b.id
      WHERE ul.customer_id = ? $monthFilter
      ORDER BY ul.created_at DESC, ul.id DESC
    ''', args);
    return rows
        .map(
          (r) => LedgerRow(
            entry: UdhaarLedgerEntry.fromMap(r),
            billNumber: r['bill_number'] as String?,
          ),
        )
        .toList();
  }

  Future<List<String>> getAvailableMonths(int customerId) async {
    final rows = await _helper.rawQuery(
      '''
      SELECT DISTINCT strftime('%Y-%m', created_at) AS month
      FROM udhaar_ledger
      WHERE customer_id = ?
      ORDER BY month DESC
    ''',
      [customerId],
    );
    return rows.map((r) => r['month'] as String).toList();
  }

  Future<List<BillItem>> getBillItems(int billId) async {
    final rows = await _helper.rawQuery(
      'SELECT * FROM bill_items WHERE bill_id = ?',
      [billId],
    );
    return rows.map((r) => BillItem.fromMap(r)).toList();
  }

  // ── Payments ──────────────────────────────────────────────────────────────

  Future<List<UnpaidBillRow>> getUnpaidBills(int customerId) async {
    final rows = await _helper.rawQuery(
      '''
      SELECT * FROM bills
      WHERE customer_id = ? AND payment_status IN ('udhaar', 'partial')
      ORDER BY bill_date ASC, id ASC
    ''',
      [customerId],
    );
    return rows.map((r) {
      final bill = Bill.fromMap(r);
      final remaining = (bill.totalAmount - bill.paidAmount).clamp(
        0.0,
        bill.totalAmount,
      );
      return UnpaidBillRow(bill: bill, remaining: remaining);
    }).toList();
  }

  /// General FIFO payment — allocates against oldest unpaid bills first.
  Future<void> collectGeneralPayment({
    required int customerId,
    required double amount,
    required String paymentMode,
    String? note,
  }) async {
    await _helper.runInTransaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final today = now.substring(0, 10);

      // FIFO: get oldest unpaid/partial bills
      final billRows =
          await txn.rawQuery(
                '''
        SELECT * FROM bills
        WHERE customer_id = ? AND payment_status IN ('udhaar', 'partial')
        ORDER BY bill_date ASC, id ASC
      ''',
                [customerId],
              )
              as List;

      double remaining = amount;
      for (final billRow in billRows) {
        if (remaining <= 0.01) break;
        final bill = Bill.fromMap(Map<String, dynamic>.from(billRow as Map));
        final billRemaining = (bill.totalAmount - bill.paidAmount).clamp(
          0.0,
          bill.totalAmount,
        );
        if (billRemaining <= 0.01) continue;
        final payThisBill = remaining < billRemaining
            ? remaining
            : billRemaining;
        remaining -= payThisBill;

        await txn.rawInsert(
          'INSERT INTO bill_payments '
          '(bill_id, customer_id, amount_paid, payment_mode, payment_date, note) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          [bill.id, customerId, payThisBill, paymentMode, today, note],
        );
        final newPaid = bill.paidAmount + payThisBill;
        final newUdhaar = (bill.totalAmount - newPaid).clamp(
          0.0,
          bill.totalAmount,
        );
        final newStatus = newPaid >= bill.totalAmount - 0.01
            ? 'paid'
            : 'partial';
        await txn.rawUpdate(
          'UPDATE bills SET paid_amount = ?, udhaar_amount = ?, '
          'payment_status = ? WHERE id = ?',
          [newPaid, newUdhaar, newStatus, bill.id],
        );
      }

      // Running balance
      final balRows =
          await txn.rawQuery(
                'SELECT running_balance FROM udhaar_ledger '
                'WHERE customer_id = ? ORDER BY created_at DESC, id DESC LIMIT 1',
                [customerId],
              )
              as List;
      final currentBalance = balRows.isNotEmpty
          ? (balRows.first['running_balance'] as num?)?.toDouble() ?? 0.0
          : 0.0;
      final newBalance = (currentBalance - amount).clamp(0.0, double.maxFinite);

      await txn.rawInsert(
        'INSERT INTO udhaar_ledger '
        '(customer_id, transaction_type, amount, running_balance, '
        'payment_mode, note, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          customerId,
          'payment',
          amount,
          newBalance,
          paymentMode,
          note ?? 'એકંદર ચૂકવણી',
          now,
        ],
      );
      await txn.rawUpdate(
        'UPDATE customers SET total_outstanding = MAX(0, total_outstanding - ?) '
        'WHERE id = ?',
        [amount, customerId],
      );
      await txn.rawInsert(
        'INSERT INTO khata_ledger '
        '(entry_type, account_name, customer_id, amount, payment_mode, '
        'reference_type, note, entry_date, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          'credit',
          'ઉધાર ચૂકવણી',
          customerId,
          amount,
          paymentMode,
          'udhaar_payment',
          note ?? 'એકંદર ચૂકવણી',
          today,
          now,
        ],
      );
    });
  }

  /// Bill-specific payment — allocates against a single bill.
  Future<void> collectBillSpecificPayment({
    required int billId,
    required int customerId,
    required double amount,
    required String paymentMode,
    String? note,
  }) async {
    await _helper.runInTransaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final today = now.substring(0, 10);

      final billRows =
          await txn.rawQuery('SELECT * FROM bills WHERE id = ?', [billId])
              as List;
      if (billRows.isEmpty) return;
      final bill = Bill.fromMap(
        Map<String, dynamic>.from(billRows.first as Map),
      );

      final maxAmount = (bill.totalAmount - bill.paidAmount).clamp(
        0.0,
        bill.totalAmount,
      );
      final actualAmount = amount > maxAmount ? maxAmount : amount;
      if (actualAmount <= 0.01) return;

      await txn.rawInsert(
        'INSERT INTO bill_payments '
        '(bill_id, customer_id, amount_paid, payment_mode, payment_date, note) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        [billId, customerId, actualAmount, paymentMode, today, note],
      );
      final newPaid = bill.paidAmount + actualAmount;
      final newUdhaar = (bill.totalAmount - newPaid).clamp(
        0.0,
        bill.totalAmount,
      );
      final newStatus = newPaid >= bill.totalAmount - 0.01 ? 'paid' : 'partial';
      await txn.rawUpdate(
        'UPDATE bills SET paid_amount = ?, udhaar_amount = ?, '
        'payment_status = ? WHERE id = ?',
        [newPaid, newUdhaar, newStatus, billId],
      );

      final balRows =
          await txn.rawQuery(
                'SELECT running_balance FROM udhaar_ledger '
                'WHERE customer_id = ? ORDER BY created_at DESC, id DESC LIMIT 1',
                [customerId],
              )
              as List;
      final currentBalance = balRows.isNotEmpty
          ? (balRows.first['running_balance'] as num?)?.toDouble() ?? 0.0
          : 0.0;
      final newBalance = (currentBalance - actualAmount).clamp(
        0.0,
        double.maxFinite,
      );

      await txn.rawInsert(
        'INSERT INTO udhaar_ledger '
        '(customer_id, bill_id, transaction_type, amount, running_balance, '
        'payment_mode, note, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          customerId,
          billId,
          'payment',
          actualAmount,
          newBalance,
          paymentMode,
          note,
          now,
        ],
      );
      await txn.rawUpdate(
        'UPDATE customers SET total_outstanding = MAX(0, total_outstanding - ?) '
        'WHERE id = ?',
        [actualAmount, customerId],
      );
      await txn.rawInsert(
        'INSERT INTO khata_ledger '
        '(entry_type, account_name, customer_id, amount, payment_mode, '
        'reference_type, reference_id, note, entry_date, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          'credit',
          'ઉધાર ચૂકવણી',
          customerId,
          actualAmount,
          paymentMode,
          'udhaar_payment',
          billId,
          note ?? 'બિલ #${bill.billNumber}',
          today,
          now,
        ],
      );
    });
  }

  // ── Final Total ───────────────────────────────────────────────────────────

  Future<FinalTotalData> getFinalTotal(int customerId) async {
    final customer = await getCustomerById(customerId);
    if (customer == null) throw StateError('Customer $customerId not found');

    final rows = await _helper.rawQuery(
      '''
      SELECT ul.*, b.bill_number
      FROM udhaar_ledger ul
      LEFT JOIN bills b ON ul.bill_id = b.id
      WHERE ul.customer_id = ?
      ORDER BY ul.created_at ASC, ul.id ASC
    ''',
      [customerId],
    );

    final monthMap = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final createdAt = row['created_at'] as String;
      final month = createdAt.length >= 7
          ? createdAt.substring(0, 7)
          : createdAt;
      monthMap.putIfAbsent(month, () => []).add(row);
    }

    final months = monthMap.entries.map((e) {
      double creditTotal = 0;
      double paymentTotal = 0;
      final ledgerRows = <LedgerRow>[];
      for (final r in e.value) {
        final entry = UdhaarLedgerEntry.fromMap(r);
        if (entry.transactionType == 'credit') {
          creditTotal += entry.amount;
        } else {
          paymentTotal += entry.amount;
        }
        ledgerRows.add(
          LedgerRow(entry: entry, billNumber: r['bill_number'] as String?),
        );
      }
      return MonthGroup(
        monthKey: e.key,
        monthLabel: _gujaratiMonthLabel(e.key),
        creditTotal: creditTotal,
        paymentTotal: paymentTotal,
        netAmount: creditTotal - paymentTotal,
        rows: ledgerRows,
      );
    }).toList();

    return FinalTotalData(
      customer: customer,
      months: months,
      grandTotal: customer.totalOutstanding,
    );
  }

  static const _gujaratiMonths = [
    '',
    'જાન્યુ',
    'ફેબ્રુ',
    'માર્ચ',
    'એપ્રિ',
    'મે',
    'જૂન',
    'જુલાઈ',
    'ઓગ',
    'સ્પ્ટે',
    'ઓક્ટો',
    'નવે',
    'ડિસે',
  ];

  String _gujaratiMonthLabel(String monthYear) {
    final parts = monthYear.split('-');
    if (parts.length < 2) return monthYear;
    final mn = int.tryParse(parts[1]) ?? 0;
    final name = mn >= 1 && mn <= 12 ? _gujaratiMonths[mn] : parts[1];
    return '$name ${parts[0]}';
  }

  // ── Reminders ─────────────────────────────────────────────────────────────

  Future<void> logReminder(
    int customerId,
    String reminderType,
    double balance,
  ) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await _helper.insert('reminder_log', {
      'customer_id': customerId,
      'reminder_type': reminderType,
      'sent_date': today,
      'balance_at_time': balance,
    });
  }

  Future<String> getSetting(String key, [String defaultValue = '']) async {
    final rows = await _helper.rawQuery(
      'SELECT value FROM settings WHERE key = ?',
      [key],
    );
    if (rows.isEmpty) return defaultValue;
    return (rows.first['value'] as String?) ?? defaultValue;
  }

  Future<Map<String, String>> getSettings(List<String> keys) async {
    if (keys.isEmpty) return {};
    final placeholders = List.filled(keys.length, '?').join(',');
    final rows = await _helper.rawQuery(
      'SELECT key, value FROM settings WHERE key IN ($placeholders)',
      keys,
    );
    return {
      for (final r in rows) r['key'] as String: (r['value'] as String?) ?? '',
    };
  }
}
