import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/user.dart';

class UserRepository {
  UserRepository(this._db);

  final Database _db;

  Future<User?> getById(int id) async {
    final maps = await _db.query('users', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  Future<User?> validatePin(String pin) async {
    final maps = await _db.query(
      'users',
      where: 'pin = ? AND is_active = 1',
      whereArgs: [pin],
    );
    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  Future<List<User>> getAll() async {
    final maps = await _db.query('users', orderBy: 'role ASC');
    return maps.map((m) => User.fromMap(m)).toList();
  }

  Future<int> insert(User u) async {
    return _db.insert('users', u.toMap());
  }

  Future<int> update(User u) async {
    if (u.id == null) return 0;
    return _db.update(
      'users',
      u.toMap(),
      where: 'id = ?',
      whereArgs: [u.id],
    );
  }
}
