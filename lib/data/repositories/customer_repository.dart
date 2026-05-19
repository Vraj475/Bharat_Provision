import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/customer.dart';

class CustomerRepository {
  CustomerRepository(this._db);

  final Database _db;

  Future<List<Customer>> getAll() async {
    final maps = await _db.query('customers', orderBy: 'name_gujarati ASC');
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  Future<List<Customer>> search(String query) async {
    if (query.trim().isEmpty) return getAll();
    final q = '%${query.trim()}%';
    final maps = await _db.query(
      'customers',
      where: 'name_gujarati LIKE ? OR name_english LIKE ? OR phone LIKE ?',
      whereArgs: [q, q, q],
      orderBy: 'name_gujarati ASC',
    );
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  Future<Customer?> getById(int id) async {
    final maps = await _db.query('customers', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Customer.fromMap(maps.first);
  }

  Future<int> insert(Customer c) async {
    return _db.insert('customers', {
      'name_gujarati': c.name,
      'name_english': null,
      'phone': c.phone,
      'address': c.address,
      'account_type': 'regular',
      'credit_limit': 2000.0,
      'total_outstanding': 0.0,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> update(Customer c) async {
    if (c.id == null) return 0;
    return _db.update(
      'customers',
      {
        'name_gujarati': c.name,
        'phone': c.phone,
        'address': c.address,
      },
      where: 'id = ?',
      whereArgs: [c.id],
    );
  }

  Future<int> delete(int id) async {
    return _db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }
}
