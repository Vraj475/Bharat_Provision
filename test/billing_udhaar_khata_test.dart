import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:bharat_provision/core/database/database_helper.dart';
import 'package:bharat_provision/data/repositories/bill_repository.dart';
import 'package:bharat_provision/data/repositories/customer_repository.dart';
import 'package:bharat_provision/data/repositories/khata_repository.dart';
import 'package:bharat_provision/shared/models/bill_item_model.dart';
import 'package:bharat_provision/shared/models/customer_model.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationSupportPath() async {
    final dir = Directory.systemTemp.createTempSync('khata_test');
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

  group('Udhaar (Khata) Billing Integration Tests', () {
    test('Saving Udhaar bill auto-creates customer and creates debit entry in Khata', () async {
      final db = await DatabaseHelper.instance.database;
      final billRepo = BillRepository(DatabaseHelper.instance);
      final customerRepo = CustomerRepository(DatabaseHelper.instance);
      final khataRepo = KhataRepository(DatabaseHelper.instance);

      // Create an item in items/products table so stock deduction succeeds
      final productId = await db.insert('products', {
        'name_gujarati': 'ઘઉં',
        'name_english': 'Wheat',
        'unit_type': 'કિલો',
        'buy_price': 30.0,
        'sell_price': 35.0,
        'stock_qty': 100.0,
        'min_stock_qty': 5.0,
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });

      final billItems = [
        BillItem(
          billId: 0,
          productId: productId,
          productNameSnapshot: 'ઘઉં',
          unitTypeSnapshot: 'કિલો',
          qty: 10.0,
          amount: 350.0,
          sellPriceSnapshot: 35.0,
          isReturned: false,
        ),
      ];

      // Save an Udhaar bill with customer name 'રમેશભાઈ પટેલ' without pre-existing customer ID
      final billId = await billRepo.createBill(
        customerId: null,
        customerNameSnapshot: 'રમેશભાઈ પટેલ',
        items: billItems,
        discountAmount: 0.0,
        otherCharges: 0.0,
        paidAmount: 350.0, // Even if passed 350, createBill forces 0.0 for khata!
        paymentMode: 'khata',
      );

      expect(billId, greaterThan(0));

      // 1. Verify customer was created in customers table
      final customers = await customerRepo.search('રમેશભાઈ પટેલ');
      expect(customers, isNotEmpty);
      final customer = customers.first;
      expect(customer.nameGujarati, 'રમેશભાઈ પટેલ');
      expect(customer.totalOutstanding, 350.0);

      // 2. Verify bill has paid_amount 0, due_amount 350, payment_status 'unpaid'
      final billRows = await db.query('bills', where: 'id = ?', whereArgs: [billId]);
      expect(billRows, isNotEmpty);
      final billRow = billRows.first;
      expect((billRow['paid_amount'] as num?)?.toDouble(), 0.0);
      expect((billRow['total_amount'] as num?)?.toDouble(), 350.0);
      expect(billRow['payment_status'], 'unpaid');
      expect(billRow['customer_id'], customer.id);

      // 3. Verify khata_entries has a debit record for this customer
      final entries = await khataRepo.getEntries(customer.id!);
      expect(entries, isNotEmpty);
      final firstEntry = entries.first;
      expect(firstEntry.type, 'debit');
      expect(firstEntry.amount, 350.0);
      expect(firstEntry.balanceAfter, 350.0);
      expect(firstEntry.relatedBillId, billId);

      // 4. Verify KhataRepository.getBalance reflects the outstanding balance
      final balance = await khataRepo.getBalance(customer.id!);
      expect(balance, 350.0);

      // 5. Verify customer bills list shows the unpaid bill
      final pendingBills = await khataRepo.getCustomerBills(customer.id!);
      expect(pendingBills, isNotEmpty);
      expect(pendingBills.first['id'], billId);
    });

    test('Subsequent Udhaar bills accumulate customer outstanding balance correctly', () async {
      final db = await DatabaseHelper.instance.database;
      final billRepo = BillRepository(DatabaseHelper.instance);
      final customerRepo = CustomerRepository(DatabaseHelper.instance);
      final khataRepo = KhataRepository(DatabaseHelper.instance);

      // Fetch the existing customer 'રમેશભાઈ પટેલ'
      final customers = await customerRepo.search('રમેશભાઈ પટેલ');
      expect(customers, isNotEmpty);
      final customer = customers.first;
      final initialBalance = await khataRepo.getBalance(customer.id!);
      expect(initialBalance, 350.0);

      // Get an existing product
      final productRows = await db.query('products', limit: 1);
      final productId = productRows.first['id'] as int;

      // Add a second Udhaar bill for 150.0
      final secondBillItems = [
        BillItem(
          billId: 0,
          productId: productId,
          productNameSnapshot: 'ઘઉં',
          unitTypeSnapshot: 'કિલો',
          qty: 2.0,
          amount: 150.0,
          sellPriceSnapshot: 75.0,
          isReturned: false,
        ),
      ];

      final secondBillId = await billRepo.createBill(
        customerId: customer.id,
        customerNameSnapshot: 'રમેશભાઈ પટેલ',
        items: secondBillItems,
        discountAmount: 0.0,
        paidAmount: 0.0,
        paymentMode: 'khata',
      );

      expect(secondBillId, greaterThan(0));

      // Balance should now be 350.0 + 150.0 = 500.0
      final updatedBalance = await khataRepo.getBalance(customer.id!);
      expect(updatedBalance, 500.0);

      final updatedCustomer = await customerRepo.getById(customer.id!);
      expect(updatedCustomer?.totalOutstanding, 500.0);

      final entries = await khataRepo.getEntries(customer.id!);
      expect(entries.length, 2);
      expect(entries.first.balanceAfter, 500.0); // latest entry has 500.0
    });
  });
}
