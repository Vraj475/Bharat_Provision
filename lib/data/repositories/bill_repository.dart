import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/bill.dart';
import '../models/bill_item.dart';
import '../models/bill_item_input.dart';

class BillRepository {
  BillRepository(this._db);

  final Database _db;

  Future<int> getNextBillNumber() async {
    return _db.transaction((txn) async {
      final current = await _nextBillNumberInTransaction(txn);
      await _setBillCounter(txn, current + 1);
      return current;
    });
  }

  Future<int> createBill({
    required int? customerId,
    String? customerNameSnapshot,
    required List<BillItemInput> items,
    required double discountAmount,
    required double paidAmount,
    required String paymentMode,
    int? userId,
  }) async {
    final now = DateTime.now();
    final nowEpoch = now.millisecondsSinceEpoch;
    final nowIso = now.toIso8601String();
    final billDate = nowIso.substring(0, 10);

    double subtotal = 0;
    for (final i in items) {
      subtotal += i.quantity * i.unitPrice;
    }
    final totalAmount = subtotal - discountAmount;
    final udhaarAmount = (totalAmount - paidAmount).clamp(0.0, totalAmount);

    return _db.transaction((txn) async {
      final billNumber = await _nextBillNumberInTransaction(txn);
      final itemTable = await _resolveItemTable(txn);
      final itemStockColumn = await _firstExistingColumn(txn, itemTable, [
        'current_stock',
        'stock_qty',
      ]);

      final hasCustomerNameSnapshot = await _columnExists(
        txn,
        'bills',
        'customer_name_snapshot',
      );
      final hasBillDate = await _columnExists(txn, 'bills', 'bill_date');
      final hasDiscount = await _columnExists(txn, 'bills', 'discount');
      final hasDiscountAmount = await _columnExists(
        txn,
        'bills',
        'discount_amount',
      );
      final hasTaxAmount = await _columnExists(txn, 'bills', 'tax_amount');
      final hasGstAmount = await _columnExists(txn, 'bills', 'gst_amount');
      final hasCreatedAt = await _columnExists(txn, 'bills', 'created_at');
      final hasPaymentStatus = await _columnExists(
        txn,
        'bills',
        'payment_status',
      );
      final hasUdhaarAmount = await _columnExists(
        txn,
        'bills',
        'udhaar_amount',
      );

      final billValues = <String, Object?>{
        'bill_number': billNumber.toString(),
        'customer_id': customerId,
        'subtotal': subtotal,
        'total_amount': totalAmount,
        'paid_amount': paidAmount,
        'payment_mode': paymentMode,
      };

      if (await _columnExists(txn, 'bills', 'date_time')) {
        billValues['date_time'] = nowEpoch;
      }
      if (hasBillDate) {
        billValues['bill_date'] = billDate;
      }
      if (hasDiscountAmount) {
        billValues['discount_amount'] = discountAmount;
      }
      if (hasDiscount) {
        billValues['discount'] = discountAmount;
      }
      if (hasTaxAmount) {
        billValues['tax_amount'] = 0.0;
      }
      if (hasGstAmount) {
        billValues['gst_amount'] = 0.0;
      }
      if (await _columnExists(txn, 'bills', 'created_by_user_id')) {
        billValues['created_by_user_id'] = userId;
      }
      if (hasCreatedAt) {
        billValues['created_at'] = nowIso;
      }
      if (hasPaymentStatus) {
        billValues['payment_status'] = udhaarAmount <= 0.0
            ? 'paid'
            : (paidAmount <= 0.0 ? 'udhaar' : 'partial');
      }
      if (hasUdhaarAmount) {
        billValues['udhaar_amount'] = udhaarAmount;
      }
      if (hasCustomerNameSnapshot) {
        billValues['customer_name_snapshot'] =
            (customerNameSnapshot != null &&
                customerNameSnapshot.trim().isNotEmpty)
            ? customerNameSnapshot.trim()
            : null;
      }

      final billId = await txn.insert('bills', billValues);

      final hasStockLog = await _tableExists(txn, 'stock_log');
      final hasStockQty = itemStockColumn != null;
      final hasBillItemProductId = await _columnExists(
        txn,
        'bill_items',
        'product_id',
      );
      final hasBillItemItemId = await _columnExists(
        txn,
        'bill_items',
        'item_id',
      );
      final hasBillItemQty = await _columnExists(txn, 'bill_items', 'qty');
      final hasBillItemQuantity = await _columnExists(
        txn,
        'bill_items',
        'quantity',
      );
      final hasBillItemAmount = await _columnExists(
        txn,
        'bill_items',
        'amount',
      );
      final hasBillItemLineTotal = await _columnExists(
        txn,
        'bill_items',
        'line_total',
      );
      final hasBillItemUnitPrice = await _columnExists(
        txn,
        'bill_items',
        'unit_price',
      );
      final hasBillItemSellPriceSnapshot = await _columnExists(
        txn,
        'bill_items',
        'sell_price_snapshot',
      );

      for (final i in items) {
        final lineTotal = i.quantity * i.unitPrice;
        final billItemValues = <String, Object?>{'bill_id': billId};
        if (hasBillItemItemId) billItemValues['item_id'] = i.itemId;
        if (hasBillItemProductId) billItemValues['product_id'] = i.itemId;
        if (hasBillItemQuantity) billItemValues['quantity'] = i.quantity;
        if (hasBillItemQty) billItemValues['qty'] = i.quantity;
        if (hasBillItemUnitPrice) billItemValues['unit_price'] = i.unitPrice;
        if (hasBillItemSellPriceSnapshot) {
          billItemValues['sell_price_snapshot'] = i.unitPrice;
        }
        if (hasBillItemLineTotal) billItemValues['line_total'] = lineTotal;
        if (hasBillItemAmount) billItemValues['amount'] = lineTotal;
        await txn.insert('bill_items', billItemValues);

        double qtyBefore = 0;
        if (hasStockQty) {
          final stockRow = await txn.query(
            itemTable,
            columns: [itemStockColumn],
            where: 'id = ?',
            whereArgs: [i.itemId],
          );
          qtyBefore =
              (stockRow.firstOrNull?[itemStockColumn] as num?)?.toDouble() ?? 0;
        }

        if (itemStockColumn != null) {
          await txn.rawUpdate(
            'UPDATE $itemTable SET $itemStockColumn = COALESCE($itemStockColumn, 0) - ? WHERE id = ?',
            [i.quantity, i.itemId],
          );
        }

        if (hasStockLog) {
          final hasProductId = await _columnExists(
            txn,
            'stock_log',
            'product_id',
          );
          final hasItemId = await _columnExists(txn, 'stock_log', 'item_id');
          final hasTransactionType = await _columnExists(
            txn,
            'stock_log',
            'transaction_type',
          );
          final hasQtyChange = await _columnExists(
            txn,
            'stock_log',
            'qty_change',
          );
          final hasQtyBefore = await _columnExists(
            txn,
            'stock_log',
            'qty_before',
          );
          final hasQtyAfter = await _columnExists(
            txn,
            'stock_log',
            'qty_after',
          );
          final hasReferenceId = await _columnExists(
            txn,
            'stock_log',
            'reference_id',
          );
          final hasReferenceType = await _columnExists(
            txn,
            'stock_log',
            'reference_type',
          );
          final hasNote = await _columnExists(txn, 'stock_log', 'note');
          final hasCreatedAtStockLog = await _columnExists(
            txn,
            'stock_log',
            'created_at',
          );

          final stockValues = <String, Object?>{};
          if (hasProductId) stockValues['product_id'] = i.itemId;
          if (hasItemId) stockValues['item_id'] = i.itemId;
          if (hasTransactionType) stockValues['transaction_type'] = 'sale';
          if (hasQtyChange) stockValues['qty_change'] = -i.quantity;
          if (hasQtyBefore) stockValues['qty_before'] = qtyBefore;
          if (hasQtyAfter) stockValues['qty_after'] = qtyBefore - i.quantity;
          if (hasReferenceId) stockValues['reference_id'] = billId;
          if (hasReferenceType) stockValues['reference_type'] = 'bill';
          if (hasNote) stockValues['note'] = 'Bill #$billNumber';
          if (hasCreatedAtStockLog) stockValues['created_at'] = nowIso;

          if (stockValues.isNotEmpty) {
            await txn.insert('stock_log', stockValues);
          }
        }
      }

      final isUdhaarOrSplit = paymentMode == 'udhaar' || paymentMode == 'split';
      if (isUdhaarOrSplit && customerId != null && udhaarAmount > 0) {
        final hasUdhaarLedger = await _tableExists(txn, 'udhaar_ledger');
        final hasKhataLedger = await _tableExists(txn, 'khata_ledger');
        final hasKhataEntries = await _tableExists(txn, 'khata_entries');
        final hasCustomerOutstanding = await _columnExists(
          txn,
          'customers',
          'total_outstanding',
        );

        double updatedOutstanding = udhaarAmount;
        if (hasCustomerOutstanding) {
          final customerRows = await txn.query(
            'customers',
            columns: ['total_outstanding'],
            where: 'id = ?',
            whereArgs: [customerId],
          );
          final currentOutstanding =
              (customerRows.firstOrNull?['total_outstanding'] as num?)
                  ?.toDouble() ??
              0.0;
          updatedOutstanding = currentOutstanding + udhaarAmount;
          await txn.update(
            'customers',
            {'total_outstanding': updatedOutstanding},
            where: 'id = ?',
            whereArgs: [customerId],
          );
        }

        if (hasUdhaarLedger) {
          await txn.insert('udhaar_ledger', {
            'customer_id': customerId,
            'bill_id': billId,
            'transaction_type': 'credit',
            'amount': udhaarAmount,
            'running_balance': updatedOutstanding,
            'payment_mode': paymentMode,
            'note': 'Bill #$billNumber',
            'created_at': nowIso,
          });
        }

        if (hasKhataLedger) {
          await txn.insert('khata_ledger', {
            'entry_type': 'debit',
            'account_name': 'ઉધાર બિલ',
            'customer_id': customerId,
            'amount': udhaarAmount,
            'payment_mode': paymentMode,
            'reference_type': 'bill',
            'reference_id': billId,
            'note': 'Bill #$billNumber',
            'entry_date': billDate,
            'created_at': nowIso,
          });
        } else if (hasKhataEntries) {
          final lastBalanceRows = await txn.rawQuery(
            'SELECT balance_after FROM khata_entries WHERE customer_id = ? '
            'ORDER BY date_time DESC, id DESC LIMIT 1',
            [customerId],
          );
          final currentBalance =
              (lastBalanceRows.firstOrNull?['balance_after'] as num?)
                  ?.toDouble() ??
              0.0;
          final balanceAfter = currentBalance + udhaarAmount;

          await txn.insert('khata_entries', {
            'customer_id': customerId,
            'related_bill_id': billId,
            'date_time': nowEpoch,
            'type': 'udhaar',
            'amount': udhaarAmount,
            'note': 'Bill #$billNumber',
            'balance_after': balanceAfter,
          });
        }
      }

      await _setBillCounter(txn, billNumber + 1);

      return billId;
    });
  }

  Future<bool> _tableExists(Transaction txn, String tableName) async {
    final rows = await txn.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [tableName],
    );
    return rows.isNotEmpty;
  }

  Future<bool> _columnExists(
    Transaction txn,
    String tableName,
    String columnName,
  ) async {
    final rows = await txn.rawQuery('PRAGMA table_info($tableName)');
    return rows.any((row) => row['name'] == columnName);
  }

  Future<int> _nextBillNumberInTransaction(Transaction txn) async {
    final counterRows = await txn.rawQuery(
      "SELECT value FROM settings WHERE key = 'bill_counter' LIMIT 1",
    );
    final counterValue = counterRows.isNotEmpty
        ? int.tryParse(counterRows.first['value']?.toString() ?? '') ?? 1
        : 1;

    final maxBillRows = await txn.rawQuery(
      'SELECT COALESCE(MAX(CAST(bill_number AS INTEGER)), 0) AS max_bill FROM bills',
    );
    final maxBill = (maxBillRows.first['max_bill'] as num?)?.toInt() ?? 0;

    return counterValue > maxBill ? counterValue : (maxBill + 1);
  }

  Future<void> _setBillCounter(Transaction txn, int nextValue) async {
    final updated = await txn.update('settings', {
      'value': nextValue.toString(),
    }, where: "key = 'bill_counter'");
    if (updated == 0) {
      await txn.insert('settings', {
        'key': 'bill_counter',
        'value': nextValue.toString(),
      });
    }
  }

  Future<String> _resolveItemTable(Transaction txn) async {
    if (await _tableExists(txn, 'items')) return 'items';
    return 'products';
  }

  Future<String?> _firstExistingColumn(
    Transaction txn,
    String table,
    List<String> candidates,
  ) async {
    for (final name in candidates) {
      if (await _columnExists(txn, table, name)) return name;
    }
    return null;
  }

  int _resolveBillEpoch(Map<String, dynamic> map) {
    final rawDateTime = map['date_time'];
    if (rawDateTime is int) return rawDateTime;
    if (rawDateTime is num) return rawDateTime.toInt();

    final dateStr =
        (map['bill_date'] ??
                map['created_at'] ??
                DateTime.now().toIso8601String())
            .toString();
    final parsed = DateTime.tryParse(dateStr);
    return (parsed ?? DateTime.now()).millisecondsSinceEpoch;
  }

  Future<Bill?> getById(int id) async {
    final maps = await _db.query('bills', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    final normalized = Map<String, dynamic>.from(maps.first);
    normalized['date_time'] ??= _resolveBillEpoch(normalized);
    normalized['discount_amount'] ??= normalized['discount'];
    normalized['tax_amount'] ??= normalized['gst_amount'];
    return Bill.fromMap(normalized);
  }

  Future<List<BillItem>> getBillItems(int billId) async {
    final maps = await _db.query(
      'bill_items',
      where: 'bill_id = ?',
      whereArgs: [billId],
    );
    return maps.map((m) {
      final normalized = Map<String, dynamic>.from(m);
      normalized['item_id'] ??= normalized['product_id'];
      normalized['quantity'] ??= normalized['qty'];
      normalized['unit_price'] ??= normalized['sell_price_snapshot'];
      normalized['line_total'] ??= normalized['amount'];
      return BillItem.fromMap(normalized);
    }).toList();
  }

  Future<double> getSalesTotal(int startEpoch, int endEpoch) async {
    final result = await _db.rawQuery(
      '''
      SELECT COALESCE(SUM(total_amount), 0) as total
      FROM bills
      WHERE date_time >= ? AND date_time <= ?
      ''',
      [startEpoch, endEpoch],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<int> getBillCount(int startEpoch, int endEpoch) async {
    final result = await _db.rawQuery(
      '''
      SELECT COUNT(*) as cnt FROM bills
      WHERE date_time >= ? AND date_time <= ?
      ''',
      [startEpoch, endEpoch],
    );
    return result.first['cnt'] as int? ?? 0;
  }
}
