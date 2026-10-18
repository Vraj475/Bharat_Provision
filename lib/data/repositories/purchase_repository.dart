import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/utils/weighted_average.dart';
import '../../shared/models/purchase_item_model.dart';
import '../../shared/models/purchase_model.dart';

/// Parameter object for creating a purchase line item
class PurchaseItemInput {
  final int productId;
  final double qty;
  final double unitCost;
  final double? customSellPrice;

  const PurchaseItemInput({
    required this.productId,
    required this.qty,
    required this.unitCost,
    this.customSellPrice,
  });
}

/// Result returned after creating a purchase
class CreatePurchaseResult {
  final int purchaseId;
  final String purchaseNo;
  final double totalAmount;
  final int itemsCount;
  final List<PriceAlertInfo> priceAlerts;

  const CreatePurchaseResult({
    required this.purchaseId,
    required this.purchaseNo,
    required this.totalAmount,
    required this.itemsCount,
    required this.priceAlerts,
  });
}

/// Information about a product whose cost increased significantly
class PriceAlertInfo {
  final int productId;
  final String productName;
  final double oldCost;
  final double newCost;
  final double oldSell;
  final double suggestedSell;
  final double percentageIncrease;

  const PriceAlertInfo({
    required this.productId,
    required this.productName,
    required this.oldCost,
    required this.newCost,
    required this.oldSell,
    required this.suggestedSell,
    required this.percentageIncrease,
  });
}

class PurchaseRepository {
  PurchaseRepository([DatabaseHelper? dbHelper])
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  Future<Database> get _db async => await _dbHelper.database;

  /// Generates the next sequential purchase number: e.g. PUR-0001
  Future<String> getNextPurchaseNumber() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT purchase_no FROM purchases ORDER BY id DESC LIMIT 1',
    );
    if (rows.isEmpty) {
      return 'PUR-0001';
    }
    final lastNo = rows.first['purchase_no'] as String? ?? '';
    final match = RegExp(r'PUR-(\d+)').firstMatch(lastNo);
    if (match != null) {
      final numVal = int.tryParse(match.group(1)!) ?? 0;
      final nextVal = numVal + 1;
      return 'PUR-${nextVal.toString().padLeft(4, '0')}';
    }

    final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM purchases');
    final count = (countResult.first['count'] as int? ?? 0) + 1;
    return 'PUR-${count.toString().padLeft(4, '0')}';
  }

  /// Creates a complete purchase record in a single database transaction.
  ///
  /// Effects:
  /// 1. Inserts into `purchases`
  /// 2. For each item:
  ///    - Calculates new weighted average cost price
  ///    - Updates `products.stock_qty`, `products.buy_price`, and optionally `sell_price`
  ///    - Inserts into `purchase_items`
  ///    - Inserts into `stock_log`
  /// 3. Inserts into `expenses` (linked to 'ખરીદી' account)
  /// 4. Inserts into `khata_ledger` (debit entry)
  Future<CreatePurchaseResult> createPurchase({
    String? purchaseNo,
    required DateTime purchaseDate,
    String? supplierName,
    String? supplierPhone,
    required String paymentMode,
    required double paidAmount,
    String? notes,
    required List<PurchaseItemInput> items,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Purchase must contain at least one item.');
    }

    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final dateStr = purchaseDate.toIso8601String().substring(0, 10);

    return db.transaction((txn) async {
      // 1. Determine purchase number
      final effectivePurchaseNo = purchaseNo ?? await _generatePurchaseNoInTxn(txn);

      // 2. Calculate total amount
      double totalAmount = 0.0;
      for (final item in items) {
        totalAmount += item.qty * item.unitCost;
      }
      totalAmount = double.parse(totalAmount.toStringAsFixed(2));

      // 3. Insert purchase record
      final purchaseId = await txn.insert('purchases', {
        'purchase_no': effectivePurchaseNo,
        'purchase_date': dateStr,
        'supplier_name': supplierName?.trim().isNotEmpty == true ? supplierName!.trim() : null,
        'supplier_phone': supplierPhone?.trim().isNotEmpty == true ? supplierPhone!.trim() : null,
        'total_amount': totalAmount,
        'paid_amount': paidAmount,
        'payment_mode': paymentMode,
        'notes': notes?.trim().isNotEmpty == true ? notes!.trim() : null,
        'created_at': now,
      });

      final priceAlerts = <PriceAlertInfo>[];

      // 4. Process each line item
      for (final item in items) {
        // Fetch current product state
        final prodRows = await txn.query(
          'products',
          columns: ['id', 'name_gujarati', 'stock_qty', 'buy_price', 'sell_price'],
          where: 'id = ?',
          whereArgs: [item.productId],
        );

        if (prodRows.isEmpty) {
          throw StateError('Product with ID ${item.productId} not found.');
        }

        final prodRow = prodRows.first;
        final productName = prodRow['name_gujarati'] as String? ?? 'વસ્તુ';
        final oldStockQty = (prodRow['stock_qty'] as num?)?.toDouble() ?? 0.0;
        final oldCostPrice = (prodRow['buy_price'] as num?)?.toDouble() ?? 0.0;
        final oldSellPrice = (prodRow['sell_price'] as num?)?.toDouble() ?? 0.0;

        // Calculate weighted average cost price
        final newCostPrice = WeightedAverageCalculator.calculateWeightedAverage(
          oldQty: oldStockQty,
          oldCost: oldCostPrice,
          newQty: item.qty,
          newCost: item.unitCost,
        );

        final newStockQty = oldStockQty + item.qty;
        final newSellPrice = item.customSellPrice ?? oldSellPrice;
        final itemTotalCost = double.parse((item.qty * item.unitCost).toStringAsFixed(2));

        // Update product stock and pricing
        await txn.update(
          'products',
          {
            'stock_qty': newStockQty,
            'buy_price': newCostPrice,
            'sell_price': newSellPrice,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [item.productId],
        );

        // Insert purchase item record
        await txn.insert('purchase_items', {
          'purchase_id': purchaseId,
          'product_id': item.productId,
          'qty': item.qty,
          'unit_cost': item.unitCost,
          'total_cost': itemTotalCost,
          'old_stock_qty': oldStockQty,
          'old_cost_price': oldCostPrice,
          'new_cost_price': newCostPrice,
          'old_sell_price': oldSellPrice,
          'new_sell_price': newSellPrice,
        });

        // Insert stock log entry
        await txn.insert('stock_log', {
          'product_id': item.productId,
          'transaction_type': 'purchase',
          'qty_change': item.qty,
          'qty_before': oldStockQty,
          'qty_after': newStockQty,
          'reference_id': purchaseId,
          'reference_type': 'purchase',
          'note': 'ખરીદી: #$effectivePurchaseNo${supplierName != null ? ' | $supplierName' : ''}',
          'created_at': now,
        });

        // Check if cost increased significantly (>= 10%)
        if (WeightedAverageCalculator.hasSignificantCostIncrease(
          oldCost: oldCostPrice,
          newCost: newCostPrice,
        )) {
          final percentageIncrease = WeightedAverageCalculator.calculateCostChangePercentage(
            oldCost: oldCostPrice,
            newCost: newCostPrice,
          );
          final suggestedSell = WeightedAverageCalculator.suggestSellingPrice(
            oldCost: oldCostPrice,
            oldSell: oldSellPrice,
            newCost: newCostPrice,
          );

          priceAlerts.add(
            PriceAlertInfo(
              productId: item.productId,
              productName: productName,
              oldCost: oldCostPrice,
              newCost: newCostPrice,
              oldSell: oldSellPrice,
              suggestedSell: suggestedSell,
              percentageIncrease: percentageIncrease,
            ),
          );
        }
      }

      // 5. Link to Expense table
      // Find 'ખરીદી' (Purchase) expense account
      final accRows = await txn.query(
        'expense_accounts',
        columns: ['id', 'account_name_gujarati'],
        where: 'account_name_gujarati LIKE ? OR account_name_english LIKE ?',
        whereArgs: ['%ખરીદી%', '%Purchase%'],
        limit: 1,
      );

      int? purchaseAccId;
      String purchaseAccName = 'ખરીદી';
      if (accRows.isNotEmpty) {
        purchaseAccId = accRows.first['id'] as int?;
        purchaseAccName = accRows.first['account_name_gujarati'] as String? ?? 'ખરીદી';
      }

      final expenseDesc = StringBuffer('ખરીદી: #$effectivePurchaseNo (${items.length} વસ્તુઓ)');
      if (supplierName != null && supplierName.isNotEmpty) {
        expenseDesc.write(' | સપ્લાયર: $supplierName');
      }

      await txn.insert('expenses', {
        'expense_account_id': purchaseAccId,
        'account_name_snapshot': purchaseAccName,
        'amount': totalAmount,
        'description': expenseDesc.toString(),
        'expense_date': dateStr,
        'created_by': 'purchase_module',
        'created_at': now,
      });

      // 6. Link to khata_ledger table (debit)
      await txn.insert('khata_ledger', {
        'entry_type': 'debit',
        'account_name': purchaseAccName,
        'customer_id': null,
        'amount': totalAmount,
        'payment_mode': paymentMode,
        'reference_type': 'purchase',
        'reference_id': purchaseId,
        'note': 'ખરીદી: #$effectivePurchaseNo${supplierName != null ? ' | $supplierName' : ''}',
        'entry_date': dateStr,
        'created_at': now,
      });

      return CreatePurchaseResult(
        purchaseId: purchaseId,
        purchaseNo: effectivePurchaseNo,
        totalAmount: totalAmount,
        itemsCount: items.length,
        priceAlerts: priceAlerts,
      );
    });
  }

  Future<String> _generatePurchaseNoInTxn(Transaction txn) async {
    final rows = await txn.rawQuery(
      'SELECT purchase_no FROM purchases ORDER BY id DESC LIMIT 1',
    );
    if (rows.isEmpty) {
      return 'PUR-0001';
    }
    final lastNo = rows.first['purchase_no'] as String? ?? '';
    final match = RegExp(r'PUR-(\d+)').firstMatch(lastNo);
    if (match != null) {
      final numVal = int.tryParse(match.group(1)!) ?? 0;
      return 'PUR-${(numVal + 1).toString().padLeft(4, '0')}';
    }
    final countResult = await txn.rawQuery('SELECT COUNT(*) as count FROM purchases');
    final count = (countResult.first['count'] as int? ?? 0) + 1;
    return 'PUR-${count.toString().padLeft(4, '0')}';
  }

  /// Updates sell price for a product (e.g. after price alert approval)
  Future<void> updateProductSellPrice(int productId, double newSellPrice) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'products',
      {
        'sell_price': newSellPrice,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  /// Fetches a paginated/filtered list of purchases
  Future<List<Purchase>> getPurchases({
    DateTime? startDate,
    DateTime? endDate,
    String? query,
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await _db;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (startDate != null) {
      whereClauses.add('purchase_date >= ?');
      whereArgs.add(startDate.toIso8601String().substring(0, 10));
    }
    if (endDate != null) {
      whereClauses.add('purchase_date <= ?');
      whereArgs.add(endDate.toIso8601String().substring(0, 10));
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim()}%';
      whereClauses.add('(purchase_no LIKE ? OR supplier_name LIKE ? OR supplier_phone LIKE ?)');
      whereArgs.addAll([q, q, q]);
    }

    final where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final rows = await db.query(
      'purchases',
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'purchase_date DESC, id DESC',
      limit: limit,
      offset: offset,
    );

    return rows.map((r) => Purchase.fromMap(r)).toList();
  }

  /// Fetches a single purchase by ID along with its line items
  Future<Purchase?> getPurchaseById(int id) async {
    final db = await _db;
    final pRows = await db.query(
      'purchases',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (pRows.isEmpty) return null;

    // Fetch items joined with products for names and units
    final itemRows = await db.rawQuery('''
      SELECT 
        pi.*,
        p.name_gujarati,
        p.name_english,
        p.unit_type as unit
      FROM purchase_items pi
      JOIN products p ON pi.product_id = p.id
      WHERE pi.purchase_id = ?
      ORDER BY pi.id ASC
    ''', [id]);

    final items = itemRows.map((r) => PurchaseItem.fromMap(r)).toList();
    return Purchase.fromMap(pRows.first, items);
  }

  /// Summary statistics for purchases in a given date range
  Future<Map<String, dynamic>> getPurchaseSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _db;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (startDate != null) {
      whereClauses.add('purchase_date >= ?');
      whereArgs.add(startDate.toIso8601String().substring(0, 10));
    }
    if (endDate != null) {
      whereClauses.add('purchase_date <= ?');
      whereArgs.add(endDate.toIso8601String().substring(0, 10));
    }

    final where = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_count,
        COALESCE(SUM(total_amount), 0) as total_amount,
        COALESCE(SUM(paid_amount), 0) as total_paid
      FROM purchases
      $where
    ''', whereArgs);

    if (result.isEmpty) {
      return {'total_count': 0, 'total_amount': 0.0, 'total_paid': 0.0};
    }

    final row = result.first;
    return {
      'total_count': row['total_count'] as int? ?? 0,
      'total_amount': (row['total_amount'] as num?)?.toDouble() ?? 0.0,
      'total_paid': (row['total_paid'] as num?)?.toDouble() ?? 0.0,
    };
  }

  /// Fetches unique suppliers previously recorded
  Future<List<Map<String, String>>> getRegisteredSuppliers() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT DISTINCT supplier_name, COALESCE(supplier_phone, '') as supplier_phone
      FROM purchases
      WHERE supplier_name IS NOT NULL AND TRIM(supplier_name) != ''
      ORDER BY supplier_name ASC
    ''');
    return rows.map((r) => {
      'name': (r['supplier_name'] as String).trim(),
      'phone': (r['supplier_phone'] as String).trim(),
    }).toList();
  }

  /// Safely deletes a purchase and reverts stock changes
  Future<void> deletePurchase(int purchaseId) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // 1. Get purchase items to revert stock
      final items = await txn.query(
        'purchase_items',
        where: 'purchase_id = ?',
        whereArgs: [purchaseId],
      );

      for (final item in items) {
        final productId = item['product_id'] as int;
        final qty = (item['qty'] as num).toDouble();
        final oldCostPrice = (item['old_cost_price'] as num).toDouble();
        final oldSellPrice = (item['old_sell_price'] as num).toDouble();

        // Fetch current stock
        final pRows = await txn.query('products', where: 'id = ?', whereArgs: [productId]);
        if (pRows.isNotEmpty) {
          final curStock = (pRows.first['stock_qty'] as num?)?.toDouble() ?? 0.0;
          final revertedStock = (curStock - qty).clamp(0.0, double.infinity);

          await txn.update(
            'products',
            {
              'stock_qty': revertedStock,
              'buy_price': oldCostPrice,
              'sell_price': oldSellPrice,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [productId],
          );
        }
      }

      // 2. Delete related stock_log
      await txn.delete(
        'stock_log',
        where: 'reference_type = ? AND reference_id = ?',
        whereArgs: ['purchase', purchaseId],
      );

      // 3. Delete related khata_ledger
      await txn.delete(
        'khata_ledger',
        where: 'reference_type = ? AND reference_id = ?',
        whereArgs: ['purchase', purchaseId],
      );

      // 4. Delete related expense
      final pRow = await txn.query('purchases', where: 'id = ?', whereArgs: [purchaseId]);
      if (pRow.isNotEmpty) {
        final pNo = pRow.first['purchase_no'] as String;
        await txn.delete(
          'expenses',
          where: "description LIKE ?",
          whereArgs: ['%#$pNo%'],
        );
      }

      // 5. Delete purchase items and purchase record
      await txn.delete('purchase_items', where: 'purchase_id = ?', whereArgs: [purchaseId]);
      await txn.delete('purchases', where: 'id = ?', whereArgs: [purchaseId]);
    });
  }
}
