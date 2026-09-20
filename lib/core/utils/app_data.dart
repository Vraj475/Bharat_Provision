import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';

class AppData {
  static const String _shopNameKey = 'shop_name';
  static const String _defaultShopName = 'My Shop';

  static Future<String> getShopName() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        'settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [_shopNameKey],
      );
      if (result.isNotEmpty) {
        final val = (result.first['value'] as String?)?.trim();
        if (val != null && val.isNotEmpty) {
          return val;
        }
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_shopNameKey)?.trim();
      if (name != null && name.isNotEmpty) {
        return name;
      }
    } catch (_) {}

    return _defaultShopName;
  }
}

Future<String> getShopName() {
  return AppData.getShopName();
}
