import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:bharat_provision/core/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'dart:io';

class MockPathProviderPlatform extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  @override
  Future<String?> getApplicationSupportPath() async {
    final dir = Directory.systemTemp.createTempSync('db_test');
    return dir.path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    PathProviderPlatform.instance = MockPathProviderPlatform();
  });

  tearDownAll(() async {
    await DatabaseHelper.instance.close();
  });

  test('initDatabase creates tables and inserts defaults', () async {
    await DatabaseHelper.instance.initDatabase(adminPin: '1234');
    final db = await DatabaseHelper.instance.database;
    
    // Check settings
    final settings = await DatabaseHelper.instance.query('settings');
    expect(settings.isNotEmpty, true, reason: 'Settings should be inserted by default');
    
    // Check expense accounts
    final expenseAccounts = await DatabaseHelper.instance.query('expense_accounts');
    expect(expenseAccounts.isNotEmpty, true, reason: 'Expense accounts should be inserted');
    
    // Check transliteration
    final dictionary = await DatabaseHelper.instance.query('transliteration_dictionary');
    expect(dictionary.length, greaterThan(200), reason: 'Transliteration dictionary should have >200 entries');
  });

  test('User CRUD operations', () async {
    // Create
    final userId = await DatabaseHelper.instance.insert('users', {
      'role': 'admin',
      'display_name': 'Test User',
      'pin_hash': 'testhash',
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
    expect(userId, greaterThan(0));

    // Read
    final users = await DatabaseHelper.instance.query('users', where: 'id = ?', whereArgs: [userId]);
    expect(users.length, 1);
    expect(users.first['display_name'], 'Test User');

    // Update
    await DatabaseHelper.instance.update('users', {'display_name': 'Updated User'}, where: 'id = ?', whereArgs: [userId]);
    final updatedUsers = await DatabaseHelper.instance.query('users', where: 'id = ?', whereArgs: [userId]);
    expect(updatedUsers.first['display_name'], 'Updated User');

    // Delete
    await DatabaseHelper.instance.delete('users', where: 'id = ?', whereArgs: [userId]);
    final deletedUsers = await DatabaseHelper.instance.query('users', where: 'id = ?', whereArgs: [userId]);
    expect(deletedUsers.isEmpty, true);
  });

  test('Transactions and Foreign Keys', () async {
    // Insert category
    final categoryId = await DatabaseHelper.instance.insert('categories', {
      'name_gujarati': 'ટેસ્ટ કેટેગરી',
      'created_at': DateTime.now().toIso8601String(),
    });

    // Insert product
    final productId = await DatabaseHelper.instance.insert('products', {
      'name_gujarati': 'ટેસ્ટ પ્રોડક્ટ',
      'category_id': categoryId,
      'unit_type': 'kg',
      'buy_price': 100.0,
      'sell_price': 120.0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
    expect(productId, greaterThan(0));

    // Verify foreign key enforcement (insert product with invalid category)
    try {
      await DatabaseHelper.instance.insert('products', {
        'name_gujarati': 'Invalid',
        'category_id': 9999, // Doesn't exist
        'unit_type': 'kg',
        'buy_price': 10.0,
        'sell_price': 20.0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      fail('Should have thrown foreign key constraint error');
    } catch (e) {
      expect(e.toString().contains('FOREIGN KEY'), true);
    }
  });

  test('Export and Import JSON', () async {
    // Insert some test data to ensure export works
    await DatabaseHelper.instance.insert('customers', {
      'name_gujarati': 'ટેસ્ટ ગ્રાહક',
      'created_at': DateTime.now().toIso8601String(),
    });

    final jsonStr = await DatabaseHelper.instance.exportToJson();
    expect(jsonStr, isNotEmpty);
    
    final Map<String, dynamic> data = jsonDecode(jsonStr);
    expect(data.containsKey('settings'), true);
    expect(data.containsKey('customers'), true);
    
    final customersList = data['customers'] as List;
    expect(customersList.isNotEmpty, true);

    // Import the data back
    await DatabaseHelper.instance.importFromJson(jsonStr);
    
    // Verify it didn't crash and data is still there
    final customersAfter = await DatabaseHelper.instance.query('customers');
    expect(customersAfter.isNotEmpty, true);
  });
}
