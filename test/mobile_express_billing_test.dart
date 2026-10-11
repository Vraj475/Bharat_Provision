import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:bharat_provision/features/billing/views/mobile_express_billing_view.dart';
import 'package:bharat_provision/data/repositories/item_repository.dart';
import 'package:bharat_provision/data/providers.dart';
import 'package:bharat_provision/shared/models/product_model.dart';

class MockItemRepository extends Mock implements ItemRepository {}

void main() {
  late MockItemRepository mockItemRepo;
  late GlobalKey boundaryKey;
  late TextEditingController customerController;

  setUp(() {
    mockItemRepo = MockItemRepository();
    boundaryKey = GlobalKey();
    customerController = TextEditingController();
  });

  tearDown(() {
    customerController.dispose();
  });

  testWidgets('MobileExpressBillingView renders and allows 1-screen product search and quantity adjustment', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final testProduct = Product(
      id: 50,
      nameGujarati: 'તુવેર દાળ',
      nameEnglish: 'Tuver Dal',
      transliterationKeys: 'tuver dal',
      unitType: 'કિલો',
      buyPrice: 120.0,
      sellPrice: 150.0,
      stockQty: 25.0,
      minStockQty: 5.0,
      categoryId: 1,
      isActive: true,
      createdAt: '2026-10-01',
      updatedAt: '2026-10-01',
    );

    when(() => mockItemRepo.search('તુવેર', lowStockOnly: false))
        .thenAnswer((_) async => [testProduct]);

    bool saveCalled = false;
    bool printCalled = false;
    bool clearCalled = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          itemRepositoryProvider.overrideWithValue(mockItemRepo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MobileExpressBillingView(
              boundaryKey: boundaryKey,
              customerName: null,
              customerId: null,
              customerController: customerController,
              onCustomerSelected: (_, __) {},
              onClearCustomer: () {},
              checkStock: ({required int itemId, required double newQtyGrams, int? excludeLineIndex}) async => true,
              onSaveBill: () => saveCalled = true,
              onPrintBill: () => printCalled = true,
              onClearBill: () => clearCalled = true,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify initial empty bill state & top bar
    expect(find.text('રોકડ ગ્રાહક'), findsOneWidget);
    expect(find.text('બિલ ખાલી છે'), findsOneWidget);
    expect(find.text('ઉત્પાદન / બારકોડ શોધો...'), findsOneWidget);

    // 2. Search for item in search box
    await tester.enterText(find.byType(TextField).first, 'તુવેર');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    // 3. Verify suggestion dropdown appears
    expect(find.text('તુવેર દાળ'), findsOneWidget);
    expect(find.textContaining('₹150.00 / કિલો'), findsOneWidget);

    // 4. Tap suggestion -> Weight asking dialog must appear
    await tester.tap(find.text('તુવેર દાળ'));
    await tester.pumpAndSettle();

    // Verify weight asking dialog appears
    expect(find.text('વજન (કિલો)'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'કિલોમાં દાખલ કરો જેમ કે 1.500'), '1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('ઉમેરો'));
    await tester.pumpAndSettle();

    // 5. Verify item appears in the live bill lines table
    expect(find.text('તુવેર દાળ'), findsOneWidget);
    expect(find.text('1.000 કિલો'), findsOneWidget);
    expect(find.text('₹150.00'), findsWidgets);
    expect(find.text('+ નવી વસ્તુ ઉમેરો'), findsOneWidget);

    // Verify discount button shows minus icon and '- ₹0'
    expect(find.text('- ₹0'), findsOneWidget);

    // Test clicking product name opens weight asking dialog
    await tester.tap(find.text('તુવેર દાળ'));
    await tester.pumpAndSettle();
    expect(find.text('વજન (કિલો)'), findsOneWidget);
    await tester.tap(find.text('રદ કરો'));
    await tester.pumpAndSettle();

    // 6. Test quick Kirana weight chip: tap 500g chip
    final chip500g = find.text('500g');
    expect(chip500g, findsOneWidget);
    await tester.tap(chip500g);
    await tester.pumpAndSettle();

    // 500g should now update quantity to 0.500 kg and amount to ₹75.00
    expect(find.text('0.500 કિલો'), findsOneWidget);
    expect(find.text('₹75.00'), findsWidgets);

    // 7. Test Stepper [+] button: adds 250g -> 0.750 kg
    final addIcon = find.byIcon(Icons.add);
    expect(addIcon, findsOneWidget);
    await tester.tap(addIcon);
    await tester.pumpAndSettle();

    expect(find.text('0.750 કિલો'), findsOneWidget);

    // 8. Test payment mode chips
    final onlineChip = find.text('📱 ઓનલાઇન');
    expect(onlineChip, findsOneWidget);
    await tester.tap(onlineChip);
    await tester.pumpAndSettle();

    // 9. Test Save & Print button
    final printBtn = find.text('સાચવો & પ્રિન્ટ');
    expect(printBtn, findsOneWidget);
    await tester.tap(printBtn);
    expect(printCalled, isTrue);

    // 10. Test Save button
    final saveBtn = find.text('સાચવો');
    expect(saveBtn, findsOneWidget);
    await tester.tap(saveBtn);
    expect(saveCalled, isTrue);

    // 11. Test Clear bill button
    final clearBtn = find.text('સાફ કરો');
    expect(clearBtn, findsOneWidget);
    await tester.tap(clearBtn);
    expect(clearCalled, isTrue);
  });
}
