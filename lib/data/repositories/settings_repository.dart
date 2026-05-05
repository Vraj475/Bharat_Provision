import 'package:sqflite_sqlcipher/sqflite.dart';

class SettingsRepository {
  SettingsRepository(this._db);

  final Database _db;

  Future<String> get(String key) async {
    final result = await _db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    if (result.isEmpty) return '';
    return (result.first['value'] as String?) ?? '';
  }

  Future<void> set(String key, String value) async {
    await _db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final v = await get(key);
    if (v.isEmpty) return defaultValue;
    return v.toLowerCase() == 'true' || v == '1';
  }

  Future<void> setBool(String key, bool value) async {
    await set(key, value.toString());
  }

  Future<int> getInt(String key, {int defaultValue = 0}) async {
    final v = await get(key);
    if (v.isEmpty) return defaultValue;
    return int.tryParse(v) ?? defaultValue;
  }
}
