import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bharat_provision/shared/models/product_model.dart';
import 'package:bharat_provision/features/billing/billing_providers.dart';
import 'package:bharat_provision/features/billing/controllers/billing_controller.dart';
import 'package:bharat_provision/features/billing/views/billing_product_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testProducts = [
    const Product(
      id: 1,
      barcode: '111',
      nameGujarati: 'ઘઉં ૧ નંબર',
      nameEnglish: 'Wheat No 1',
      transliterationKeys: 'ghau wheat',
      unitType: 'કિલો',
      buyPrice: 30,
      sellPrice: 35,
      stockQty: 100,
      minStockQty: 10,
      isActive: true,
    ),
    const Product(
      id: 2,
      barcode: '222',
      nameGujarati: 'ચોખા બાસમતી',
      nameEnglish: 'Basmati Rice',
      transliterationKeys: 'chokha rice',
      unitType: 'કિલો',
      buyPrice: 60,
      sellPrice: 75,
      stockQty: 50,
      minStockQty: 5,
      isActive: true,
    ),
    const Product(
      id: 3,
      barcode: '333',
      nameGujarati: 'તુવેર દાળ',
      nameEnglish: 'Tuver Dal',
      transliterationKeys: 'tuver dal',
      unitType: 'કિલો',
      buyPrice: 110,
      sellPrice: 130,
      stockQty: 40,
      minStockQty: 5,
      isActive: true,
    ),
  ];

  testWidgets('BillingProductPanel navigates product suggestions with Arrow Down / Arrow Up and selects with Enter', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final searchController = TextEditingController();
    final searchFocusNode = FocusNode();

    final container = ProviderContainer(
      overrides: [
        billingItemsProvider.overrideWith((ref) => Future.value(testProducts)),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: BillingProductPanel(
              searchController: searchController,
              productSearchFocusNode: searchFocusNode,
              checkStock: ({required int itemId, required double newQtyGrams, int? excludeLineIndex}) async => true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Focus product search and type search query
    searchFocusNode.requestFocus();
    await tester.pumpAndSettle();

    searchController.text = 'દાળ';
    // Tap the search field to open dropdown
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();

    // Verify dropdown is visible and shows products in ListView
    final dropdownList = find.byType(ListView);
    expect(dropdownList, findsOneWidget);
    expect(find.descendant(of: dropdownList, matching: find.text('ઘઉં ૧ નંબર')), findsOneWidget);
    expect(find.descendant(of: dropdownList, matching: find.text('ચોખા બાસમતી')), findsOneWidget);
    expect(find.descendant(of: dropdownList, matching: find.text('તુવેર દાળ')), findsOneWidget);

    // Press Arrow Down -> first product (index 0) becomes highlighted
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    // Verify visual highlight icon (arrow_right) appears for highlighted item
    expect(find.byIcon(Icons.arrow_right), findsOneWidget);

    // Press Arrow Down again -> second product (index 1)
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    // Press Arrow Down again -> third product (index 2)
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    // Press Arrow Down again -> wraps around to index 0
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    // Press Arrow Up -> wraps back to index 2 (તુવેર દાળ)
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    // Press Enter to select the highlighted item
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    // Selected product should be item at index 2 (તુવેર દાળ) added to bill
    final billLines = container.read(billingControllerProvider).billLines;
    expect(billLines, isNotEmpty);
    expect(billLines.first.item.nameGujarati, 'તુવેર દાળ');
  });

  testWidgets('BillingProductPanel closes product suggestions on Escape', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final searchController = TextEditingController();
    final searchFocusNode = FocusNode();

    final container = ProviderContainer(
      overrides: [
        billingItemsProvider.overrideWith((ref) => Future.value(testProducts)),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: BillingProductPanel(
              searchController: searchController,
              productSearchFocusNode: searchFocusNode,
              checkStock: ({required int itemId, required double newQtyGrams, int? excludeLineIndex}) async => true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    searchFocusNode.requestFocus();
    searchController.text = 'ચોખા';
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsOneWidget);
    expect(find.descendant(of: find.byType(ListView), matching: find.text('ચોખા બાસમતી')), findsOneWidget);

    // Press Escape
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    // Dropdown ListView should be dismissed
    expect(find.byType(ListView), findsNothing);
  });
}
