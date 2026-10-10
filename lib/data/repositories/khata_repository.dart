import 'package:sqflite_common/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../domain/models/khata_entry.dart';

class KhataRepository {
  KhataRepository([DatabaseHelper? dbHelper])
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  Future<double> getBalance(int customerId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      '''
      SELECT balance_after FROM khata_entries
      WHERE customer_id = ?
      ORDER BY date_time DESC, id DESC
      LIMIT 1
      ''',
      [customerId],
    );
    if (result.isNotEmpty) {
      return (result.first['balance_after'] as num?)?.toDouble() ?? 0.0;
    }

    final cRows = await db.query(
      'customers',
      columns: ['total_outstanding'],
      where: 'id = ?',
      whereArgs: [customerId],
      limit: 1,
    );
    if (cRows.isNotEmpty) {
      return (cRows.first['total_outstanding'] as num?)?.toDouble() ?? 0.0;
    }
    return 0.0;
  }

  Future<Map<int, double>> getBulkBalances() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT k1.customer_id, k1.balance_after
      FROM khata_entries k1
      INNER JOIN (
        SELECT customer_id, MAX(id) as max_id
        FROM khata_entries
        GROUP BY customer_id
      ) k2 ON k1.customer_id = k2.customer_id AND k1.id = k2.max_id
    ''');
    
    final map = <int, double>{};
    for (final row in result) {
      final cid = row['customer_id'] as int?;
      final bal = (row['balance_after'] as num?)?.toDouble() ?? 0.0;
      if (cid != null) {
        map[cid] = bal;
      }
    }

    final cRows = await db.query(
      'customers',
      columns: ['id', 'total_outstanding'],
      where: 'is_active = 1',
    );
    for (final row in cRows) {
      final cid = row['id'] as int?;
      final out = (row['total_outstanding'] as num?)?.toDouble() ?? 0.0;
      if (cid != null && !map.containsKey(cid)) {
        map[cid] = out;
      }
    }
    return map;
  }

  Future<List<KhataEntry>> getEntries(int customerId, {int? limit}) async {
    var sql = '''
      SELECT * FROM khata_entries
      WHERE customer_id = ?
      ORDER BY date_time DESC, id DESC
    ''';
    if (limit != null) sql += ' LIMIT $limit';

    final db = await _dbHelper.database;
    final maps = await db.rawQuery(sql, [customerId]);
    return maps.map((m) => KhataEntry.fromMap(m)).toList();
  }

  Future<bool> hasEntries(int customerId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT 1 FROM khata_entries WHERE customer_id = ? LIMIT 1',
      [customerId],
    );
    return result.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getCustomerBills(int customerId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT id, bill_number, total_amount, paid_amount, udhaar_amount, payment_mode, payment_status, bill_date, created_at
      FROM bills
      WHERE customer_id = ?
        AND payment_status != 'paid'
        AND (total_amount - paid_amount) > 0.01
      ORDER BY bill_date ASC, id ASC
    ''', [customerId]);
  }

  Future<void> addEntry({
    required int customerId,
    required String type,
    required double amount,
    int? relatedBillId,
    String? note,
  }) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final currentBalance = await _getBalance(txn, customerId);
      final isDebit = type == 'debit' || type == 'udhaar';
      final newBalance = isDebit
          ? currentBalance + amount
          : currentBalance - amount;

      final finalBalance = newBalance;

      await txn.insert('khata_entries', {
        'customer_id': customerId,
        'related_bill_id': relatedBillId,
        'date_time': now,
        'type': isDebit ? 'debit' : 'credit',
        'amount': amount,
        'note': note,
        'balance_after': finalBalance,
      });

      await txn.rawUpdate(
        'UPDATE customers SET total_outstanding = ? WHERE id = ?',
        [finalBalance, customerId],
      );

      final nowIso = DateTime.now().toIso8601String();
      await txn.insert('udhaar_ledger', {
        'customer_id': customerId,
        'bill_id': relatedBillId,
        'transaction_type': isDebit ? 'credit' : 'payment',
        'amount': amount,
        'running_balance': finalBalance,
        'payment_mode': 'cash',
        'note': note ?? (isDebit ? 'ઉધાર નોંધણી' : 'ચુકવણી જમા'),
        'created_at': nowIso,
      });

      // When payment is recorded, update bills so paid bills are cleared
      if (!isDebit) {
        final today = nowIso.substring(0, 10);
        if (relatedBillId != null) {
          final billRows = await txn.rawQuery(
            'SELECT total_amount, paid_amount FROM bills WHERE id = ?',
            [relatedBillId],
          );
          if (billRows.isNotEmpty) {
            final bRow = billRows.first;
            final total = (bRow['total_amount'] as num?)?.toDouble() ?? 0.0;
            final currentPaid = (bRow['paid_amount'] as num?)?.toDouble() ?? 0.0;
            final newPaid = currentPaid + amount;
            final newUdhaar = (total - newPaid).clamp(0.0, total);
            final newStatus = newPaid >= (total - 0.01) ? 'paid' : 'partial';

            await txn.rawUpdate(
              'UPDATE bills SET paid_amount = ?, udhaar_amount = ?, payment_status = ? WHERE id = ?',
              [newPaid, newUdhaar, newStatus, relatedBillId],
            );

            await txn.insert('bill_payments', {
              'bill_id': relatedBillId,
              'customer_id': customerId,
              'amount_paid': amount,
              'payment_mode': 'cash',
              'payment_date': today,
              'note': note ?? 'બિલ ચૂકવણી',
            });
          }
        } else {
          // FIFO: allocate payment across oldest unpaid bills for this customer
          final unpaidBillRows = await txn.rawQuery('''
            SELECT id, total_amount, paid_amount FROM bills
            WHERE customer_id = ? AND payment_status != 'paid' AND (total_amount - paid_amount) > 0.01
            ORDER BY bill_date ASC, id ASC
          ''', [customerId]);

          double remainingPayment = amount;
          for (final bRow in unpaidBillRows) {
            if (remainingPayment <= 0.01) break;
            final bId = bRow['id'] as int;
            final total = (bRow['total_amount'] as num?)?.toDouble() ?? 0.0;
            final currentPaid = (bRow['paid_amount'] as num?)?.toDouble() ?? 0.0;
            final billRemaining = (total - currentPaid).clamp(0.0, total);
            if (billRemaining <= 0.01) continue;

            final payThis = remainingPayment < billRemaining ? remainingPayment : billRemaining;
            remainingPayment -= payThis;
            final newPaid = currentPaid + payThis;
            final newUdhaar = (total - newPaid).clamp(0.0, total);
            final newStatus = newPaid >= (total - 0.01) ? 'paid' : 'partial';

            await txn.rawUpdate(
              'UPDATE bills SET paid_amount = ?, udhaar_amount = ?, payment_status = ? WHERE id = ?',
              [newPaid, newUdhaar, newStatus, bId],
            );

            await txn.insert('bill_payments', {
              'bill_id': bId,
              'customer_id': customerId,
              'amount_paid': payThis,
              'payment_mode': 'cash',
              'payment_date': today,
              'note': note ?? 'ચુકવણી જમા',
            });
          }
        }
      }
    });
  }

  Future<double> _getBalance(Transaction txn, int customerId) async {
    final result = await txn.rawQuery(
      '''
      SELECT balance_after FROM khata_entries
      WHERE customer_id = ?
      ORDER BY date_time DESC, id DESC
      LIMIT 1
      ''',
      [customerId],
    );
    if (result.isNotEmpty) {
      return (result.first['balance_after'] as num?)?.toDouble() ?? 0.0;
    }
    final cRows = await txn.query(
      'customers',
      columns: ['total_outstanding'],
      where: 'id = ?',
      whereArgs: [customerId],
      limit: 1,
    );
    if (cRows.isNotEmpty) {
      return (cRows.first['total_outstanding'] as num?)?.toDouble() ?? 0.0;
    }
    return 0.0;
  }

  Future<void> addUdharFromBill(
    int customerId,
    int billId,
    double amount,
  ) async {
    await addEntry(
      customerId: customerId,
      type: 'debit',
      amount: amount,
      relatedBillId: billId,
      note: 'બીલથી ઉધાર',
    );
  }
}
