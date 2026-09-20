import '../../core/database/database_helper.dart';
import '../../shared/models/customer_model.dart';

class CustomerRepository {
  CustomerRepository([DatabaseHelper? dbHelper])
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  Future<List<Customer>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query('customers', orderBy: 'name_gujarati ASC');
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  Future<List<Customer>> search(String query) async {
    if (query.trim().isEmpty) return getAll();
    final db = await _dbHelper.database;
    final q = '%${query.trim()}%';
    final maps = await db.query(
      'customers',
      where: 'name_gujarati LIKE ? OR name_english LIKE ? OR phone LIKE ?',
      whereArgs: [q, q, q],
      orderBy: 'name_gujarati ASC',
    );
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  Future<Customer?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Customer.fromMap(maps.first);
  }

  Future<int> insert(Customer c) async {
    final db = await _dbHelper.database;
    return db.insert('customers', {
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
    final db = await _dbHelper.database;
    return db.update(
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
    final db = await _dbHelper.database;
    return db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }
}
