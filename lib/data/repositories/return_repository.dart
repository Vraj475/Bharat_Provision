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
  final String? productName;
  final double qtyReturned;
  final double sellPriceSnapshot;

  ReturnLine({
    required this.billItemId,
    required this.productId,
    this.productName,
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
    String? paymentStatus,
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
      conditions.add(
        '(bill_number LIKE ? OR customer_name_snapshot LIKE ? OR CAST(total_amount AS TEXT) LIKE ?)',
      );
      args.addAll([like, like, like]);
    }

    if (paymentStatus != null && paymentStatus.isNotEmpty) {
      conditions.add('payment_status = ?');
      args.add(paymentStatus);
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

    // Build product summary string for clear identification
    final itemSummaries = <String>[];
    for (final l in lines) {
      final pName = l.productName ?? 'ઉત્પાદન #${l.productId}';
      itemSummaries.add('$pName (${l.qtyReturned})');
    }
    final defaultNote = 'પરત: ${itemSummaries.join(', ')}';
    final computedNotes = (notes != null && notes.trim().isNotEmpty)
        ? '${notes.trim()} - $defaultNote'
        : defaultNote;

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
      'notes': computedNotes,
    });

    for (final line in lines) {
      await txn.insert('return_items', {
        'return_id': returnId,
        'product_id': line.productId,
        'qty_returned': line.qtyReturned,
        'value_at_return': line.qtyReturned * line.sellPriceSnapshot,
      });

      // Update bill item remaining quantity and amount
      final itemRows = await txn.query(
        'bill_items',
        where: 'id = ?',
        whereArgs: [line.billItemId],
      );
      if (itemRows.isNotEmpty) {
        final currentQty = (itemRows.first['qty'] as num?)?.toDouble() ?? line.qtyReturned;
        final remainingQty = (currentQty - line.qtyReturned).clamp(0.0, double.maxFinite);
        final newAmount = remainingQty * line.sellPriceSnapshot;
        await txn.update(
          'bill_items',
          {
            'qty': remainingQty,
            'amount': newAmount,
            'is_returned': remainingQty <= 0.001 ? 1 : 0,
          },
          where: 'id = ?',
          whereArgs: [line.billItemId],
        );
      }

      // stock update + log
      final prodRows = await txn.query(
        'products',
        columns: ['stock_qty', 'name_gujarati', 'unit_type'],
        where: 'id = ?',
        whereArgs: [line.productId],
      );
      if (prodRows.isEmpty) continue;
      final unitTypeStr = (prodRows.first['unit_type'] as String?)?.trim().toLowerCase() ?? '';
      final prodName = (prodRows.first['name_gujarati'] as String?) ?? line.productName ?? 'ઉત્પાદન';
      final isWeightProduct = unitTypeStr == 'weight_kg' ||
          unitTypeStr == 'weight_gram' ||
          unitTypeStr.contains('કિલો') ||
          unitTypeStr == 'kg' ||
          unitTypeStr.contains('kilo') ||
          unitTypeStr.contains('ગ્રામ') ||
          unitTypeStr == 'g' ||
          unitTypeStr.contains('gram');

      final returnQtySanitized = isWeightProduct ? line.qtyReturned : line.qtyReturned.roundToDouble();
      final qtyBefore = (prodRows.first['stock_qty'] as num?)?.toDouble() ?? 0;
      final qtyAfter = qtyBefore + returnQtySanitized;
      await txn.update(
        'products',
        {'stock_qty': qtyAfter, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [line.productId],
      );
      await txn.insert('stock_log', {
        'product_id': line.productId,
        'transaction_type': 'return',
        'qty_change': returnQtySanitized,
        'qty_before': qtyBefore,
        'qty_after': qtyAfter,
        'reference_id': returnId,
        'reference_type': 'return',
        'note': 'Return for bill #$billId: $prodName ($returnQtySanitized)',
        'created_at': now,
      });
    }

    // Update bill total amount and status
    final remaining = await txn.rawQuery(
      'SELECT COUNT(*) as cnt, COALESCE(SUM(amount), 0) as total FROM bill_items WHERE bill_id = ? AND is_returned = 0',
      [billId],
    );
    final remainingCount = (remaining.first['cnt'] as int?) ?? 0;
    final remainingTotal = (remaining.first['total'] as num?)?.toDouble() ?? 0.0;
    final status = remainingCount == 0 ? 'fully_returned' : 'partial_return';
    await txn.update(
      'bills',
      {'total_amount': remainingTotal, 'payment_status': status, 'is_returned': 1},
      where: 'id = ?',
      whereArgs: [billId],
    );

    // P&L impact: record as expense on return date
    await txn.insert('expenses', {
      'expense_account_id': null,
      'account_name_snapshot': 'Return adjustment',
      'amount': totalReturnValue,
      'description': 'Return for bill #$billId: $computedNotes',
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
        'note': 'Cash refund for return: $computedNotes',
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
        'note': 'Return credit: $computedNotes',
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
        columns: ['stock_qty', 'name_gujarati', 'unit_type'],
        where: 'id = ?',
        whereArgs: [replacement.replacementProductId],
      );
      if (replacementProdRows.isEmpty) {
        throw StateError('Replacement product not found');
      }
      final replaceUnitTypeStr = (replacementProdRows.first['unit_type'] as String?)?.trim().toLowerCase() ?? '';
      final isReplaceWeightProduct = replaceUnitTypeStr == 'weight_kg' ||
          replaceUnitTypeStr == 'weight_gram' ||
          replaceUnitTypeStr.contains('કિલો') ||
          replaceUnitTypeStr == 'kg' ||
          replaceUnitTypeStr.contains('kilo') ||
          replaceUnitTypeStr.contains('ગ્રામ') ||
          replaceUnitTypeStr == 'g' ||
          replaceUnitTypeStr.contains('gram');

      final replaceQtyGivenSanitized = isReplaceWeightProduct
          ? replacement.replacementQtyGiven
          : replacement.replacementQtyGiven.roundToDouble();

      final replaceQtyBefore =
          (replacementProdRows.first['stock_qty'] as num?)?.toDouble() ?? 0;
      final replaceQtyAfter =
          replaceQtyBefore - replaceQtyGivenSanitized;
      await txn.update(
        'products',
        {'stock_qty': replaceQtyAfter, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [replacement.replacementProductId],
      );
      await txn.insert('stock_log', {
        'product_id': replacement.replacementProductId,
        'transaction_type': 'replace_out',
        'qty_change': -replaceQtyGivenSanitized,
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

  /// Update bill_date for an existing bill (for editing bill dates)
  Future<void> updateBillDate(int billId, String newBillDate) async {
    final db = await _helper.database;
    await db.update(
      'bills',
      {'bill_date': newBillDate},
      where: 'id = ?',
      whereArgs: [billId],
    );
  }

  /// Process full bill replace: updates bill items, calculates inventory delta for each product,
  /// logs stock changes, updates bill total, and handles price difference in Cash / Udhaar.
  Future<void> replaceBill({
    required int billId,
    required int? customerId,
    required List<BillItem> newItems,
    required String paymentMode,
  }) async {
    final now = DateTime.now().toIso8601String();
    final today = now.substring(0, 10);

    await _helper.runInTransaction((txn) async {
      final billRows = await txn.query('bills', where: 'id = ?', whereArgs: [billId]);
      if (billRows.isEmpty) throw StateError('Bill not found');
      final originalTotal = (billRows.first['total_amount'] as num?)?.toDouble() ?? 0.0;

      final originalItems = await txn.query('bill_items', where: 'bill_id = ?', whereArgs: [billId]);
      final oldProductQtyMap = <int, double>{};
      for (final r in originalItems) {
        final pid = r['product_id'] as int;
        final q = (r['qty'] as num?)?.toDouble() ?? 0.0;
        oldProductQtyMap[pid] = (oldProductQtyMap[pid] ?? 0.0) + q;
      }

      final newProductQtyMap = <int, double>{};
      double newTotal = 0.0;
      for (final item in newItems) {
        final pid = item.productId;
        final q = item.qty;
        newProductQtyMap[pid] = (newProductQtyMap[pid] ?? 0.0) + q;
        newTotal += item.amount;
      }

      final allProductIds = {...oldProductQtyMap.keys, ...newProductQtyMap.keys};

      for (final pid in allProductIds) {
        final oldQty = oldProductQtyMap[pid] ?? 0.0;
        final newQty = newProductQtyMap[pid] ?? 0.0;
        final delta = newQty - oldQty;

        if (delta.abs() < 0.0001) continue;

        final prodRows = await txn.query(
          'products',
          columns: ['stock_qty', 'unit_type', 'name_gujarati'],
          where: 'id = ?',
          whereArgs: [pid],
        );
        if (prodRows.isEmpty) continue;

        final qtyBefore = (prodRows.first['stock_qty'] as num?)?.toDouble() ?? 0.0;
        final stockChange = -delta;
        final qtyAfter = qtyBefore + stockChange;

        await txn.update(
          'products',
          {'stock_qty': qtyAfter, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [pid],
        );

        await txn.insert('stock_log', {
          'product_id': pid,
          'transaction_type': stockChange > 0 ? 'replace_return' : 'replace_out',
          'qty_change': stockChange,
          'qty_before': qtyBefore,
          'qty_after': qtyAfter,
          'reference_id': billId,
          'reference_type': 'replace',
          'note': 'Bill replace update for bill #$billId',
          'created_at': now,
        });
      }

      await txn.delete('bill_items', where: 'bill_id = ?', whereArgs: [billId]);
      for (final item in newItems) {
        await txn.insert('bill_items', {
          'bill_id': billId,
          'product_id': item.productId,
          'product_name_snapshot': item.productNameSnapshot,
          'unit_type_snapshot': item.unitTypeSnapshot,
          'sell_price_snapshot': item.sellPriceSnapshot,
          'qty': item.qty,
          'amount': item.amount,
          'is_returned': 0,
        });
      }

      await txn.update(
        'bills',
        {'total_amount': newTotal, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [billId],
      );

      final priceDiff = newTotal - originalTotal;
      if (priceDiff.abs() > 0.01) {
        if (priceDiff > 0) {
          if (paymentMode == 'cash_refund' || paymentMode == 'cash') {
            await txn.insert('khata_ledger', {
              'entry_type': 'credit',
              'account_name': 'Replacement extra',
              'customer_id': customerId,
              'amount': priceDiff,
              'payment_mode': 'cash',
              'reference_type': 'replace',
              'reference_id': billId,
              'note': 'Extra charge for bill replace #$billId',
              'entry_date': today,
              'created_at': now,
            });
          } else if (customerId != null) {
            final balRows = await txn.rawQuery(
              'SELECT running_balance FROM udhaar_ledger WHERE customer_id = ? ORDER BY created_at DESC, id DESC LIMIT 1',
              [customerId],
            );
            final currentBalance = balRows.isNotEmpty
                ? (balRows.first['running_balance'] as num?)?.toDouble() ?? 0.0
                : 0.0;
            final newBalance = currentBalance + priceDiff;
            await txn.insert('udhaar_ledger', {
              'customer_id': customerId,
              'bill_id': billId,
              'transaction_type': 'credit',
              'amount': priceDiff,
              'running_balance': newBalance,
              'payment_mode': null,
              'note': 'Bill replace extra charge',
              'created_at': now,
            });
            await txn.rawUpdate(
              'UPDATE customers SET total_outstanding = total_outstanding + ? WHERE id = ?',
              [priceDiff, customerId],
            );
          }
        } else {
          final refundAmount = -priceDiff;
          if (paymentMode == 'cash_refund' || paymentMode == 'cash') {
            await txn.insert('expenses', {
              'expense_account_id': null,
              'account_name_snapshot': 'Replacement refund',
              'amount': refundAmount,
              'description': 'Replace refund for bill #$billId',
              'expense_date': today,
              'created_by': 'replace',
              'created_at': now,
            });
            await txn.insert('khata_ledger', {
              'entry_type': 'debit',
              'account_name': 'Replacement refund',
              'customer_id': customerId,
              'amount': refundAmount,
              'payment_mode': 'cash',
              'reference_type': 'replace',
              'reference_id': billId,
              'note': 'Cash refund for bill replace #$billId',
              'entry_date': today,
              'created_at': now,
            });
          } else if (customerId != null) {
            final balRows = await txn.rawQuery(
              'SELECT running_balance FROM udhaar_ledger WHERE customer_id = ? ORDER BY created_at DESC, id DESC LIMIT 1',
              [customerId],
            );
            final currentBalance = balRows.isNotEmpty
                ? (balRows.first['running_balance'] as num?)?.toDouble() ?? 0.0
                : 0.0;
            final newBalance = (currentBalance - refundAmount).clamp(0.0, double.maxFinite);
            await txn.insert('udhaar_ledger', {
              'customer_id': customerId,
              'bill_id': billId,
              'transaction_type': 'payment',
              'amount': -refundAmount,
              'running_balance': newBalance,
              'payment_mode': null,
              'note': 'Bill replace refund credit',
              'created_at': now,
            });
            await txn.rawUpdate(
              'UPDATE customers SET total_outstanding = MAX(0, total_outstanding - ?) WHERE id = ?',
              [refundAmount, customerId],
            );
          }
        }
      }
    });
  }
}
