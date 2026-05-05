import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase._();

  static const int schemaVersion = 1;
  static const String dbFileName = 'kirana_shop.db';

  static Database? _instance;

  static Future<Database> get instance async {
    if (_instance != null) return _instance!;
    _instance = await _open();
    return _instance!;
  }

  static Future<Database> _open() async {
    String path;
    if (Platform.isAndroid || Platform.isIOS) {
      final dir = await getApplicationDocumentsDirectory();
      path = p.join(dir.path, dbFileName);
    } else {
      final dir = await getApplicationSupportDirectory();
      path = p.join(dir.path, dbFileName);
    }

    if (Platform.isWindows || Platform.isLinux) {
      return databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: schemaVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
    }
    return sqlcipher.openDatabase(
      path,
      version: schemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('PRAGMA foreign_keys = ON');

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name_gu TEXT NOT NULL,
        color_code TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name_gu TEXT NOT NULL,
        category_id INTEGER REFERENCES categories(id),
        barcode TEXT,
        unit TEXT NOT NULL,
        sale_price REAL NOT NULL,
        purchase_price REAL NOT NULL,
        current_stock REAL DEFAULT 0,
        low_stock_threshold REAL DEFAULT 0,
        is_active INTEGER DEFAULT 1
      )
    ''');
    await db.execute('CREATE INDEX idx_items_category ON items(category_id)');
    await db.execute('CREATE INDEX idx_items_barcode ON items(barcode)');

    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        pin TEXT NOT NULL,
        role TEXT NOT NULL,
        is_active INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_number TEXT NOT NULL,
        date_time INTEGER NOT NULL,
        customer_id INTEGER REFERENCES customers(id),
        subtotal REAL NOT NULL,
        discount_amount REAL DEFAULT 0,
        tax_amount REAL DEFAULT 0,
        total_amount REAL NOT NULL,
        paid_amount REAL DEFAULT 0,
        payment_mode TEXT NOT NULL,
        created_by_user_id INTEGER REFERENCES users(id)
      )
    ''');
    await db.execute('CREATE INDEX idx_bills_date ON bills(date_time)');
    await db.execute('CREATE INDEX idx_bills_customer ON bills(customer_id)');

    await db.execute('''
      CREATE TABLE bill_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_id INTEGER NOT NULL REFERENCES bills(id),
        item_id INTEGER NOT NULL REFERENCES items(id),
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        line_total REAL NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_bill_items_bill ON bill_items(bill_id)');

    await db.execute('''
      CREATE TABLE khata_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL REFERENCES customers(id),
        related_bill_id INTEGER REFERENCES bills(id),
        date_time INTEGER NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        note TEXT,
        balance_after REAL NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_khata_customer ON khata_entries(customer_id)',
    );
    await db.execute('CREATE INDEX idx_khata_date ON khata_entries(date_time)');

    await db.execute('''
      CREATE TABLE purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date_time INTEGER NOT NULL,
        supplier_name TEXT,
        total_amount REAL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE purchase_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id INTEGER NOT NULL REFERENCES purchases(id),
        item_id INTEGER NOT NULL REFERENCES items(id),
        quantity REAL NOT NULL,
        unit_cost REAL NOT NULL,
        line_total REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await _insertDefaults(db);
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Future migrations go here
  }

  static Future<void> _insertDefaults(Database db) async {
    final count = sqlcipher.Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM users'),
    );
    if ((count ?? 0) == 0) {
      await db.insert('users', {
        'name': 'માલિક',
        'pin': '1234',
        'role': 'owner',
        'is_active': 1,
      });
    }

    final settingsCount = sqlcipher.Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM settings'),
    );
    if ((settingsCount ?? 0) == 0) {
      await db.insert('settings', {'key': 'shop_name', 'value': 'મારી દુકાન'});
      await db.insert('settings', {'key': 'bill_counter', 'value': '1'});
      await db.insert('settings', {'key': 'large_text', 'value': 'false'});
    }
  }

  static Future<void> close() async {
    final db = _instance;
    _instance = null;
    if (db != null) await db.close();
  }

  static Future<String> exportToJson() async {
    final db = await instance;
    const tables = [
      'settings',
      'users',
      'categories',
      'items',
      'customers',
      'bills',
      'bill_items',
      'khata_entries',
      'purchases',
      'purchase_items',
    ];
    final Map<String, dynamic> out = {'schema_version': schemaVersion};
    for (final t in tables) {
      try {
        final rows = await db.query(t);
        out[t] = rows;
      } catch (_) {
        out[t] = [];
      }
    }
    return const JsonEncoder.withIndent('  ').convert(out);
  }

  static Future<void> importFromJson(String jsonStr) async {
    final db = await instance;
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    await db.transaction((txn) async {
      const tables = [
        'purchase_items',
        'purchases',
        'khata_entries',
        'bill_items',
        'bills',
        'items',
        'categories',
        'customers',
        'users',
        'settings',
      ];
      for (final t in tables) {
        final rows = data[t] as List<dynamic>?;
        if (rows == null || rows.isEmpty) continue;
        for (final row in rows) {
          final map = Map<String, Object?>.from(row as Map);
          await txn.insert(
            t,
            map,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }
}
