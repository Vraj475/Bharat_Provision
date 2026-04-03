import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppData {
  static const String _shopNameKey = 'shop_name';
  static const String _defaultShopName = 'My Shop';

  static Future<String> getShopName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_shopNameKey)?.trim();
    final shopName = (name == null || name.isEmpty) ? _defaultShopName : name;
    debugPrint('Shop Name: $shopName');
    return shopName;
  }
}

Future<String> getShopName() {
  return AppData.getShopName();
}
