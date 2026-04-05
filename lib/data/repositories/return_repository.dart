import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../shared/models/bill_item_model.dart';
import '../../shared/models/bill_model.dart';
import '../../shared/models/return_model.dart';
import '../../shared/models/product_model.dart';

/// Input model for return line items.
class ReturnLine {
  final int billItemId;
  final int productId;
  final double qtyReturned;
  final double sellPriceSnapshot;

  ReturnLine({
    required this.billItemId,
    required this.productId,
    required this.qtyReturned,
    required this.sellPriceSnapshot,
  });
}

/// Input model for replacement.
class ReplacementInput {
  final int returnedProductId;
  final double returnedQty;
  final double returnedPricePerKg;
  final int replacementProductId;
  final double replacementPricePerKg;
  final double replacementQtyCalculated;
  final double replacementQtyGiven;
  final double priceDifference;
  final String? differenceMode;

  ReplacementInput({
    required this.returnedProductId,
    required this.returnedQty,
    required this.returnedPricePerKg,
    required this.replacementProductId,
    required this.replacementPricePerKg,
    required this.replacementQtyCalculated,
    required this.replacementQtyGiven,
    required this.priceDifference,
    this.differenceMode,
  });
}

class ReturnRepository {
  ReturnRepository(this._helper);
  final DatabaseHelper _helper;

  Future<List<Bill>> getBillHistory({
    String? query,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final db = await _helper.database;
    final dateColumn = await _billDateColumn(db);
    final conditions = <String>[];
    final args = <dynamic>[];

    final trimmedQuery = query?.trim() ?? '';
    if (trimmedQuery.isNotEmpty) {
      final like = '%$trimmedQuery%';
      conditions.add('(bill_number LIKE ? OR customer_name_snapshot LIKE ?)');
      args.addAll([like, like]);
    }

    if (from != null && to != null) {
      if (dateColumn == 'date_time') {
        final fromEpoch = DateTime(
          from.year,
          from.month,
          from.day,
        ).millisecondsSinceEpoch;
        final toEpoch = DateTime(
          to.year,
          to.month,
          to.day,
          23,
          59,
          59,
          999,
        ).millisecondsSinceEpoch;
        conditions.add('date_time >= ? AND date_time <= ?');
        args.addAll([fromEpoch, toEpoch]);
      } else {
        final fromDate = DateTime(
          from.year,
          from.month,
          from.day,
        ).toIso8601String().substring(0, 10);
        final toDate = DateTime(
          to.year,
          to.month,
          to.day,
        ).toIso8601String().substring(0, 10);
        conditions.add('$dateColumn >= ? AND $dateColumn <= ?');
        args.addAll([fromDate, toDate]);
      }
    }

    final whereClause = conditions.isEmpty
        ? ''
        : 'WHERE ${conditions.join(' AND ')}';
    final limitClause = limit != null ? 'LIMIT $limit' : '';

    final rows = await db.rawQuery('''
      SELECT * FROM bills
      $whereClause
      ORDER BY $dateColumn DESC, id DESC
      $limitClause
    ''', args);

    return rows.map((r) => Bill.fromMap(r)).toList();
  }

  Future<List<Bill>> searchBills(String query) async {
    return getBillHistory(query: query, limit: 30);
  }

  Future<String> _billDateColumn(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(bills)');
    final names = columns
        .map((row) => row['name']?.toString())
        .whereType<String>()
        .toList();

    if (names.contains('date_time')) return 'date_time';
    if (names.contains('bill_date')) return 'bill_date';
    if (names.contains('created_at')) return 'created_at';
    return 'id';
  }

  Future<List<BillItem>> getBillItems(int billId) async {
    final db = await _helper.database;
    final rows = await db.query(
      'bill_items',
      where: 'bill_id = ?',
      whereArgs: [billId],
    );
    return rows.map((r) => BillItem.fromMap(r)).toList();
  }

  Future<List<Product>> getProducts({String? query}) async {
    final db = await _helper.database;
    if (query == null || query.trim().isEmpty) {
      final rows = await db.query(
        'products',
        where: 'is_active = 1',
        orderBy: 'name_gujarati',
      );
      return rows.map((r) => Product.fromMap(r)).toList();
    }
    final like = '%${query.trim()}%';
    final rows = await db.rawQuery(
      '''
      SELECT * FROM products
      WHERE is_active = 1
        AND (name_gujarati LIKE ? OR name_english LIKE ? OR barcode LIKE ?)
      ORDER BY name_gujarati
      LIMIT 50
    ''',
      [like, like, like],
    );
    return rows.map((r) => Product.fromMap(r)).toList();
  }

  Future<int> createReturn({
    required int billId,
    required int? customerId,
    required List<ReturnLine> lines,
    required String returnMode,
    String? notes,
  }) async {
    if (lines.isEmpty) {
      throw ArgumentError('At least one return line is required');
    }

    return await _helper.runInTransaction((txn) async {
      return await _createReturnInternal(
        txn: txn,
        billId: billId,
        customerId: customerId,
        lines: lines,
        returnMode: returnMode,
        notes: notes,
      );
    });
  }

  Future<int> _createReturnInternal({
    required Transaction txn,
    required int billId,
    required int? customerId,
    required List<ReturnLine> lines,
    required String returnMode,
    String? notes,
  }) async {
    final now = DateTime.now().toIso8601String();
    final today = now.substring(0, 10);

    // Calculate total return value
    double totalReturnValue = 0;
    for (final l in lines) {
      totalReturnValue += l.qtyReturned * l.sellPriceSnapshot;
    }

    final returnId = await txn.insert('returns', {
      'original_bill_id': billId,
      'customer_id': customerId,
      'return_date': now,
      'total_return_value': totalReturnValue,
      'return_mode': returnMode,
      'notes': notes,
    });

    for (final line in lines) {
      await txn.insert('return_items', {
        'return_id': returnId,
        'product_id': line.productId,
        'qty_returned': line.qtyReturned,
        'value_at_return': line.qtyReturned * line.sellPriceSnapshot,
      });

      // mark bill item as returned
      await txn.update(
        'bill_items',
        {'is_returned': 1},
        where: 'id = ?',
        whereArgs: [line.billItemId],
      );

      // stock update + log
      final prodRows = await txn.query(
        'products',
        columns: ['stock_qty', 'name_gujarati'],
        where: 'id = ?',
        whereArgs: [line.productId],
      );
      if (prodRows.isEmpty) continue;
      final qtyBefore = (prodRows.first['stock_qty'] as num?)?.toDouble() ?? 0;
      final qtyAfter = qtyBefore + line.qtyReturned;
      await txn.update(
        'products',
        {'stock_qty': qtyAfter, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [line.productId],
      );
      await txn.insert('stock_log', {
        'product_id': line.productId,
        'transaction_type': 'return',
        'qty_change': line.qtyReturned,
        'qty_before': qtyBefore,
        'qty_after': qtyAfter,
        'reference_id': returnId,
        'reference_type': 'return',
        'note': 'Return for bill $billId',
        'created_at': now,
      });
    }

    // Update bill status
    final remaining = await txn.rawQuery(
      'SELECT COUNT(*) as cnt FROM bill_items WHERE bill_id = ? AND is_returned = 0',
      [billId],
    );
    final remainingCount = (remaining.first['cnt'] as int?) ?? 0;
    final status = remainingCount == 0 ? 'fully_returned' : 'partial_return';
    await txn.update(
      'bills',
      {'payment_status': status, 'is_returned': 1},
      where: 'id = ?',
      whereArgs: [billId],
    );

    // P&L impact: record as expense on return date
    await txn.insert('expenses', {
      'expense_account_id': null,
      'account_name_snapshot': 'Return adjustment',
      'amount': totalReturnValue,
      'description': 'Return for bill #$billId',
      'expense_date': today,
      'created_by': 'return',
      'created_at': now,
    });

    // Handle refund modes
    if (returnMode == 'cash_refund') {
      await txn.insert('khata_ledger', {
        'entry_type': 'debit',
        'account_name': 'Cash refund',
        'customer_id': customerId,
        'amount': totalReturnValue,
        'payment_mode': 'cash',
        'reference_type': 'return',
        'reference_id': returnId,
        'note': 'Cash refund for return',
        'entry_date': today,
        'created_at': now,
      });
    } else if (returnMode == 'udhaar_credit') {
      final balRows = await txn.rawQuery(
        'SELECT running_balance FROM udhaar_ledger WHERE customer_id = ? ORDER BY created_at DESC, id DESC LIMIT 1',
        [customerId],
      );
      final currentBalance = balRows.isNotEmpty
          ? (balRows.first['running_balance'] as num?)?.toDouble() ?? 0.0
          : 0.0;
      final newBalance = (currentBalance - totalReturnValue).clamp(
        0.0,
        double.maxFinite,
      );
      await txn.insert('udhaar_ledger', {
        'customer_id': customerId,
        'bill_id': billId,
        'transaction_type': 'payment',
        'amount': -totalReturnValue,
        'running_balance': newBalance,
        'payment_mode': null,
        'note': 'Return credit',
        'created_at': now,
      });
      await txn.rawUpdate(
        'UPDATE customers SET total_outstanding = MAX(0, total_outstanding - ?) WHERE id = ?',
        [totalReturnValue, customerId],
      );
    }

    return returnId;
  }

  /// Process a replace operation (return + replacement) as a single transaction.
  Future<int> createReplace({
    required int billId,
    required int? customerId,
    required ReturnLine returnLine,
    required ReplacementInput replacement,
    required String returnMode,
    String? notes,
  }) async {
    final now = DateTime.now().toIso8601String();
    final today = now.substring(0, 10);

    return await _helper.runInTransaction((txn) async {
      // First, create return part (in same transaction)
      final returnId = await _createReturnInternal(
        txn: txn,
        billId: billId,
        customerId: customerId,
        lines: [returnLine],
        returnMode: returnMode,
        notes: notes,
      );

      // Then apply replacement stock movement and log
      // Decrease replacement product stock
      final replacementProdRows = await txn.query(
        'products',
        columns: ['stock_qty', 'name_gujarati'],
        where: 'id = ?',
        whereArgs: [replacement.replacementProductId],
      );
      if (replacementProdRows.isEmpty) {
        throw StateError('Replacement product not found');
      }
      final replaceQtyBefore =
          (replacementProdRows.first['stock_qty'] as num?)?.toDouble() ?? 0;
      final replaceQtyAfter =
          replaceQtyBefore - replacement.replacementQtyGiven;
      await txn.update(
        'products',
        {'stock_qty': replaceQtyAfter, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [replacement.replacementProductId],
      );
      await txn.insert('stock_log', {
        'product_id': replacement.replacementProductId,
        'transaction_type': 'replace_out',
        'qty_change': -replacement.replacementQtyGiven,
        'qty_before': replaceQtyBefore,
        'qty_after': replaceQtyAfter,
        'reference_id': returnId,
        'reference_type': 'replace',
        'note': 'Replacement for return #$returnId',
        'created_at': now,
      });

      // persist replace transaction
      await txn.insert('replace_transactions', {
        'return_id': returnId,
        'returned_product_id': returnLine.productId,
        'returned_qty': returnLine.qtyReturned,
        'returned_value': returnLine.qtyReturned * returnLine.sellPriceSnapshot,
        'replacement_product_id': replacement.replacementProductId,
        'replacement_qty_calculated': replacement.replacementQtyCalculated,
        'replacement_qty_given': replacement.replacementQtyGiven,
        'price_difference': replacement.priceDifference,
        'difference_mode': replacement.differenceMode,
        'created_at': now,
      });

      // Handle price difference
      if (replacement.priceDifference.abs() > 0.01) {
        if (replacement.priceDifference > 0) {
          // customer pays extra
          if (replacement.differenceMode == 'cash') {
            await txn.insert('khata_ledger', {
              'entry_type': 'credit',
              'account_name': 'Replacement extra',
              'customer_id': customerId,
              'amount': replacement.priceDifference,
              'payment_mode': 'cash',
              'reference_type': 'replace',
              'reference_id': returnId,
              'note': 'Customer paid extra for replacement',
              'entry_date': today,
              'created_at': now,
            });
          } else if (replacement.differenceMode == 'udhaar') {
            final balRows = await txn.rawQuery(
              'SELECT running_balance FROM udhaar_ledger WHERE customer_id = ? ORDER BY created_at DESC, id DESC LIMIT 1',
              [customerId],
            );
            final currentBalance = balRows.isNotEmpty
                ? (balRows.first['running_balance'] as num?)?.toDouble() ?? 0.0
                : 0.0;
            final newBalance = (currentBalance + replacement.priceDifference)
                .clamp(0.0, double.maxFinite);
            await txn.insert('udhaar_ledger', {
              'customer_id': customerId,
              'bill_id': billId,
              'transaction_type': 'credit',
              'amount': replacement.priceDifference,
              'running_balance': newBalance,
              'payment_mode': null,
              'note': 'Replacement extra charge',
              'created_at': now,
            });
            await txn.rawUpdate(
              'UPDATE customers SET total_outstanding = total_outstanding + ? WHERE id = ?',
              [replacement.priceDifference, customerId],
            );
          }
        } else {
          // shopkeeper refunds difference
          final refundAmount = -replacement.priceDifference;
          if (replacement.differenceMode == 'cash') {
            await txn.insert('khata_ledger', {
              'entry_type': 'debit',
              'account_name': 'Replacement refund',
              'customer_id': customerId,
              'amount': refundAmount,
              'payment_mode': 'cash',
              'reference_type': 'replace',
              'reference_id': returnId,
              'note': 'Cash refund for replacement',
              'entry_date': today,
              'created_at': now,
            });
          } else if (replacement.differenceMode == 'udhaar') {
            final balRows = await txn.rawQuery(
              'SELECT running_balance FROM udhaar_ledger WHERE customer_id = ? ORDER BY created_at DESC, id DESC LIMIT 1',
              [customerId],
            );
            final currentBalance = balRows.isNotEmpty
                ? (balRows.first['running_balance'] as num?)?.toDouble() ?? 0.0
                : 0.0;
            final newBalance = (currentBalance - refundAmount).clamp(
              0.0,
              double.maxFinite,
            );
            await txn.insert('udhaar_ledger', {
              'customer_id': customerId,
              'bill_id': billId,
              'transaction_type': 'payment',
              'amount': -refundAmount,
              'running_balance': newBalance,
              'payment_mode': null,
              'note': 'Replacement refund',
              'created_at': now,
            });
            await txn.rawUpdate(
              'UPDATE customers SET total_outstanding = MAX(0, total_outstanding - ?) WHERE id = ?',
              [refundAmount, customerId],
            );
          }
        }
      }

      return returnId;
    });
  }

  Future<List<ReturnEntry>> getReturnHistory({
    DateTime? from,
    DateTime? to,
    String? returnMode,
  }) async {
    final db = await _helper.database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (from != null) {
      conditions.add('return_date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      conditions.add('return_date <= ?');
      args.add(to.toIso8601String());
    }
    if (returnMode != null && returnMode.isNotEmpty) {
      conditions.add('return_mode = ?');
      args.add(returnMode);
    }

    var where = '';
    if (conditions.isNotEmpty) {
      where = 'WHERE ${conditions.join(' AND ')}';
    }

    final rows = await db.rawQuery('''
      SELECT r.*, b.bill_number, c.name_gujarati as customer_name
      FROM returns r
      LEFT JOIN bills b ON b.id = r.original_bill_id
      LEFT JOIN customers c ON c.id = r.customer_id
      $where
      ORDER BY r.return_date DESC
    ''', args);

    return rows.map((r) => ReturnEntry.fromMap(r)).toList();
  }
}
