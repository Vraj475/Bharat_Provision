import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../shared/models/customer_model.dart';

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
      'name_gujarati': c.nameGujarati,
      'name_english': c.nameEnglish,
      'phone': c.phone,
      'address': c.address,
      'account_type': c.accountType,
      'credit_limit': c.creditLimit,
      'total_outstanding': c.totalOutstanding,
      'is_active': c.isActive ? 1 : 0,
      'created_at': c.createdAt,
    });
  }

  Future<int> update(Customer c) async {
    if (c.id == null) return 0;
    return _db.update(
      'customers',
      {
        'name_gujarati': c.nameGujarati,
        'name_english': c.nameEnglish,
        'phone': c.phone,
        'address': c.address,
        'account_type': c.accountType,
        'credit_limit': c.creditLimit,
        'total_outstanding': c.totalOutstanding,
        'is_active': c.isActive ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [c.id],
    );
  }

  Future<int> delete(int id) async {
    return _db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }
}
