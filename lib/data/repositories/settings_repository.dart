import 'package:sqflite_common/sqflite.dart';

import '../../core/database/database_helper.dart';

class SettingsRepository {
  SettingsRepository([DatabaseHelper? dbHelper])
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  Future<String> get(String key) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    if (result.isEmpty) return '';
    return (result.first['value'] as String?) ?? '';
  }

  Future<void> set(String key, String value) async {
    final db = await _dbHelper.database;
    await db.insert('settings', {
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
