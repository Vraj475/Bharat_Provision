import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bharat_provision/core/shortcuts/app_intents.dart';
import 'package:bharat_provision/core/shortcuts/app_shortcuts.dart';
import 'package:bharat_provision/features/billing/controllers/billing_controller.dart';
import 'package:bharat_provision/features/billing/models/bill_line_item.dart';
import 'package:bharat_provision/features/billing/views/bill_lines_panel.dart';
import 'package:bharat_provision/features/billing/views/bill_summary_panel.dart';
import 'package:bharat_provision/features/billing/billing_providers.dart';
import 'package:bharat_provision/shared/models/product_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Keyboard Shortcuts Definition Tests', () {
    test('Billing shortcuts are mapped to Ctrl+F, Ctrl+Enter and Ctrl+NumpadEnter in AppShortcuts.billingShortcuts', () {
      final map = AppShortcuts.billingShortcuts;

      expect(
        map[const SingleActivator(LogicalKeyboardKey.keyF, control: true)],
        isA<FocusProductSearchIntent>(),
      );
      expect(
        map[const SingleActivator(LogicalKeyboardKey.enter, control: true)],
        isA<SaveBillIntent>(),
      );
      expect(
        map[const SingleActivator(LogicalKeyboardKey.numpadEnter, control: true)],
        isA<SaveBillIntent>(),
      );
      expect(
        map[const SingleActivator(LogicalKeyboardKey.keyC, alt: true)],
        isA<TogglePaymentModeIntent>(),
      );
    });

    test('Module shortcuts are mapped in AppShortcuts.moduleShortcuts (Alt + 1 - 7)', () {
      final moduleMap = AppShortcuts.moduleShortcuts;
      expect(moduleMap[const SingleActivator(LogicalKeyboardKey.digit1, alt: true)], isA<NavigateToModuleIntent>());
      expect(moduleMap[const SingleActivator(LogicalKeyboardKey.numpad1, alt: true)], isA<NavigateToModuleIntent>());
      expect(moduleMap[const SingleActivator(LogicalKeyboardKey.digit2, alt: true)], isA<NavigateToModuleIntent>());
      expect(moduleMap[const SingleActivator(LogicalKeyboardKey.numpad2, alt: true)], isA<NavigateToModuleIntent>());
      expect(moduleMap[const SingleActivator(LogicalKeyboardKey.digit3, alt: true)], isA<NavigateToModuleIntent>());
      expect(moduleMap[const SingleActivator(LogicalKeyboardKey.numpad3, alt: true)], isA<NavigateToModuleIntent>());
      expect(moduleMap[const SingleActivator(LogicalKeyboardKey.digit4, alt: true)], isA<NavigateToModuleIntent>());
      expect(moduleMap[const SingleActivator(LogicalKeyboardKey.numpad4, alt: true)], isA<NavigateToModuleIntent>());
      expect(moduleMap[const SingleActivator(LogicalKeyboardKey.digit5, alt: true)], isA<NavigateToModuleIntent>());
      expect(moduleMap[const SingleActivator(LogicalKeyboardKey.numpad5, alt: true)], isA<NavigateToModuleIntent>());
      expect(moduleMap[const SingleActivator(LogicalKeyboardKey.digit6, alt: true)], isA<NavigateToModuleIntent>());
      expect(moduleMap[const SingleActivator(LogicalKeyboardKey.numpad6, alt: true)], isA<NavigateToModuleIntent>());
      expect(moduleMap[const SingleActivator(LogicalKeyboardKey.digit7, alt: true)], isA<NavigateToModuleIntent>());
      expect(moduleMap[const SingleActivator(LogicalKeyboardKey.numpad7, alt: true)], isA<NavigateToModuleIntent>());
    });
  });

  group('BillLinesPanel Ctrl+R and Tab Key Traversal Tests', () {
    testWidgets('Ctrl+R focuses first item weight, and Tab navigates Qty -> Price -> Amount -> next line', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final billLinesKey = GlobalKey<BillLinesPanelState>();
      final container = ProviderContainer();

      final p1 = Product(
        id: 1,
        nameGujarati: 'ખાંડ',
        nameEnglish: 'Sugar',
        transliterationKeys: 'khand sugar',
        unitType: 'કિલો',
        buyPrice: 38.0,
        sellPrice: 45.0,
        stockQty: 100.0,
        minStockQty: 10.0,
        isActive: true,
      );

      final p2 = Product(
        id: 2,
        nameGujarati: 'ચોખા',
        nameEnglish: 'Rice',
        transliterationKeys: 'chokha rice',
        unitType: 'કિલો',
        buyPrice: 50.0,
        sellPrice: 60.0,
        stockQty: 80.0,
        minStockQty: 5.0,
        isActive: true,
      );

      final controller = container.read(billingControllerProvider.notifier);
      controller.addLine(
        BillLineItem(draftKey: 'line_1', item: p1, qtyGrams: 2000.0, amount: 90.0),
      );
      controller.addLine(
        BillLineItem(draftKey: 'line_2', item: p2, qtyGrams: 1000.0, amount: 60.0),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: BillLinesPanel(
                key: billLinesKey,
                checkStock: ({required int itemId, required double newQtyGrams, int? excludeLineIndex}) async => true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Trigger Ctrl+R action directly on the state
      billLinesKey.currentState?.startEditingFirstItemWeight();
      await tester.pumpAndSettle();

      // We should now have a TextField open for quantity of first item
      expect(find.byType(TextField), findsOneWidget);
      final qtyTextField = tester.widget<TextField>(find.byType(TextField));
      expect(qtyTextField.controller?.text, '2.000');

      // Now press Tab key to advance to Price
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // Should now be editing Price
      expect(find.byType(TextField), findsOneWidget);
      final priceTextField = tester.widget<TextField>(find.byType(TextField));
      expect(priceTextField.controller?.text, '45.00');

      // Now press Tab key to advance to Amount
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // Should now be editing Amount
      expect(find.byType(TextField), findsOneWidget);
      final amountTextField = tester.widget<TextField>(find.byType(TextField));
      expect(amountTextField.controller?.text, '90.00');

      // Now press Tab key to advance to Next Item (Product 2 Quantity)
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // Should now be editing Product 2 Quantity
      expect(find.byType(TextField), findsOneWidget);
      final p2QtyTextField = tester.widget<TextField>(find.byType(TextField));
      expect(p2QtyTextField.controller?.text, '1.000');
    });
  });

  group('BillSummaryPanel Ctrl+D and Ctrl+G Tests', () {
    testWidgets('startDiscountEdit and startGrandTotalEdit open input fields', (tester) async {
      final summaryKey = GlobalKey<BillSummaryPanelState>();
      final container = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: BillSummaryPanel(
                key: summaryKey,
                onClearBill: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Trigger discount edit (Ctrl+D)
      summaryKey.currentState?.startDiscountEdit();
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);

      // Press Escape to cancel discount edit
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);

      // Trigger grand total edit (Ctrl+G)
      summaryKey.currentState?.startGrandTotalEdit();
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);

      // Press Escape to cancel grand total edit
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
    });
  });

  group('Shortcut trigger when TextField is focused', () {
    testWidgets('Ctrl+Enter when TextField has focus invokes SaveBillIntent', (tester) async {
      final focusNode = FocusNode();
      bool savePressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Shortcuts(
            shortcuts: AppShortcuts.billingShortcuts,
            child: Actions(
              actions: {
                SaveBillIntent: CallbackAction<SaveBillIntent>(
                  onInvoke: (_) {
                    savePressed = true;
                    return null;
                  },
                ),
              },
              child: Scaffold(
                body: TextField(
                  focusNode: focusNode,
                  autofocus: true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(focusNode.hasFocus, isTrue);

      // Press Ctrl + Enter
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(savePressed, isTrue, reason: 'Ctrl+Enter should be triggered');
    });

    testWidgets('commitCurrentEdit updates quantity on the active line', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final billLinesKey = GlobalKey<BillLinesPanelState>();
      final container = ProviderContainer();

      final p = Product(
        id: 10,
        nameGujarati: 'ઘઉં',
        nameEnglish: 'Wheat',
        transliterationKeys: 'ghau wheat',
        unitType: 'કિલો',
        buyPrice: 30.0,
        sellPrice: 35.0,
        stockQty: 50.0,
        minStockQty: 5.0,
        isActive: true,
      );

      final controller = container.read(billingControllerProvider.notifier);
      controller.addLine(
        BillLineItem(draftKey: 'line_w1', item: p, qtyGrams: 1000.0, amount: 35.0),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: BillLinesPanel(
                key: billLinesKey,
                checkStock: ({required int itemId, required double newQtyGrams, int? excludeLineIndex}) async => true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Start editing weight
      billLinesKey.currentState?.startEditingFirstItemWeight();
      await tester.pumpAndSettle();

      // Type new weight: 3.500 kg
      await tester.enterText(find.byType(TextField), '3.500');
      await tester.pumpAndSettle();

      // Commit edit using the public commitCurrentEdit
      final commitSuccess = await billLinesKey.currentState?.commitCurrentEdit();
      expect(commitSuccess, isTrue);
      await tester.pumpAndSettle();

      // Check updated quantity in provider: 3500 grams, amount = 3.5 * 35 = 122.5
      final updatedLines = container.read(billingControllerProvider).billLines;
      expect(updatedLines.first.qtyGrams, 3500.0);
      expect(updatedLines.first.amount, 122.5);
    });

    testWidgets('commitActiveEdits commits discount and grand total before save', (tester) async {
      final summaryKey = GlobalKey<BillSummaryPanelState>();
      final container = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: BillSummaryPanel(
                key: summaryKey,
                onClearBill: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Start discount edit
      summaryKey.currentState?.startDiscountEdit();
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '25.00');
      await tester.pumpAndSettle();

      // Commit active edits
      summaryKey.currentState?.commitActiveEdits();
      await tester.pumpAndSettle();

      // Verify discount is committed in controller
      expect(container.read(billingControllerProvider).discount, 25.0);
    });
  });

  group('BillLinesPanel Row Selection, Plus/Minus and Delete Tests', () {
    testWidgets('Tapping a row selects it, plus/minus adjusts quantity, delete removes it', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final billLinesKey = GlobalKey<BillLinesPanelState>();
      final container = ProviderContainer();

      final pWeight = const Product(
        id: 1,
        nameGujarati: 'ખાંડ',
        nameEnglish: 'Sugar',
        transliterationKeys: 'khand sugar',
        unitType: 'કિલો',
        buyPrice: 38.0,
        sellPrice: 40.0,
        stockQty: 100.0,
        minStockQty: 10.0,
        isActive: true,
      );

      final pCount = const Product(
        id: 2,
        nameGujarati: 'સાબુ',
        nameEnglish: 'Soap',
        transliterationKeys: 'sabu soap',
        unitType: 'count',
        buyPrice: 15.0,
        sellPrice: 20.0,
        stockQty: 50.0,
        minStockQty: 5.0,
        isActive: true,
      );

      final controller = container.read(billingControllerProvider.notifier);
      controller.addLine(
        BillLineItem(draftKey: 'l_sugar', item: pWeight, qtyGrams: 1000.0, amount: 40.0),
      );
      controller.addLine(
        BillLineItem(draftKey: 'l_soap', item: pCount, qtyGrams: 2.0, amount: 40.0),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: BillLinesPanel(
                key: billLinesKey,
                checkStock: ({required int itemId, required double newQtyGrams, int? excludeLineIndex}) async => true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially no row is selected
      expect(billLinesKey.currentState?.selectedRowIndex, isNull);
      expect(find.byIcon(Icons.arrow_right), findsNothing);

      // Tap on the first row ('ખાંડ')
      await tester.tap(find.text('ખાંડ'));
      await tester.pumpAndSettle();

      // Now first row is selected (index 0) and arrow_right icon is visible
      expect(billLinesKey.currentState?.selectedRowIndex, 0);
      expect(find.byIcon(Icons.arrow_right), findsOneWidget);

      // Increment quantity with '+' (step = +250g for weight)
      await billLinesKey.currentState?.incrementSelectedRowQty();
      await tester.pumpAndSettle();

      var lines = container.read(billingControllerProvider).billLines;
      expect(lines[0].qtyGrams, 1250.0);
      expect(lines[0].amount, 50.0); // 1.25 kg * 40

      // Decrement quantity with '-' (step = -250g)
      await billLinesKey.currentState?.decrementSelectedRowQty();
      await tester.pumpAndSettle();

      lines = container.read(billingControllerProvider).billLines;
      expect(lines[0].qtyGrams, 1000.0);
      expect(lines[0].amount, 40.0);

      // Select next row (navigates to index 1: 'સાબુ')
      billLinesKey.currentState?.selectNextRow();
      await tester.pumpAndSettle();
      expect(billLinesKey.currentState?.selectedRowIndex, 1);

      // Increment count item (+1 unit)
      await billLinesKey.currentState?.incrementSelectedRowQty();
      await tester.pumpAndSettle();

      lines = container.read(billingControllerProvider).billLines;
      expect(lines[1].qtyGrams, 3.0); // 2 -> 3
      expect(lines[1].amount, 60.0); // 3 * 20

      // Deselect row (Escape action)
      billLinesKey.currentState?.deselectRow();
      await tester.pumpAndSettle();
      expect(billLinesKey.currentState?.selectedRowIndex, isNull);
      expect(find.byIcon(Icons.arrow_right), findsNothing);

      // Select row 1 and delete it via deleteSelectedRow() (Ctrl + Delete)
      billLinesKey.currentState?.selectNextRow(); // selects 0
      billLinesKey.currentState?.selectNextRow(); // selects 1
      await tester.pumpAndSettle();
      expect(billLinesKey.currentState?.selectedRowIndex, 1);

      await billLinesKey.currentState?.deleteSelectedRow();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      lines = container.read(billingControllerProvider).billLines;
      expect(lines.length, 1);
      expect(lines[0].item.nameGujarati, 'ખાંડ');
    });
  });

  group('Payment Mode and Summary Actions Tests', () {
    testWidgets('Payment mode chips switch between Cash and Udhaar', (tester) async {
      final summaryKey = GlobalKey<BillSummaryPanelState>();
      final container = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: BillSummaryPanel(
                key: summaryKey,
                onClearBill: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default transaction type should be cash
      expect(container.read(billingTabsProvider).activeDraft.transactionType, 'cash');

      // Tap on Udhaar chip
      await tester.tap(find.text('📒 ઉધાર (Credit)'));
      await tester.pumpAndSettle();

      expect(container.read(billingTabsProvider).activeDraft.transactionType, 'khata');

      // Tap on Cash chip
      await tester.tap(find.text('💵 રોકડ (Cash)'));
      await tester.pumpAndSettle();

      expect(container.read(billingTabsProvider).activeDraft.transactionType, 'cash');
    });

    testWidgets('BillSummaryPanel triggers onSaveAndPrintBill callback', (tester) async {
      final summaryKey = GlobalKey<BillSummaryPanelState>();
      final container = ProviderContainer();
      bool saveAndPrintTriggered = false;

      // Add a line item to enable the save & print button
      const p = Product(
        id: 1,
        nameGujarati: 'ખાંડ',
        nameEnglish: 'Sugar',
        transliterationKeys: 'khand sugar',
        unitType: 'કિલો',
        buyPrice: 38.0,
        sellPrice: 40.0,
        stockQty: 100.0,
        minStockQty: 10.0,
        isActive: true,
      );
      container.read(billingControllerProvider.notifier).addLine(
        BillLineItem(draftKey: 'l1', item: p, qtyGrams: 1000.0, amount: 40.0),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: BillSummaryPanel(
                key: summaryKey,
                onClearBill: () {},
                onSaveAndPrintBill: () {
                  saveAndPrintTriggered = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Save & Print button
      await tester.tap(find.text('સાચવો & પ્રિન્ટ'));
      await tester.pumpAndSettle();

      expect(saveAndPrintTriggered, isTrue);
    });
  });

  group('Keyboard Traversal Loop (Qty -> Price -> Amount -> Up/Down & Search) Tests', () {
    testWidgets('Entering quantity advances to price, price advances to amount, enter on amount completes edit', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final billLinesKey = GlobalKey<BillLinesPanelState>();
      final container = ProviderContainer();
      bool editCompleted = false;

      final p1 = const Product(
        id: 1,
        nameGujarati: 'ખાંડ',
        nameEnglish: 'Sugar',
        barcode: '12345',
        transliterationKeys: 'khand sugar',
        unitType: 'કિલો',
        buyPrice: 38.0,
        sellPrice: 40.0,
        stockQty: 100.0,
        minStockQty: 10.0,
        isActive: true,
      );

      final p2 = const Product(
        id: 2,
        nameGujarati: 'તેલ',
        nameEnglish: 'Oil',
        barcode: '67890',
        transliterationKeys: 'tel oil',
        unitType: 'લિટર',
        buyPrice: 120.0,
        sellPrice: 150.0,
        stockQty: 50.0,
        minStockQty: 5.0,
        isActive: true,
      );

      final controller = container.read(billingControllerProvider.notifier);
      controller.addLine(
        BillLineItem(draftKey: 'l_sugar', item: p1, qtyGrams: 1000.0, amount: 40.0),
      );
      controller.addLine(
        BillLineItem(draftKey: 'l_oil', item: p2, qtyGrams: 2.0, amount: 300.0),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: BillLinesPanel(
                key: billLinesKey,
                checkStock: ({required int itemId, required double newQtyGrams, int? excludeLineIndex}) async => true,
                onInlineEditCompleted: () {
                  editCompleted = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Open weight/quantity edit on row 0
      billLinesKey.currentState?.startEditingLineQuantity(0);
      await tester.pumpAndSettle();

      // Quantity TextField is open
      expect(find.byType(TextField), findsOneWidget);
      final qtyField = tester.widget<TextField>(find.byType(TextField));
      expect(qtyField.controller?.text, '1.000');

      // Step 2: Submit new quantity (2.000 kg)
      await tester.enterText(find.byType(TextField), '2.000');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Step 3: Focus automatically moved to Unit Price TextField
      expect(find.byType(TextField), findsOneWidget);
      final priceField = tester.widget<TextField>(find.byType(TextField));
      expect(priceField.controller?.text, '40.00');
      expect(priceField.focusNode?.hasFocus, isTrue);

      // Step 4: Type new unit price (45.00) and submit
      await tester.enterText(find.byType(TextField), '45.00');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Step 5: Focus automatically moved to Final Price (Amount) TextField
      expect(find.byType(TextField), findsOneWidget);
      final amountField = tester.widget<TextField>(find.byType(TextField));
      expect(amountField.controller?.text, '90.00'); // 2.0 kg * 45.00
      expect(amountField.focusNode?.hasFocus, isTrue);

      // Step 6: Up / Down arrow key moves between product amount fields
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // Now row 1 Amount should be focused!
      expect(find.byType(TextField), findsOneWidget);
      final row1AmountField = tester.widget<TextField>(find.byType(TextField));
      expect(row1AmountField.controller?.text, '300.00');

      // Press Arrow Up to return to row 0 Amount
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      final row0ReturnAmountField = tester.widget<TextField>(find.byType(TextField));
      expect(row0ReturnAmountField.controller?.text, '90.00');

      // Step 7: Press Enter on Amount -> commits and calls onInlineEditCompleted
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(editCompleted, isTrue);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('Adding first product to empty bill opens quantity edit and updates quantity', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final billLinesKey = GlobalKey<BillLinesPanelState>();
      final p1 = Product(
        id: 1,
        categoryId: 1,
        nameGujarati: 'ખાંડ',
        nameEnglish: 'Sugar',
        barcode: '12345',
        transliterationKeys: 'khand sugar',
        unitType: 'કિલો',
        buyPrice: 35.0,
        sellPrice: 40.0,
        stockQty: 100.0,
        minStockQty: 10.0,
        isActive: true,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: BillLinesPanel(
                key: billLinesKey,
                checkStock: ({required int itemId, required double newQtyGrams, int? excludeLineIndex}) async => true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Bill starts empty
      expect(find.text('બિલ ખાલી છે'), findsOneWidget);
      expect(container.read(billingControllerProvider).billLines.isEmpty, isTrue);

      // Add the first product
      final controller = container.read(billingControllerProvider.notifier);
      controller.addLine(
        BillLineItem(draftKey: 'l_sugar_1', item: p1, qtyGrams: 1000.0, amount: 40.0),
      );

      // Trigger startEditingLineQuantity for the first product (index 0)
      billLinesKey.currentState?.startEditingLineQuantity(0);
      await tester.pumpAndSettle();

      // Verify empty text is gone and TextField is open with initial quantity
      expect(find.text('બિલ ખાલી છે'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      final qtyField = tester.widget<TextField>(find.byType(TextField));
      expect(qtyField.controller?.text, '1.000');

      // Edit quantity to 3.500 kg
      await tester.enterText(find.byType(TextField), '3.500');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Verify the quantity on the bill line was updated in controller state
      final lines = container.read(billingControllerProvider).billLines;
      expect(lines.length, 1);
      expect(lines.first.qtyGrams, 3500.0);
      expect(lines.first.amount, 140.0);
    });
  });
}

