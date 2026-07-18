import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:bharat_provision/data/repositories/bill_repository.dart';
import 'package:bharat_provision/data/models/bill_item_input.dart';

class MockDatabase extends Mock implements Database {}
class MockTransaction extends Mock implements Transaction {}

void main() {
  late MockDatabase db;
  late MockTransaction txn;
  late BillRepository repo;

  setUp(() {
    db = MockDatabase();
    txn = MockTransaction();
    repo = BillRepository(db);

    // Ensure we can pass the transaction callback
    when(() => db.transaction<int>(any())).thenAnswer((invocation) async {
      final action = invocation.positionalArguments[0] as Future<int> Function(Transaction);
      return await action(txn);
    });

    when(() => txn.rawQuery(any(), any())).thenAnswer((invocation) async {
      final query = invocation.positionalArguments[0] as String;
      if (query.contains('sqlite_master')) {
        return [
          {'name': 'bills'},
          {'name': 'bill_items'},
          {'name': 'settings'},
          {'name': 'items'}
        ];
      }
      if (query.contains('PRAGMA table_info')) {
        return [
          {'name': 'id'},
          {'name': 'bill_number'},
          {'name': 'customer_name_snapshot'}
        ];
      }
      if (query.contains('settings')) {
        return [{'value': '1'}];
      }
      if (query.contains('MAX')) {
        return [{'max_bill': 1}];
      }
      return [];
    });

    when(() => txn.insert(any(), any())).thenAnswer((_) async => 1);
    when(() => txn.update(any(), any(), where: any(named: 'where'))).thenAnswer((_) async => 1);
    when(() => txn.rawUpdate(any(), any())).thenAnswer((_) async => 1);
  });

  test('Schema introspection triggers exactly once across multiple createBill calls', () async {
    // 1) First call to createBill
    await repo.createBill(
      customerId: 1,
      items: [
        BillItemInput(
          itemId: 101,
          quantity: 1,
          unitPrice: 100,
        )
      ],
      discountAmount: 0,
      paidAmount: 100,
      paymentMode: 'cash',
    );

    // Verify schema queries were executed (1 sqlite_master + 4 tables = 5 schema queries)
    verify(() => txn.rawQuery(any(that: contains('sqlite_master')), any())).called(1);
    verify(() => txn.rawQuery(any(that: contains('PRAGMA table_info')), any())).called(4);
    
    // Clear mock interactions for the spy check
    clearInteractions(txn);

    // 2) Second call to createBill
    await repo.createBill(
      customerId: 2,
      items: [
        BillItemInput(
          itemId: 102,
          quantity: 2,
          unitPrice: 50,
        )
      ],
      discountAmount: 0,
      paidAmount: 100,
      paymentMode: 'cash',
    );

    // Verify ZERO PRAGMA or schema queries were executed on subsequent calls
    verifyNever(() => txn.rawQuery(any(that: contains('sqlite_master')), any()));
    verifyNever(() => txn.rawQuery(any(that: contains('PRAGMA table_info')), any()));
    
    // Verify it still executed other queries like insert/update properly
    verify(() => txn.insert('bills', any())).called(1);
  });
}
