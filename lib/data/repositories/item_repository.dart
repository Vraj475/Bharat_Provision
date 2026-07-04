import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/category.dart';
import '../models/item.dart';

class ItemRepository {
  ItemRepository(this._db);

  final Database _db;

  Future<List<Item>> getAll({bool activeOnly = true}) async {
    final maps = await _db.query(
      'products',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'name_gujarati ASC',
    );
    return maps.map((m) => Item.fromMap(m)).toList();
  }

  Future<List<Item>> search(String query, {bool lowStockOnly = false}) async {
    var where = 'is_active = 1';
    final args = <Object?>[];

    if (query.trim().isNotEmpty) {
      where +=
          ' AND (name_gujarati LIKE ? OR name_english LIKE ? OR barcode LIKE ?)';
      final q = '%${query.trim()}%';
      args.addAll([q, q, q]);
    }
    if (lowStockOnly) {
      where += ' AND stock_qty <= min_stock_qty';
    }

    final maps = await _db.query(
      'products',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name_gujarati ASC',
    );
    return maps.map((m) => Item.fromMap(m)).toList();
  }

  Future<Item?> getById(int id) async {
    final maps = await _db.query('products', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Item.fromMap(maps.first);
  }

  Future<Item?> getByBarcode(String barcode) async {
    final maps = await _db.query(
      'products',
      where: 'barcode = ? AND is_active = 1',
      whereArgs: [barcode],
    );
    if (maps.isEmpty) return null;
    return Item.fromMap(maps.first);
  }

  Future<int> insert(Item item) async {
    final now = DateTime.now().toIso8601String();
    return _db.insert('products', {
      'name_gujarati': item.nameGu,
      'name_english': null,
      'transliteration_keys': null,
      'category_id': item.categoryId,
      'unit_type': item.unit,
      'buy_price': item.purchasePrice,
      'sell_price': item.salePrice,
      'stock_qty': item.currentStock,
      'min_stock_qty': item.lowStockThreshold,
      'is_active': item.isActive ? 1 : 0,
      'barcode': item.barcode,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<int> update(Item item) async {
    if (item.id == null) return 0;
    final now = DateTime.now().toIso8601String();
    return _db.update(
      'products',
      {
        'name_gujarati': item.nameGu,
        'category_id': item.categoryId,
        'unit_type': item.unit,
        'buy_price': item.purchasePrice,
        'sell_price': item.salePrice,
        'stock_qty': item.currentStock,
        'min_stock_qty': item.lowStockThreshold,
        'is_active': item.isActive ? 1 : 0,
        'barcode': item.barcode,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> delete(int id) async {
    return _db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> decreaseStock(int itemId, double qty) async {
    await _db.rawUpdate(
      'UPDATE products SET stock_qty = stock_qty - ?, updated_at = ? WHERE id = ?',
      [qty, DateTime.now().toIso8601String(), itemId],
    );
  }

  Future<void> increaseStock(int itemId, double qty) async {
    await _db.rawUpdate(
      'UPDATE products SET stock_qty = stock_qty + ?, updated_at = ? WHERE id = ?',
      [qty, DateTime.now().toIso8601String(), itemId],
    );
  }

  // Categories
  Future<List<Category>> getCategories() async {
    final maps = await _db.query('categories', orderBy: 'name_gujarati ASC');
    return maps.map((m) => Category.fromMap(m)).toList();
  }

  Future<int> insertCategory(Category c) async {
    return _db.insert('categories', {
      'name_gujarati': c.nameGu,
      'name_english': null,
      'icon': c.colorCode,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> updateCategory(Category c) async {
    if (c.id == null) return 0;
    return _db.update(
      'categories',
      {'name_gujarati': c.nameGu, 'icon': c.colorCode},
      where: 'id = ?',
      whereArgs: [c.id],
    );
  }
}
