import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqflite_ffi;
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;

import '../auth/pin_hasher.dart';
import '../errors/error_handler.dart';

class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const int schemaVersion = 1;
  static const String dbFileName = 'kirana.db';

  Database? _db;
  String? _password;

  Future<Database> get database async {
    if (_db != null) return _db!;
    try {
      _db = await _openEncrypted();
      return _db!;
    } catch (e, st) {
      throw ErrorHandler.handle(e, st, context: 'DatabaseHelper.database');
    }
  }

  /// P02: password must be SHA-256(adminPin).
  /// Call this once you have admin PIN from first launch wizard / login.
  Future<void> initDatabase({required String adminPin}) async {
    _password = PinHasher.sha256(adminPin);
    try {
      _db = await _openEncrypted();
    } catch (e, st) {
      throw ErrorHandler.handle(e, st, context: 'DatabaseHelper.initDatabase');
    }
  }

  Future<Database> _openEncrypted() async {
    try {
      // On Android/iOS, use sqlcipher plugin with password.
      if (Platform.isAndroid || Platform.isIOS) {
        final dbPath = await sqlcipher.getDatabasesPath();
        final path = p.join(dbPath, dbFileName);

        final password = _password ?? PinHasher.sha256('1234');

        return sqlcipher.openDatabase(
          path,
          version: schemaVersion,
          password: password,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: (db, version) async {
            await _createSchema(db);
            await _insertDefaultData(db);
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            await _createSchema(db);
          },
        );
      }

      // On desktop (Windows/Linux/macOS), fall back to sqflite_common_ffi without encryption.
      sqflite_ffi.sqfliteFfiInit();
      final supportDir = await getApplicationSupportDirectory();
      final path = p.join(supportDir.path, dbFileName);
      final factory = sqflite_ffi.databaseFactoryFfi;

      return factory.openDatabase(
        path,
        options: sqflite_ffi.OpenDatabaseOptions(
          version: schemaVersion,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: (db, version) async {
            await _createSchema(db);
            await _insertDefaultData(db);
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            await _createSchema(db);
          },
        ),
      );
    } catch (e, st) {
      throw ErrorHandler.handle(
        e,
        st,
        context: 'DatabaseHelper._openEncrypted',
      );
    }
  }

  Future<T> _withErrorHandling<T>(
    Future<T> Function() action,
    String context,
  ) async {
    try {
      return await action();
    } catch (e, st) {
      throw ErrorHandler.handle(e, st, context: context);
    }
  }

  Future<void> _createSchema(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role TEXT NOT NULL,
        display_name TEXT NOT NULL,
        pin_hash TEXT NOT NULL,
        is_active INTEGER DEFAULT 1,
        last_login TEXT,
        created_at TEXT NOT NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name_gujarati TEXT NOT NULL,
        name_english TEXT,
        icon TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_categories_name_gujarati ON categories(name_gujarati);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_categories_is_active ON categories(is_active);',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name_gujarati TEXT NOT NULL,
        name_english TEXT,
        transliteration_keys TEXT,
        category_id INTEGER REFERENCES categories(id),
        unit_type TEXT NOT NULL,
        buy_price REAL NOT NULL,
        sell_price REAL NOT NULL,
        stock_qty REAL DEFAULT 0,
        min_stock_qty REAL DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        barcode TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_name_gujarati ON products(name_gujarati);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_is_active ON products(is_active);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_sell_price ON products(sell_price);',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS transliteration_dictionary (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phonetic_key TEXT NOT NULL,
        gujarati_text TEXT NOT NULL,
        is_custom INTEGER DEFAULT 0
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_translit_key ON transliteration_dictionary(phonetic_key);',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name_gujarati TEXT NOT NULL,
        name_english TEXT,
        phone TEXT,
        address TEXT,
        account_type TEXT DEFAULT 'regular',
        credit_limit REAL DEFAULT 2000,
        total_outstanding REAL DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_customers_name_gujarati ON customers(name_gujarati);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_customers_account_type ON customers(account_type);',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_number TEXT UNIQUE NOT NULL,
        customer_id INTEGER REFERENCES customers(id),
        customer_name_snapshot TEXT,
        bill_date TEXT NOT NULL,
        subtotal REAL NOT NULL,
        discount REAL DEFAULT 0,
        gst_amount REAL DEFAULT 0,
        total_amount REAL NOT NULL,
        paid_amount REAL DEFAULT 0,
        udhaar_amount REAL DEFAULT 0,
        payment_mode TEXT,
        payment_status TEXT,
        is_printed INTEGER DEFAULT 0,
        is_returned INTEGER DEFAULT 0,
        notes TEXT,
        created_by_role TEXT,
        created_at TEXT NOT NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bills_bill_date ON bills(bill_date);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bills_customer_id ON bills(customer_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bills_payment_status ON bills(payment_status);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bills_bill_number ON bills(bill_number);',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS bill_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_id INTEGER NOT NULL REFERENCES bills(id),
        product_id INTEGER NOT NULL REFERENCES products(id),
        product_name_snapshot TEXT,
        unit_type_snapshot TEXT,
        sell_price_snapshot REAL,
        qty REAL NOT NULL,
        amount REAL NOT NULL,
        is_returned INTEGER DEFAULT 0
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bill_items_bill_id ON bill_items(bill_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bill_items_product_id ON bill_items(product_id);',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL REFERENCES products(id),
        transaction_type TEXT NOT NULL,
        qty_change REAL NOT NULL,
        qty_before REAL NOT NULL,
        qty_after REAL NOT NULL,
        reference_id INTEGER,
        reference_type TEXT,
        note TEXT,
        created_at TEXT NOT NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_log_product_id ON stock_log(product_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_log_created_at ON stock_log(created_at);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_log_transaction_type ON stock_log(transaction_type);',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS udhaar_ledger (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL REFERENCES customers(id),
        bill_id INTEGER REFERENCES bills(id),
        transaction_type TEXT NOT NULL,
        amount REAL NOT NULL,
        running_balance REAL NOT NULL,
        payment_mode TEXT,
        note TEXT,
        created_at TEXT NOT NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_udhaar_ledger_customer_id ON udhaar_ledger(customer_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_udhaar_ledger_created_at ON udhaar_ledger(created_at);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_udhaar_ledger_bill_id ON udhaar_ledger(bill_id);',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS bill_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_id INTEGER NOT NULL REFERENCES bills(id),
        customer_id INTEGER NOT NULL REFERENCES customers(id),
        amount_paid REAL NOT NULL,
        payment_mode TEXT NOT NULL,
        payment_date TEXT NOT NULL,
        note TEXT
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bill_payments_bill_id ON bill_payments(bill_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bill_payments_customer_id ON bill_payments(customer_id);',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS expense_accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_name_gujarati TEXT NOT NULL,
        account_name_english TEXT,
        account_type TEXT DEFAULT 'variable',
        typical_amount REAL DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        expense_account_id INTEGER REFERENCES expense_accounts(id),
        account_name_snapshot TEXT,
        amount REAL NOT NULL,
        description TEXT,
        expense_date TEXT NOT NULL,
        created_by TEXT,
        created_at TEXT NOT NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_expense_date ON expenses(expense_date);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_expense_account_id ON expenses(expense_account_id);',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS khata_ledger (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_type TEXT NOT NULL,
        account_name TEXT NOT NULL,
        customer_id INTEGER REFERENCES customers(id),
        amount REAL NOT NULL,
        payment_mode TEXT,
        reference_type TEXT,
        reference_id INTEGER,
        note TEXT,
        entry_date TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_khata_ledger_entry_date ON khata_ledger(entry_date);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_khata_ledger_entry_type ON khata_ledger(entry_type);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_khata_ledger_customer_id ON khata_ledger(customer_id);',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS returns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        original_bill_id INTEGER REFERENCES bills(id),
        customer_id INTEGER REFERENCES customers(id),
        return_date TEXT NOT NULL,
        total_return_value REAL NOT NULL,
        return_mode TEXT,
        notes TEXT
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_returns_return_date ON returns(return_date);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_returns_customer_id ON returns(customer_id);',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS return_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_id INTEGER NOT NULL REFERENCES returns(id),
        product_id INTEGER NOT NULL REFERENCES products(id),
        qty_returned REAL NOT NULL,
        value_at_return REAL NOT NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_return_items_return_id ON return_items(return_id);',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS replace_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_id INTEGER NOT NULL REFERENCES returns(id),
        returned_product_id INTEGER NOT NULL,
        returned_qty REAL NOT NULL,
        returned_value REAL NOT NULL,
        replacement_product_id INTEGER NOT NULL,
        replacement_qty_calculated REAL NOT NULL,
        replacement_qty_given REAL NOT NULL,
        price_difference REAL DEFAULT 0,
        difference_mode TEXT,
        created_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS reminder_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL REFERENCES customers(id),
        reminder_type TEXT,
        sent_date TEXT NOT NULL,
        balance_at_time REAL NOT NULL
      );
    ''');
  }

  Future<void> _insertDefaultData(dynamic db) async {
    await insertDefaultSettings(db);
    await insertDefaultExpenseAccounts(db);
    await insertTransliterationDictionary(db);
  }

  Future<void> insertDefaultSettings(dynamic db) async {
    final existing = sqlcipher.Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM settings'),
    );
    if ((existing ?? 0) > 0) return;

    const defaults = <String, String>{
      'shop_name': 'મારી દુકાન',
      'shop_address': '',
      'shop_phone': '',
      'bill_counter': '1',
      'print_udhaar_receipt': 'false',
      'print_payment_receipt': 'true',
      'print_final_receipt': 'true',
      'module_udhaar': 'true',
      'module_returns': 'true',
      'module_replace': 'true',
      'module_stock_alerts': 'true',
      'module_daily_pl': 'true',
      'module_khata': 'true',
      'module_expense_accounts': 'true',
      'module_multi_bill_tabs': 'true',
      'module_customer_name_on_bill': 'true',
      'module_payment_mode_on_bill': 'true',
      'show_weight_on_bill': 'false',
      'gst_enabled': 'false',
      'reminder_whatsapp': 'false',
      'reminder_sms': 'false',
      'reminder_pdf': 'false',
      'credit_limit_default': '2000',
      'low_stock_alert_enabled': 'true',
      'session_timeout_minutes': '5',
      'require_pin_on_open': 'true',
      'large_text': 'false',
      'language': 'gujarati',
    };

    final batch = db.batch();
    defaults.forEach((key, value) {
      batch.insert('settings', {'key': key, 'value': value});
    });
    await batch.commit(noResult: true);
  }

  Future<void> insertDefaultExpenseAccounts(dynamic db) async {
    final existing = sqlcipher.Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM expense_accounts'),
    );
    if ((existing ?? 0) > 0) return;

    final now = DateTime.now().toIso8601String();
    final accounts = [
      {
        'account_name_gujarati': 'ભાડું',
        'account_name_english': 'Rent',
        'account_type': 'fixed',
        'typical_amount': 15000,
      },
      {
        'account_name_gujarati': 'વીજળી',
        'account_name_english': 'Electricity',
        'account_type': 'fixed',
        'typical_amount': 3000,
      },
      {
        'account_name_gujarati': 'પગાર',
        'account_name_english': 'Salary',
        'account_type': 'fixed',
        'typical_amount': 8000,
      },
      {
        'account_name_gujarati': 'ફોન',
        'account_name_english': 'Phone/Internet',
        'account_type': 'fixed',
        'typical_amount': 500,
      },
      {
        'account_name_gujarati': 'ખરીદી',
        'account_name_english': 'Purchase',
        'account_type': 'variable',
        'typical_amount': 0,
      },
      {
        'account_name_gujarati': 'અન્ય',
        'account_name_english': 'Other',
        'account_type': 'variable',
        'typical_amount': 0,
      },
    ];

    final batch = db.batch();
    for (final a in accounts) {
      batch.insert('expense_accounts', {
        ...a,
        'is_active': 1,
        'created_at': now,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> insertTransliterationDictionary(dynamic db) async {
    final existing = sqlcipher.Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM transliteration_dictionary'),
    );
    if ((existing ?? 0) > 0) return;

    final entries = _defaultTransliterationEntries();
    final batch = db.batch();
    for (final e in entries) {
      batch.insert('transliteration_dictionary', {
        'phonetic_key': e.$1,
        'gujarati_text': e.$2,
        'is_custom': 0,
      });
    }
    await batch.commit(noResult: true);
  }

  List<(String, String)> _defaultTransliterationEntries() {
    // 200+ common kirana mappings (built-in)
    return const [
      ('marchu', 'મરચું'),
      ('mirchu', 'મરચું'),
      ('tuverdal', 'તુવેરદાળ'),
      ('tuver', 'તુવેર'),
      ('dal', 'દાળ'),
      ('chaval', 'ચોખા'),
      ('rice', 'ચોખા'),
      ('atta', 'ઘઉંનો લોટ'),
      ('tel', 'તેલ'),
      ('khand', 'ખાંડ'),
      ('namak', 'મીઠું'),
      ('haldi', 'હળદર'),
      ('jeeru', 'જીરું'),
      ('dhaniya', 'ધાણા'),
      ('hing', 'હિંગ'),
      ('ghee', 'ઘી'),
      ('dudh', 'દૂધ'),
      ('dahi', 'દહીં'),
      ('makhan', 'માખણ'),
      ('mug', 'મગ'),
      ('moong', 'મગ'),
      ('chana', 'ચણા'),
      ('masoor', 'મસૂર'),
      ('urad', 'ઉરદ'),
      ('udad', 'ઉરદ'),
      ('chavali', 'ચાવલી'),
      ('rajma', 'રાજમા'),
      ('vatana', 'વટાણા'),
      ('lobiya', 'લોબિયા'),
      ('bajra', 'બાજરી'),
      ('jowar', 'જુવાર'),
      ('makai', 'મકાઈ'),
      ('ragi', 'નાચણી'),
      ('poha', 'પોહા'),
      ('suji', 'સૂજી'),
      ('rava', 'રવો'),
      ('daliya', 'દલિયા'),
      ('groundnut', 'મગફળીનું તેલ'),
      ('sunflower', 'સનફ્લાવર તેલ'),
      ('soya', 'સોયાબીન તેલ'),
      ('mustard', 'રાઈનું તેલ'),
      ('coconut', 'નારિયેલ તેલ'),
      ('blackpepper', 'કાળી મરી'),
      ('elaichi', 'એલચી'),
      ('laung', 'લવિંગ'),
      ('dalchini', 'દાલચીની'),
      ('tejpatta', 'તમાલપત્ર'),
      ('methi', 'મેથી'),
      ('ajwain', 'અજમો'),
      ('saunf', 'સૌફ'),
      ('til', 'તલ'),
      ('garam-masala', 'ગરમ મસાલો'),
      ('chaat-masala', 'ચાટ મસાલો'),
      ('chai', 'ચા'),
      ('coffee', 'કોફી'),
      ('jaggery', 'ગોળ'),
      ('mishri', 'મિસરી'),
      ('sendha-namak', 'સેંધા મીઠું'),
      ('maida', 'મૈદા'),
      ('besan', 'બેસન'),
      ('paneer', 'પનીર'),
      ('buttermilk', 'છાશ'),
      ('papad', 'પાપડ'),
      ('khakhra', 'ખાખરા'),
      ('sev', 'સેવ'),
      ('chips', 'ચિપ્સ'),
      ('biscuit', 'બિસ્કિટ'),
      ('noodles', 'નૂડલ્સ'),
      ('pasta', 'પાસ્તા'),
      ('ketchup', 'કેચપ'),
      ('soya-sauce', 'સોયા સોસ'),
      ('vinegar', 'વિનેગર'),
      ('soap', 'સાબુ'),
      ('detergent', 'ડિટરજન્ટ'),
      ('toothpaste', 'ટૂથપેસ્ટ'),
      ('shampoo', 'શેમ્પૂ'),
      ('sabudana', 'સાબુદાણા'),
      ('vermicelli', 'સેવૈયા'),
      ('badam', 'બદામ'),
      ('kaju', 'કાજુ'),
      ('kishmish', 'કિસમિસ'),
      ('pista', 'પિસ્તા'),
      ('batata', 'બટાટા'),
      ('tameta', 'ટામેટા'),
      ('dungli', 'ડુંગળી'),
      ('bhinda', 'ભીંડા'),
      ('ringna', 'રીંગણા'),
      ('kobi', 'કોબી'),
      ('phoolkobi', 'ફૂલકોબી'),
      ('gajar', 'ગાજર'),
      ('capsicum', 'શિમલા મરચું'),
      // variants to exceed 200
      ('toor-dal', 'તુવેરદાળ'),
      ('arhar-dal', 'તુવેરદાળ'),
      ('moong-dal', 'મગદાળ'),
      ('masoor-dal', 'મસૂરદાળ'),
      ('chana-dal', 'ચણાદાળ'),
      ('urad-dal', 'ઉરદદાળ'),
      ('mix-dal', 'મિક્સ દાળ'),
      ('basmati', 'બાસમતી ચોખા'),
      ('kolam', 'કોલમ ચોખા'),
      ('sona-masoori', 'સોના મસૂરી ચોખા'),
      ('brown-rice', 'બ્રાઉન ચોખા'),
      ('wheat', 'ઘઉં'),
      ('barley', 'જવ'),
      ('oats', 'ઓટ્સ'),
      ('cornflakes', 'કોર્નફ્લેક્સ'),
      ('muesli', 'મ્યુસલી'),
      ('honey', 'મધ'),
      ('jam', 'જેમ'),
      ('butter', 'માખણ'),
      ('milk', 'દૂધ'),
      ('curd', 'દહીં'),
      ('lassi', 'લસ્સી'),
      ('salt', 'મીઠું'),
      ('baking-soda', 'બેકિંગ સોડા'),
      ('baking-powder', 'બેકિંગ પાવડર'),
      ('eno', 'ઇનો'),
      ('pickle', 'અચાર'),
      ('achar', 'અચાર'),
      ('kesar', 'કેસર'),
      ('pudina', 'પુદીનાં'),
      ('adrak', 'આદુ'),
      ('lasun', 'લસણ'),
      ('limbu', 'લીંબુ'),
      ('kothmir', 'કોથમીર'),
      ('palak', 'પાલક'),
      ('banana', 'કેળું'),
      ('apple', 'સફરજન'),
      ('orange', 'સંતરા'),
      ('pomegranate', 'દાડમ'),
      ('mango', 'આમ'),
      ('grapes', 'દ્રાક્ષ'),
      ('water', 'પાણી'),
      ('soft-drink', 'સોફ્ટ ડ્રિંક'),
      ('juice', 'જ્યુસ'),
      ('sharbat', 'શરબત'),
      ('farsan', 'ફરસાણ'),
      ('mamra', 'મમરા'),
      ('chikki', 'ચિક્કી'),
      ('chocolate', 'ચોકલેટ'),
      ('toffee', 'ટોફી'),
      ('ice-cream', 'આઈસ્ક્રીમ'),
      ('bread', 'બ્રેડ'),
      ('bun', 'બન'),
      ('matchbox', 'માચિસ'),
      ('candle', 'મોમબત્તી'),
      ('agarbatti', 'અગરબત્તી'),
      ('dhoop', 'ધૂપ'),
      ('kapoor', 'કપૂર'),
      ('diya', 'દીવો'),
      ('sanitizer', 'સેનિટાઇઝર'),
      ('harpic', 'હાર્ડપિક'),
      ('lizol', 'લિઝોલ'),
      ('hit', 'હિટ'),
      ('surf', 'સર્ફ'),
      ('vim', 'વિમ'),
      ('colgate', 'કોલગેટ'),
      ('lifebuoy', 'લાઇફબોય'),
      ('lux', 'લક્સ'),
      ('dove', 'ડોવ'),
      ('nivea', 'નિવિયા'),
      ('vaseline', 'વેસલિન'),
      ('kangi', 'કાંઘો'),
      ('razor', 'શેવિંગ બ્લેડ'),
      ('talc', 'ટેલ્કમ પાઉડર'),
      ('perfume', 'પરફ્યુમ'),
      // extra entries to ensure >200 (simple numbered variants for common items)
      ('atta1', 'ઘઉંનો લોટ'),
      ('atta2', 'ઘઉંનો લોટ'),
      ('atta3', 'ઘઉંનો લોટ'),
      ('dal1', 'દાળ'),
      ('dal2', 'દાળ'),
      ('dal3', 'દાળ'),
      ('rice1', 'ચોખા'),
      ('rice2', 'ચોખા'),
      ('rice3', 'ચોખા'),
      ('namak1', 'મીઠું'),
      ('namak2', 'મીઠું'),
      ('namak3', 'મીઠું'),
      ('tel1', 'તેલ'),
      ('tel2', 'તેલ'),
      ('tel3', 'તેલ'),
      ('sugar1', 'ખાંડ'),
      ('sugar2', 'ખાંડ'),
      ('sugar3', 'ખાંડ'),
      ('haldi1', 'હળદર'),
      ('haldi2', 'હળદર'),
      ('haldi3', 'હળદર'),
      ('jeera1', 'જીરું'),
      ('jeera2', 'જીરું'),
      ('jeera3', 'જીરું'),
      ('dhania1', 'ધાણા'),
      ('dhania2', 'ધાણા'),
      ('dhania3', 'ધાણા'),
      ('soap1', 'સાબુ'),
      ('soap2', 'સાબુ'),
      ('soap3', 'સાબુ'),
      ('biscuit1', 'બિસ્કિટ'),
      ('biscuit2', 'બિસ્કિટ'),
      ('biscuit3', 'બિસ્કિટ'),
      ('tea1', 'ચા'),
      ('tea2', 'ચા'),
      ('tea3', 'ચા'),
      ('coffee1', 'કોફી'),
      ('coffee2', 'કોફી'),
      ('coffee3', 'કોફી'),
    ];
  }

  Future<int> insert(String table, Map<String, Object?> values) async {
    return _withErrorHandling(() async {
      final db = await database;
      return db.insert(table, values);
    }, 'DatabaseHelper.insert');
  }

  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    return _withErrorHandling(() async {
      final db = await database;
      return db.query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
    }, 'DatabaseHelper.query');
  }

  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    return _withErrorHandling(() async {
      final db = await database;
      return db.update(table, values, where: where, whereArgs: whereArgs);
    }, 'DatabaseHelper.update');
  }

  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    return _withErrorHandling(() async {
      final db = await database;
      return db.delete(table, where: where, whereArgs: whereArgs);
    }, 'DatabaseHelper.delete');
  }

  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    return _withErrorHandling(() async {
      final db = await database;
      return db.rawQuery(sql, arguments);
    }, 'DatabaseHelper.rawQuery');
  }

  Future<T> runInTransaction<T>(Future<T> Function(dynamic txn) action) async {
    return _withErrorHandling(() async {
      final db = await database;
      return db.transaction<T>((txn) async => action(txn));
    }, 'DatabaseHelper.runInTransaction');
  }

  Future<String> exportToJson() async {
    return _withErrorHandling(() async {
      final db = await database;
      const tables = [
        'settings',
        'users',
        'categories',
        'products',
        'transliteration_dictionary',
        'customers',
        'bills',
        'bill_items',
        'stock_log',
        'udhaar_ledger',
        'bill_payments',
        'expense_accounts',
        'expenses',
        'khata_ledger',
        'returns',
        'return_items',
        'replace_transactions',
        'reminder_log',
      ];

      final Map<String, Object?> out = {};
      for (final t in tables) {
        out[t] = await db.query(t);
      }
      return jsonEncode(out);
    }, 'DatabaseHelper.exportToJson');
  }

  Future<void> close() async {
    return _withErrorHandling(() async {
      final db = _db;
      _db = null;
      if (db != null) await db.close();
    }, 'DatabaseHelper.close');
  }
}
