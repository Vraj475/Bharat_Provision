import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:bharat_provision/core/database/database_helper.dart';
import 'package:bharat_provision/data/repositories/purchase_repository.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationSupportPath() async {
    final dir = Directory.systemTemp.createTempSync('purchase_db_test');
    return dir.path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper dbHelper;
  late PurchaseRepository purchaseRepo;
  late Database db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PathProviderPlatform.instance = MockPathProviderPlatform();
    dbHelper = DatabaseHelper.instance;
    db = await dbHelper.database;
  });

  tearDownAll(() async {
    await dbHelper.close();
  });

  setUp(() async {
    await db.delete('purchase_items');
    await db.delete('purchases');
    await db.delete('stock_log');
    await db.delete('expenses');
    await db.delete('khata_ledger');
    await db.delete('products');
    purchaseRepo = PurchaseRepository(dbHelper);
  });

  tearDown(() async {
    await db.delete('purchase_items');
    await db.delete('purchases');
    await db.delete('stock_log');
    await db.delete('expenses');
    await db.delete('khata_ledger');
    await db.delete('products');
  });

  group('PurchaseRepository Tests', () {
    test('createPurchase updates stock, weighted average cost, expenses, and logs', () async {
      final now = DateTime.now().toIso8601String();

      // Insert product with stock 10, buy_price 50, sell_price 70
      final prodId = await db.insert('products', {
        'name_gujarati': 'ઘઉં',
        'name_english': 'Wheat',
        'unit_type': 'weight_kg',
        'buy_price': 50.0,
        'sell_price': 70.0,
        'stock_qty': 10.0,
        'min_stock_qty': 5.0,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });

      // Purchase 10 units at 60 each (new weighted avg should be 55.0)
      final result = await purchaseRepo.createPurchase(
        purchaseDate: DateTime.now(),
        supplierName: 'પટેલ ટ્રેડર્સ',
        supplierPhone: '9876543210',
        paymentMode: 'cash',
        paidAmount: 600.0,
        notes: 'બિલ નંબર 123',
        items: [
          PurchaseItemInput(
            productId: prodId,
            qty: 10.0,
            unitCost: 60.0,
          ),
        ],
      );

      expect(result.purchaseNo, startsWith('PUR-'));
      expect(result.totalAmount, 600.0);
      expect(result.itemsCount, 1);

      // Verify product state
      final prodRows = await db.query('products', where: 'id = ?', whereArgs: [prodId]);
      expect(prodRows.first['stock_qty'], 20.0);
      expect(prodRows.first['buy_price'], 55.0);
      expect(prodRows.first['sell_price'], 70.0); // Unchanged

      // Verify purchase record
      final pRows = await db.query('purchases', where: 'id = ?', whereArgs: [result.purchaseId]);
      expect(pRows.isNotEmpty, isTrue);
      expect(pRows.first['supplier_name'], 'પટેલ ટ્રેડર્સ');

      // Verify purchase_items record
      final itemRows = await db.query('purchase_items', where: 'purchase_id = ?', whereArgs: [result.purchaseId]);
      expect(itemRows.length, 1);
      expect(itemRows.first['old_cost_price'], 50.0);
      expect(itemRows.first['new_cost_price'], 55.0);
      expect(itemRows.first['old_stock_qty'], 10.0);

      // Verify stock_log
      final stockLogs = await db.query('stock_log', where: 'product_id = ?', whereArgs: [prodId]);
      expect(stockLogs.isNotEmpty, isTrue);
      expect(stockLogs.first['transaction_type'], 'purchase');
      expect(stockLogs.first['qty_change'], 10.0);

      // Verify expenses
      final expRows = await db.query('expenses', where: 'description LIKE ?', whereArgs: ['%#${result.purchaseNo}%']);
      expect(expRows.isNotEmpty, isTrue);
      expect(expRows.first['amount'], 600.0);

      // Verify khata_ledger
      final ledgerRows = await db.query('khata_ledger', where: 'reference_type = ? AND reference_id = ?', whereArgs: ['purchase', result.purchaseId]);
      expect(ledgerRows.isNotEmpty, isTrue);
      expect(ledgerRows.first['entry_type'], 'debit');
      expect(ledgerRows.first['amount'], 600.0);
    });

    test('createPurchase identifies price increase >= 10% and applies custom sell price', () async {
      final now = DateTime.now().toIso8601String();

      // Product: 5 units @ 40 cost, 60 sell
      final prodId = await db.insert('products', {
        'name_gujarati': 'ખાંડ',
        'name_english': 'Sugar',
        'unit_type': 'weight_kg',
        'buy_price': 40.0,
        'sell_price': 60.0,
        'stock_qty': 5.0,
        'min_stock_qty': 5.0,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });

      // Buy 15 units @ 60 cost.
      // New avg = (5*40 + 15*60) / 20 = (200 + 900) / 20 = 55.
      // Cost increase: (55 - 40) / 40 = 37.5% >= 10%!
      final result = await purchaseRepo.createPurchase(
        purchaseDate: DateTime.now(),
        paymentMode: 'cash',
        paidAmount: 900.0,
        items: [
          PurchaseItemInput(
            productId: prodId,
            qty: 15.0,
            unitCost: 60.0,
            customSellPrice: 75.0, // Updated sell price
          ),
        ],
      );

      expect(result.priceAlerts.length, 1);
      expect(result.priceAlerts.first.productId, prodId);
      expect(result.priceAlerts.first.percentageIncrease, closeTo(37.5, 0.1));

      // Verify updated product sell price
      final prodRows = await db.query('products', where: 'id = ?', whereArgs: [prodId]);
      expect(prodRows.first['buy_price'], 55.0);
      expect(prodRows.first['sell_price'], 75.0);
    });

    test('deletePurchase safely reverts stock and removes expense/ledger entries', () async {
      final now = DateTime.now().toIso8601String();

      final prodId = await db.insert('products', {
        'name_gujarati': 'ચોખા',
        'name_english': 'Rice',
        'unit_type': 'weight_kg',
        'buy_price': 40.0,
        'sell_price': 50.0,
        'stock_qty': 10.0,
        'min_stock_qty': 5.0,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });

      final result = await purchaseRepo.createPurchase(
        purchaseDate: DateTime.now(),
        paymentMode: 'cash',
        paidAmount: 500.0,
        items: [
          PurchaseItemInput(
            productId: prodId,
            qty: 10.0,
            unitCost: 50.0,
          ),
        ],
      );

      // Verify stock was 20
      var prod = await db.query('products', where: 'id = ?', whereArgs: [prodId]);
      expect(prod.first['stock_qty'], 20.0);

      // Delete the purchase
      await purchaseRepo.deletePurchase(result.purchaseId);

      // Verify stock and price are reverted
      prod = await db.query('products', where: 'id = ?', whereArgs: [prodId]);
      expect(prod.first['stock_qty'], 10.0);
      expect(prod.first['buy_price'], 40.0);

      // Verify purchase and items deleted
      final purchases = await db.query('purchases', where: 'id = ?', whereArgs: [result.purchaseId]);
      expect(purchases.isEmpty, isTrue);

      final items = await db.query('purchase_items', where: 'purchase_id = ?', whereArgs: [result.purchaseId]);
      expect(items.isEmpty, isTrue);

      // Verify expense deleted
      final exps = await db.query('expenses', where: 'description LIKE ?', whereArgs: ['%#${result.purchaseNo}%']);
      expect(exps.isEmpty, isTrue);
    });
  });
}
