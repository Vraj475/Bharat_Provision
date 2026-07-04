import '../../../core/database/database_helper.dart';
import '../../shared/models/product_model.dart';
import '../../shared/models/stock_log_model.dart';
import '../../shared/models/expense_account_model.dart';

/// Data class holding result of addStock transaction.
class AddStockResult {
  const AddStockResult({
    required this.updatedProduct,
    required this.stockLogId,
    required this.expenseId,
    required this.khataLedgerId,
  });
  final Product updatedProduct;
  final int stockLogId;
  final int expenseId;
  final int khataLedgerId;
}

/// Computed stock health for display.
enum StockHealth { healthy, low, critical, outOfStock }

extension StockHealthX on Product {
  StockHealth get stockHealth {
    if (stockQty <= 0) return StockHealth.outOfStock;
    if (stockQty <= minStockQty) return StockHealth.critical;
    if (minStockQty > 0 && stockQty <= minStockQty * 1.2) {
      return StockHealth.low;
    }
    return StockHealth.healthy;
  }
}

class StockRepository {
  const StockRepository(this._db);
  final DatabaseHelper _db;

  // ────────────────────────────────────────────────────────────────────────
  //  Product reads
  // ────────────────────────────────────────────────────────────────────────

  Future<List<Product>> getAllProducts({String? query}) async {
    final db = await _db.database;
    List<Map<String, dynamic>> rows;
    if (query == null || query.trim().isEmpty) {
      rows = (await db.query(
        'products',
        where: 'is_active = 1',
        orderBy: 'name_gujarati COLLATE NOCASE',
      )).cast<Map<String, dynamic>>();
    } else {
      final like = '%${query.trim()}%';
      rows = (await db.rawQuery(
        '''
        SELECT DISTINCT p.*
        FROM products p
        LEFT JOIN transliteration_dictionary t
          ON t.gujarati_text = p.name_gujarati
        WHERE p.is_active = 1
          AND (
            p.name_gujarati LIKE ? OR
            p.name_english LIKE ? OR
            p.transliteration_keys LIKE ? OR
            t.phonetic_key LIKE ?
          )
        ORDER BY p.name_gujarati COLLATE NOCASE
      ''',
        [like, like, like, like],
      )).cast<Map<String, dynamic>>();
    }
    return rows.map(Product.fromMap).toList();
  }

  Future<Product?> getProductById(int id) async {
    final db = await _db.database;
    final rows = (await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    )).cast<Map<String, dynamic>>();
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<List<Product>> getLowStockProducts() async {
    final db = await _db.database;
    final rows = (await db.rawQuery('''
      SELECT * FROM products
      WHERE is_active = 1
        AND stock_qty <= min_stock_qty
        AND stock_qty > 0
    ''')).cast<Map<String, dynamic>>();
    return rows.map(Product.fromMap).toList();
  }

  Future<List<Product>> getOutOfStockProducts() async {
    final db = await _db.database;
    final rows = (await db.rawQuery('''
      SELECT * FROM products
      WHERE is_active = 1 AND stock_qty <= 0
    ''')).cast<Map<String, dynamic>>();
    return rows.map(Product.fromMap).toList();
  }

  // ────────────────────────────────────────────────────────────────────────
  //  Categories
  // ────────────────────────────────────────────────────────────────────────

  Future<List<CategoryRow>> getCategories() async {
    final db = await _db.database;
    final rows = (await db.query(
      'categories',
      where: 'is_active = 1',
      orderBy: 'name_gujarati',
    )).cast<Map<String, dynamic>>();
    return rows
        .map(
          (m) => CategoryRow(
            id: m['id'] as int,
            nameGujarati: m['name_gujarati'] as String,
          ),
        )
        .toList();
  }

  // ────────────────────────────────────────────────────────────────────────
  //  Expense accounts
  // ────────────────────────────────────────────────────────────────────────

  Future<List<ExpenseAccount>> getExpenseAccounts() async {
    final db = await _db.database;
    final rows = (await db.query(
      'expense_accounts',
      where: 'is_active = 1',
      orderBy: 'account_name_gujarati',
    )).cast<Map<String, dynamic>>();
    return rows.map(ExpenseAccount.fromMap).toList();
  }

  // ────────────────────────────────────────────────────────────────────────
  //  Stock history
  // ────────────────────────────────────────────────────────────────────────

  Future<List<StockLogEntry>> getStockHistory(
    int productId, {
    String? transactionType,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final db = await _db.database;
    final conditions = <String>['product_id = ?'];
    final args = <dynamic>[productId];

    if (transactionType != null && transactionType.isNotEmpty) {
      conditions.add('transaction_type = ?');
      args.add(transactionType);
    }
    if (fromDate != null) {
      conditions.add("created_at >= ?");
      args.add(fromDate.toIso8601String());
    }
    if (toDate != null) {
      conditions.add("created_at <= ?");
      args.add(toDate.add(const Duration(days: 1)).toIso8601String());
    }

    final rows = (await db.query(
      'stock_log',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at DESC',
    )).cast<Map<String, dynamic>>();
    return rows.map(StockLogEntry.fromMap).toList();
  }

  // ────────────────────────────────────────────────────────────────────────
  //  AddStock — single transaction with 4 effects
  // ────────────────────────────────────────────────────────────────────────

  Future<AddStockResult> addStock({
    required int productId,
    required double qtyReceived,
    required double buyPrice,
    required int expenseAccountId,
    required String expenseAccountName,
    required String? supplierName,
    required DateTime date,
    required String? notes,
  }) async {
    final dateStr = date.toIso8601String().substring(0, 10);
    final now = DateTime.now().toIso8601String();
    final totalAmount = qtyReceived * buyPrice;

    late AddStockResult result;

    await _db.runInTransaction((txn) async {
      // 1. Fetch current stock
      final rows = (await txn.query(
        'products',
        columns: ['stock_qty', 'name_gujarati'],
        where: 'id = ?',
        whereArgs: [productId],
      )).cast<Map<String, dynamic>>();
      final qtyBefore = (rows.first['stock_qty'] as num?)?.toDouble() ?? 0;
      final productName = rows.first['name_gujarati'] as String;
      final qtyAfter = qtyBefore + qtyReceived;

      // Effect 1: update product stock + buy price
      await txn.rawUpdate(
        '''
        UPDATE products
        SET stock_qty = ?,
            buy_price = ?,
            updated_at = ?
        WHERE id = ?
      ''',
        [qtyAfter, buyPrice, now, productId],
      );

      // Effect 2: insert stock_log
      final stockLogId = await txn.insert('stock_log', {
        'product_id': productId,
        'transaction_type': 'purchase',
        'qty_change': qtyReceived,
        'qty_before': qtyBefore,
        'qty_after': qtyAfter,
        'reference_id': null,
        'reference_type': 'purchase',
        'note':
            notes ?? (supplierName != null ? 'સપ્લાયર: $supplierName' : null),
        'created_at': now,
      });

      // Effect 3: insert expense
      final expenseId = await txn.insert('expenses', {
        'expense_account_id': expenseAccountId,
        'account_name_snapshot': expenseAccountName,
        'amount': totalAmount,
        'description':
            'સ્ટોક ખરીદી: $productName'
            '${supplierName != null ? ' | $supplierName' : ''}',
        'expense_date': dateStr,
        'created_by': 'stock_purchase',
        'created_at': now,
      });

      // Effect 4: insert khata_ledger debit
      final khataId = await txn.insert('khata_ledger', {
        'entry_type': 'debit',
        'account_name': expenseAccountName,
        'customer_id': null,
        'amount': totalAmount,
        'payment_mode': null,
        'reference_type': 'expense',
        'reference_id': expenseId,
        'note': 'સ્ટોક ખરીદી: $productName',
        'entry_date': dateStr,
        'created_at': now,
      });

      // Reload updated product
      final updatedRows = (await txn.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
      )).cast<Map<String, dynamic>>();

      result = AddStockResult(
        updatedProduct: Product.fromMap(updatedRows.first),
        stockLogId: stockLogId,
        expenseId: expenseId,
        khataLedgerId: khataId,
      );
    });

    return result;
  }

  // ────────────────────────────────────────────────────────────────────────
  //  Stock alert check (called after bill save)
  // ────────────────────────────────────────────────────────────────────────

  /// Returns products that need alerts after a set of product IDs were sold.
  Future<StockAlertResult> checkStockAlerts(List<int> productIds) async {
    if (productIds.isEmpty) return const StockAlertResult([], []);
    final db = await _db.database;
    final placeholders = productIds.map((_) => '?').join(',');
    final rows = (await db.rawQuery('''
      SELECT * FROM products
      WHERE id IN ($placeholders) AND is_active = 1
    ''', productIds)).cast<Map<String, dynamic>>();

    final products = rows.map(Product.fromMap).toList();
    final lowStock = <Product>[];
    final outOfStock = <Product>[];
    for (final p in products) {
      if (p.stockQty <= 0) {
        outOfStock.add(p);
      } else if (p.minStockQty > 0 && p.stockQty <= p.minStockQty) {
        lowStock.add(p);
      }
    }
    return StockAlertResult(lowStock, outOfStock);
  }

  // ────────────────────────────────────────────────────────────────────────
  //  Dashboard summary
  // ────────────────────────────────────────────────────────────────────────

  Future<StockSummary> getSummary() async {
    final db = await _db.database;
    final total =
        (await db.rawQuery(
              'SELECT COUNT(*) as c FROM products WHERE is_active = 1',
            )).first['c']
            as int? ??
        0;
    final lowRows =
        (await db.rawQuery('''
      SELECT COUNT(*) as c FROM products
      WHERE is_active = 1 AND stock_qty <= min_stock_qty AND stock_qty > 0
    ''')).first['c']
            as int? ??
        0;
    final outRows =
        (await db.rawQuery('''
      SELECT COUNT(*) as c FROM products
      WHERE is_active = 1 AND stock_qty <= 0
    ''')).first['c']
            as int? ??
        0;
    return StockSummary(total: total, low: lowRows, outOfStock: outRows);
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Lightweight helpers
// ────────────────────────────────────────────────────────────────────────────

class CategoryRow {
  const CategoryRow({required this.id, required this.nameGujarati});
  final int id;
  final String nameGujarati;
}

class StockAlertResult {
  const StockAlertResult(this.lowStock, this.outOfStock);
  final List<Product> lowStock;
  final List<Product> outOfStock;
}

class StockSummary {
  const StockSummary({
    required this.total,
    required this.low,
    required this.outOfStock,
  });
  final int total;
  final int low;
  final int outOfStock;
}
