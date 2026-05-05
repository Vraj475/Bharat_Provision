import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/category.dart';
import '../models/item.dart';

class ItemRepository {
  ItemRepository(this._db);

  final Database _db;

  Future<List<Item>> getAll({bool activeOnly = true}) async {
    final maps = await _db.query(
      'items',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'name_gu ASC',
    );
    return maps.map((m) => Item.fromMap(m)).toList();
  }

  Future<List<Item>> search(String query, {bool lowStockOnly = false}) async {
    var where = 'is_active = 1';
    final args = <Object?>[];

    if (query.trim().isNotEmpty) {
      where += ' AND (name_gu LIKE ? OR barcode LIKE ?)';
      final q = '%${query.trim()}%';
      args.addAll([q, q]);
    }
    if (lowStockOnly) {
      where += ' AND current_stock <= low_stock_threshold';
    }

    final maps = await _db.query(
      'items',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name_gu ASC',
    );
    return maps.map((m) => Item.fromMap(m)).toList();
  }

  Future<Item?> getById(int id) async {
    final maps = await _db.query('items', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Item.fromMap(maps.first);
  }

  Future<Item?> getByBarcode(String barcode) async {
    final maps = await _db.query(
      'items',
      where: 'barcode = ? AND is_active = 1',
      whereArgs: [barcode],
    );
    if (maps.isEmpty) return null;
    return Item.fromMap(maps.first);
  }

  Future<int> insert(Item item) async {
    return _db.insert('items', item.toMap());
  }

  Future<int> update(Item item) async {
    if (item.id == null) return 0;
    return _db.update(
      'items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> delete(int id) async {
    return _db.delete('items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> decreaseStock(int itemId, double qty) async {
    await _db.rawUpdate(
      'UPDATE items SET current_stock = current_stock - ? WHERE id = ?',
      [qty, itemId],
    );
  }

  Future<void> increaseStock(int itemId, double qty) async {
    await _db.rawUpdate(
      'UPDATE items SET current_stock = current_stock + ? WHERE id = ?',
      [qty, itemId],
    );
  }

  // Categories
  Future<List<Category>> getCategories() async {
    final maps = await _db.query('categories', orderBy: 'name_gu ASC');
    return maps.map((m) => Category.fromMap(m)).toList();
  }

  Future<int> insertCategory(Category c) async {
    return _db.insert('categories', c.toMap());
  }

  Future<int> updateCategory(Category c) async {
    if (c.id == null) return 0;
    return _db.update(
      'categories',
      c.toMap(),
      where: 'id = ?',
      whereArgs: [c.id],
    );
  }
}
