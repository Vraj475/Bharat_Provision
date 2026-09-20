import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/khata_entry.dart';

class KhataRepository {
  KhataRepository(this._db);

  final Database _db;

  Future<double> getBalance(int customerId) async {
    final result = await _db.rawQuery(
      '''
      SELECT balance_after FROM khata_entries
      WHERE customer_id = ?
      ORDER BY date_time DESC, id DESC
      LIMIT 1
      ''',
      [customerId],
    );
    if (result.isEmpty) return 0;
    return (result.first['balance_after'] as num?)?.toDouble() ?? 0;
  }

  Future<Map<int, double>> getBulkBalances() async {
    final result = await _db.rawQuery('''
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
    return map;
  }

  Future<List<KhataEntry>> getEntries(int customerId, {int? limit}) async {
    var sql = '''
      SELECT * FROM khata_entries
      WHERE customer_id = ?
      ORDER BY date_time DESC, id DESC
    ''';
    if (limit != null) sql += ' LIMIT $limit';

    final maps = await _db.rawQuery(sql, [customerId]);
    return maps.map((m) => KhataEntry.fromMap(m)).toList();
  }

  Future<void> addEntry({
    required int customerId,
    required String type,
    required double amount,
    int? relatedBillId,
    String? note,
  }) async {
    await _db.transaction((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final currentBalance = await _getBalance(txn, customerId);
      final newBalance = type == 'debit'
          ? currentBalance + amount
          : currentBalance - amount;

      await txn.insert('khata_entries', {
        'customer_id': customerId,
        'related_bill_id': relatedBillId,
        'date_time': now,
        'type': type,
        'amount': amount,
        'note': note,
        'balance_after': newBalance,
      });
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
    if (result.isEmpty) return 0;
    return (result.first['balance_after'] as num?)?.toDouble() ?? 0;
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
