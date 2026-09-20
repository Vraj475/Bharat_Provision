import '../../core/database/database_helper.dart';
import '../../domain/models/models.dart';

class ItemRepository {
  ItemRepository([DatabaseHelper? dbHelper])
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  Future<List<Product>> getAll({bool activeOnly = true}) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'products',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'name_gujarati ASC',
    );
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<List<Product>> search(String query, {bool lowStockOnly = false}) async {
    var where = 'is_active = 1';
    final args = <Object?>[];

    if (query.trim().isNotEmpty) {
      where +=
          ' AND (name_gujarati LIKE ? OR name_english LIKE ? OR barcode LIKE ? OR transliteration_keys LIKE ?)';
      final q = '%${query.trim()}%';
      args.addAll([q, q, q, q]);
    }
    if (lowStockOnly) {
      where += ' AND stock_qty <= min_stock_qty';
    }

    final db = await _dbHelper.database;
    final maps = await db.query(
      'products',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name_gujarati ASC',
    );
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<Product?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<Product?> getByBarcode(String barcode) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'products',
      where: 'barcode = ? AND is_active = 1',
      whereArgs: [barcode],
    );
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<int> insert(Product item) async {
    final now = DateTime.now().toIso8601String();
    final db = await _dbHelper.database;
    return db.insert('products', {
      'name_gujarati': item.nameGujarati,
      'name_english': item.nameEnglish,
      'transliteration_keys': item.transliterationKeys,
      'category_id': item.categoryId,
      'unit_type': item.unitType,
      'buy_price': item.buyPrice,
      'sell_price': item.sellPrice,
      'stock_qty': item.stockQty,
      'min_stock_qty': item.minStockQty,
      'is_active': item.isActive ? 1 : 0,
      'barcode': item.barcode,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<int> update(Product item) async {
    if (item.id == null) return 0;
    final now = DateTime.now().toIso8601String();
    final db = await _dbHelper.database;
    return db.update(
      'products',
      {
        'name_gujarati': item.nameGujarati,
        'name_english': item.nameEnglish,
        'transliteration_keys': item.transliterationKeys,
        'category_id': item.categoryId,
        'unit_type': item.unitType,
        'buy_price': item.buyPrice,
        'sell_price': item.sellPrice,
        'stock_qty': item.stockQty,
        'min_stock_qty': item.minStockQty,
        'is_active': item.isActive ? 1 : 0,
        'barcode': item.barcode,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> decreaseStock(int itemId, double qty) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final rows = await txn.query('products', columns: ['stock_qty'], where: 'id = ?', whereArgs: [itemId]);
      final qtyBefore = rows.isNotEmpty ? (rows.first['stock_qty'] as num?)?.toDouble() ?? 0.0 : 0.0;
      final qtyAfter = qtyBefore - qty;

      await txn.rawUpdate(
        'UPDATE products SET stock_qty = ?, updated_at = ? WHERE id = ?',
        [qtyAfter, DateTime.now().toIso8601String(), itemId],
      );

      await txn.insert('stock_log', {
        'product_id': itemId,
        'transaction_type': 'manual_deduction',
        'qty_change': -qty,
        'qty_before': qtyBefore,
        'qty_after': qtyAfter,
        'note': 'હસ્તચાલિત ઘટાડો',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<void> increaseStock(int itemId, double qty) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final rows = await txn.query('products', columns: ['stock_qty'], where: 'id = ?', whereArgs: [itemId]);
      final qtyBefore = rows.isNotEmpty ? (rows.first['stock_qty'] as num?)?.toDouble() ?? 0.0 : 0.0;
      final qtyAfter = qtyBefore + qty;

      await txn.rawUpdate(
        'UPDATE products SET stock_qty = ?, updated_at = ? WHERE id = ?',
        [qtyAfter, DateTime.now().toIso8601String(), itemId],
      );

      await txn.insert('stock_log', {
        'product_id': itemId,
        'transaction_type': 'manual_addition',
        'qty_change': qty,
        'qty_before': qtyBefore,
        'qty_after': qtyAfter,
        'note': 'હસ્તચાલિત ઉમેરો',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  // Categories
  Future<List<Category>> getCategories() async {
    final db = await _dbHelper.database;
    final maps = await db.query('categories', orderBy: 'name_gujarati ASC');
    return maps.map((m) => Category.fromMap(m)).toList();
  }

  Future<int> insertCategory(Category c) async {
    final db = await _dbHelper.database;
    return db.insert('categories', {
      'name_gujarati': c.nameGu,
      'name_english': null,
      'icon': c.colorCode,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> updateCategory(Category c) async {
    if (c.id == null) return 0;
    final db = await _dbHelper.database;
    return db.update(
      'categories',
      {'name_gujarati': c.nameGu, 'icon': c.colorCode},
      where: 'id = ?',
      whereArgs: [c.id],
    );
  }

  String generateTransliterationKeys(String nameGujarati) {
    if (nameGujarati.trim().isEmpty) return '';
    const map = {
      'ક': 'k', 'ખ': 'kh', 'ગ': 'g', 'ઘ': 'gh', 'ચ': 'ch', 'છ': 'chh', 'જ': 'j', 'ઝ': 'z',
      'ટ': 't', 'ઠ': 'th', 'ડ': 'd', 'ઢ': 'dh', 'ણ': 'n', 'ત': 't', 'થ': 'th', 'દ': 'd',
      'ધ': 'dh', 'ન': 'n', 'પ': 'p', 'ફ': 'f', 'બ': 'b', 'ભ': 'bh', 'મ': 'm', 'ય': 'y',
      'ર': 'r', 'લ': 'l', 'વ': 'v', 'શ': 'sh', 'ષ': 'sh', 'સ': 's', 'હ': 'h', 'ળ': 'l',
      'ા': 'a', 'િ': 'i', 'ી': 'ee', 'ુ': 'u', 'ૂ': 'oo', 'ે': 'e', 'ૈ': 'ai', 'ો': 'o', 'ૌ': 'au', 'ં': 'n', 'ઃ': 'h'
    };
    final buffer = StringBuffer();
    for (int i = 0; i < nameGujarati.length; i++) {
      final char = nameGujarati[i];
      if (map.containsKey(char)) {
        buffer.write(map[char]);
      } else if (RegExp(r'[a-zA-Z0-9\s]').hasMatch(char)) {
        buffer.write(char);
      }
    }
    final keys = <String>{};
    final phonetic = buffer.toString().toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (phonetic.isNotEmpty) keys.add(phonetic);
    for (final word in nameGujarati.split(RegExp(r'\s+'))) {
      if (word.isNotEmpty) keys.add(word.toLowerCase());
    }
    return keys.join(' ');
  }
}
