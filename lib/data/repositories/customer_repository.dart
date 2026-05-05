import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/customer.dart';

class CustomerRepository {
  CustomerRepository(this._db);

  final Database _db;

  Future<List<Customer>> getAll() async {
    final maps = await _db.query('customers', orderBy: 'name ASC');
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  Future<List<Customer>> search(String query) async {
    if (query.trim().isEmpty) return getAll();
    final q = '%${query.trim()}%';
    final maps = await _db.query(
      'customers',
      where: 'name LIKE ? OR phone LIKE ?',
      whereArgs: [q, q],
      orderBy: 'name ASC',
    );
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  Future<Customer?> getById(int id) async {
    final maps = await _db.query('customers', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Customer.fromMap(maps.first);
  }

  Future<int> insert(Customer c) async {
    return _db.insert('customers', c.toMap());
  }

  Future<int> update(Customer c) async {
    if (c.id == null) return 0;
    return _db.update(
      'customers',
      c.toMap(),
      where: 'id = ?',
      whereArgs: [c.id],
    );
  }

  Future<int> delete(int id) async {
    return _db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }
}
