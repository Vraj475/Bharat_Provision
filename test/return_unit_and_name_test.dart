import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';
import 'package:bharat_provision/data/repositories/return_repository.dart';
import 'package:bharat_provision/core/database/database_helper.dart';

class MockDatabaseHelper extends Mock implements DatabaseHelper {}
class MockDatabase extends Mock implements Database {}

void main() {
  group('ReturnRepository unit helpers', () {
    test('formatUnitName correctly maps Gujarati and English unit names', () {
      expect(ReturnRepository.formatUnitName('કિલો'), 'કિલો');
      expect(ReturnRepository.formatUnitName('kg'), 'કિલો');
      expect(ReturnRepository.formatUnitName('weight_kg'), 'કિલો');
      expect(ReturnRepository.formatUnitName('kilo'), 'કિલો');

      expect(ReturnRepository.formatUnitName('ગ્રામ'), 'ગ્રામ');
      expect(ReturnRepository.formatUnitName('gram'), 'ગ્રામ');
      expect(ReturnRepository.formatUnitName('g'), 'ગ્રામ');
      expect(ReturnRepository.formatUnitName('weight_gram'), 'ગ્રામ');

      expect(ReturnRepository.formatUnitName('લીટર'), 'લીટર');
      expect(ReturnRepository.formatUnitName('liter'), 'લીટર');
      expect(ReturnRepository.formatUnitName('litre'), 'લીટર');
      expect(ReturnRepository.formatUnitName('l'), 'લીટર');

      expect(ReturnRepository.formatUnitName('નંગ'), 'નંગ');
      expect(ReturnRepository.formatUnitName('piece'), 'નંગ');
      expect(ReturnRepository.formatUnitName('pcs'), 'નંગ');
      expect(ReturnRepository.formatUnitName('unit'), 'નંગ');
      expect(ReturnRepository.formatUnitName('units'), 'નંગ');

      expect(ReturnRepository.formatUnitName('પેકેટ'), 'પેકેટ');
      expect(ReturnRepository.formatUnitName('packet'), 'પેકેટ');
      expect(ReturnRepository.formatUnitName('pkt'), 'પેકેટ');

      expect(ReturnRepository.formatUnitName('બોક્સ'), 'બોક્સ');
      expect(ReturnRepository.formatUnitName('box'), 'બોક્સ');

      expect(ReturnRepository.formatUnitName(null), 'નંગ');
      expect(ReturnRepository.formatUnitName(''), 'નંગ');
    });

    test('isWeightUnit, isKiloUnit, isGramUnit, isLiterUnit, isDecimalUnit behave accurately', () {
      expect(ReturnRepository.isKiloUnit('કિલો'), isTrue);
      expect(ReturnRepository.isKiloUnit('kg'), isTrue);
      expect(ReturnRepository.isKiloUnit('લીટર'), isFalse);
      expect(ReturnRepository.isKiloUnit('નંગ'), isFalse);

      expect(ReturnRepository.isGramUnit('ગ્રામ'), isTrue);
      expect(ReturnRepository.isGramUnit('gram'), isTrue);
      expect(ReturnRepository.isGramUnit('કિલો'), isFalse);

      expect(ReturnRepository.isLiterUnit('લીટર'), isTrue);
      expect(ReturnRepository.isLiterUnit('liter'), isTrue);
      expect(ReturnRepository.isLiterUnit('કિલો'), isFalse);

      expect(ReturnRepository.isDecimalUnit('કિલો'), isTrue);
      expect(ReturnRepository.isDecimalUnit('ગ્રામ'), isTrue);
      expect(ReturnRepository.isDecimalUnit('લીટર'), isTrue);
      expect(ReturnRepository.isDecimalUnit('નંગ'), isFalse);
      expect(ReturnRepository.isDecimalUnit('પેકેટ'), isFalse);
      expect(ReturnRepository.isDecimalUnit('બોક્સ'), isFalse);
    });
  });

  group('ReturnRepository getBillItems product name and correspondence unit resolution', () {
    late MockDatabaseHelper mockHelper;
    late MockDatabase mockDb;
    late ReturnRepository repo;

    setUp(() {
      mockHelper = MockDatabaseHelper();
      mockDb = MockDatabase();
      when(() => mockHelper.database).thenAnswer((_) async => mockDb);
      repo = ReturnRepository(mockHelper);
    });

    test('resolves product name and correspondence unit from products table when snapshots are missing or placeholders', () async {
      when(() => mockDb.rawQuery(any(), any())).thenAnswer((_) async => [
        {
          'id': 101,
          'bill_id': 1,
          'product_id': 5,
          'product_name_snapshot': null,
          'unit_type_snapshot': null,
          'sell_price_snapshot': 50.0,
          'qty': 2.0,
          'amount': 100.0,
          'is_returned': 0,
          'prod_name_gu': 'ખાંડ (સુગર)',
          'prod_name_en': 'Sugar',
          'prod_unit_type': 'કિલો',
        },
        {
          'id': 102,
          'bill_id': 1,
          'product_id': 6,
          'product_name_snapshot': '—',
          'unit_type_snapshot': 'pcs', // legacy or generic snapshot
          'sell_price_snapshot': 150.0,
          'qty': 1.0,
          'amount': 150.0,
          'is_returned': 0,
          'prod_name_gu': 'સીંગતેલ',
          'prod_name_en': 'Groundnut Oil',
          'prod_unit_type': 'લીટર',
        },
      ]);

      final items = await repo.getBillItems(1);

      expect(items.length, 2);
      // Item 1: Sugar
      expect(items[0].productNameSnapshot, 'ખાંડ (સુગર)');
      expect(items[0].unitTypeSnapshot, 'કિલો');

      // Item 2: Oil (should take product correspondence unit 'લીટર' instead of generic 'pcs' snapshot, and resolve name from prod_name_gu instead of '—')
      expect(items[1].productNameSnapshot, 'સીંગતેલ');
      expect(items[1].unitTypeSnapshot, 'લીટર');
    });
  });
}
