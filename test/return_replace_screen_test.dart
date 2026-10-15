import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bharat_provision/features/returns/return_replace_screen.dart';
import 'package:bharat_provision/features/returns/returns_providers.dart';
import 'package:bharat_provision/data/repositories/return_repository.dart';
import 'package:bharat_provision/shared/models/bill_model.dart';
import 'package:bharat_provision/shared/models/bill_item_model.dart';

class MockReturnRepository extends Mock implements ReturnRepository {}

void main() {
  late MockReturnRepository mockRepo;

  setUp(() {
    mockRepo = MockReturnRepository();
  });

  testWidgets('ReturnReplaceScreen displays correct product names and correspondence units', (tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final testBill = Bill(
      id: 1,
      billNumber: 'BILL-001',
      customerId: 1,
      customerNameSnapshot: 'રમેશભાઈ',
      billDate: '2026-10-08',
      subtotal: 450.0,
      discount: 0.0,
      gstAmount: 0.0,
      totalAmount: 450.0,
      paidAmount: 450.0,
      paymentMode: 'cash',
      paymentStatus: 'paid',
      isPrinted: false,
      isReturned: false,
      createdAt: '2026-10-08T10:00:00',
    );

    final testItems = [
      const BillItem(
        id: 1,
        billId: 1,
        productId: 10,
        productNameSnapshot: 'ખાંડ પ્રીમિયમ',
        unitTypeSnapshot: 'કિલો',
        sellPriceSnapshot: 50.0,
        qty: 2.0,
        amount: 100.0,
        isReturned: false,
      ),
      const BillItem(
        id: 2,
        billId: 1,
        productId: 11,
        productNameSnapshot: 'કપાસિયા તેલ',
        unitTypeSnapshot: 'લીટર',
        sellPriceSnapshot: 150.0,
        qty: 2.0,
        amount: 300.0,
        isReturned: false,
      ),
      const BillItem(
        id: 3,
        billId: 1,
        productId: 12,
        productNameSnapshot: 'પારલે-જી બિસ્કિટ',
        unitTypeSnapshot: 'પેકેટ',
        sellPriceSnapshot: 10.0,
        qty: 5.0,
        amount: 50.0,
        isReturned: false,
      ),
    ];

    when(() => mockRepo.getBillHistory(
          query: any(named: 'query'),
          paymentStatus: any(named: 'paymentStatus'),
          from: any(named: 'from'),
          to: any(named: 'to'),
        )).thenAnswer((_) async => [testBill]);

    when(() => mockRepo.getBillItems(1)).thenAnswer((_) async => testItems);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          returnRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: ReturnReplaceScreen(),
        ),
      ),
    );

    // Initial bill list load
    await tester.pumpAndSettle();

    // Verify bill appears
    expect(find.textContaining('BILL-001'), findsOneWidget);
    expect(find.text('રમેશભાઈ'), findsOneWidget);

    // Tap to open the bill
    await tester.tap(find.textContaining('BILL-001'));
    await tester.pumpAndSettle();

    // Verify product names are rendered properly (not empty or —)
    expect(find.text('ખાંડ પ્રીમિયમ'), findsOneWidget);
    expect(find.text('કપાસિયા તેલ'), findsOneWidget);
    expect(find.text('પારલે-જી બિસ્કિટ'), findsOneWidget);

    // Verify correspondence units are displayed (not generic pcs)
    expect(find.text('2 કિલો'), findsOneWidget);
    expect(find.text('2 લીટર'), findsOneWidget);
    expect(find.text('5 પેકેટ'), findsOneWidget);

    expect(find.text('₹50.00 / કિલો'), findsOneWidget);
    expect(find.text('₹150.00 / લીટર'), findsOneWidget);
    expect(find.text('₹10.00 / પેકેટ'), findsOneWidget);

    // Now expand the first item (ખાંડ પ્રીમિયમ - કિલો)
    await tester.tap(find.text('ખાંડ પ્રીમિયમ'));
    await tester.pumpAndSettle();

    // Verify inline panel shows appropriate unit labels for weight
    expect(find.text('પરત આપેલ વજન'), findsOneWidget);
    expect(find.text('કિલો / ગ્રામ'), findsOneWidget);

    // Enter 500 grams in the return text field
    final inputFinder = find.byType(TextField).last;
    await tester.enterText(inputFinder, '500');
    await tester.pumpAndSettle();

    // Verify live calculation parsed 500 grams into 0.5 kg: 0.5 * 50 = ₹25 refund
    expect(find.text('પરત: 500 ગ્રામ'), findsOneWidget);
    expect(find.text('રિફંડ: ₹25.00'), findsOneWidget);

    // Save this row return
    await tester.tap(find.text('સાચવો'));
    await tester.pumpAndSettle();

    // Verify the return badge is updated with correspondence unit
    expect(find.text('પરત: 500 ગ્રામ'), findsOneWidget);

    // Expand the third item (પારલે-જી બિસ્કિટ - પેકેટ)
    await tester.tap(find.text('પારલે-જી બિસ્કિટ'));
    await tester.pumpAndSettle();

    // Verify discrete unit label
    expect(find.text('પરત આપેલ માત્રા (પેકેટ)'), findsOneWidget);
  });

  testWidgets('ReturnReplaceScreen mobile Replace Mode renders without RenderFlex overflow', (tester) async {
    // Typical Android phone dimensions
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final testBill = Bill(
      id: 1,
      billNumber: 'BILL-002',
      customerId: 1,
      customerNameSnapshot: 'સુરેશભાઈ',
      billDate: '2026-10-09',
      subtotal: 200.0,
      discount: 0.0,
      gstAmount: 0.0,
      totalAmount: 200.0,
      paidAmount: 200.0,
      paymentMode: 'cash',
      paymentStatus: 'paid',
      isPrinted: false,
      isReturned: false,
      createdAt: '2026-10-09T10:00:00',
    );

    final testItems = [
      const BillItem(
        id: 10,
        billId: 1,
        productId: 101,
        productNameSnapshot: 'બાજરી લોટ',
        unitTypeSnapshot: 'કિલો',
        sellPriceSnapshot: 40.0,
        qty: 5.0,
        amount: 200.0,
        isReturned: false,
      ),
    ];

    when(() => mockRepo.getBillHistory(
          query: any(named: 'query'),
          paymentStatus: any(named: 'paymentStatus'),
          from: any(named: 'from'),
          to: any(named: 'to'),
        )).thenAnswer((_) async => [testBill]);

    when(() => mockRepo.getBillItems(1)).thenAnswer((_) async => testItems);
    when(() => mockRepo.getProducts(query: any(named: 'query'))).thenAnswer((_) async => []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          returnRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: ReturnReplaceScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Select bill
    await tester.tap(find.textContaining('BILL-002'));
    await tester.pumpAndSettle();

    // Switch to Replace Mode (બદલો)
    final replaceModeBtn = find.textContaining('બદલો');
    expect(replaceModeBtn, findsOneWidget);
    await tester.tap(replaceModeBtn);
    await tester.pumpAndSettle();

    // Verify Express 1-Screen Replace UI: Search bar, live items, add button, bottom bar
    expect(find.text('બદલી માટે ઉત્પાદન શોધો...'), findsOneWidget);
    expect(find.text('બાજરી લોટ'), findsOneWidget);
    expect(find.text('+ નવી વસ્તુ ઉમેરો'), findsOneWidget);

    // Verify sticky bottom difference bar and action button appear
    expect(find.textContaining('તફાવત'), findsOneWidget);
    expect(find.text('બદલી સાચવો'), findsOneWidget);

    // Verify Stepper buttons are available for quick inline adjustment
    expect(find.byIcon(Icons.remove), findsWidgets);
    expect(find.byIcon(Icons.add), findsWidgets);
  });

  testWidgets('ReturnReplaceScreen directly opens given initialBill without requiring bill list selection', (tester) async {
    final mockRepo = MockReturnRepository();

    final testBill = Bill(
      id: 99,
      billNumber: 'BILL-099',
      subtotal: 350.0,
      discount: 0.0,
      gstAmount: 0.0,
      totalAmount: 350.0,
      paidAmount: 350.0,
      paymentMode: 'cash',
      paymentStatus: 'paid',
      billDate: '2026-10-15',
      createdAt: '2026-10-15 10:00:00',
      customerNameSnapshot: 'ભાવેશભાઈ',
      isPrinted: false,
      isReturned: false,
    );

    final testItems = [
      const BillItem(
        id: 101,
        billId: 99,
        productId: 50,
        productNameSnapshot: 'તુવેર દાળ દેશી',
        unitTypeSnapshot: 'કિલો',
        sellPriceSnapshot: 175.0,
        qty: 2.0,
        amount: 350.0,
        isReturned: false,
      ),
    ];

    when(() => mockRepo.getBillItems(99)).thenAnswer((_) async => testItems);
    when(() => mockRepo.getProducts(query: any(named: 'query'))).thenAnswer((_) async => []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          returnRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: MaterialApp(
          home: ReturnReplaceScreen(initialBill: testBill),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify bill header shows directly with bill number
    expect(find.text('બિલ નં: BILL-099'), findsOneWidget);

    // Verify item from the bill is directly visible
    expect(find.text('તુવેર દાળ દેશી'), findsOneWidget);

    // Verify Return mode is active by default
    expect(find.text('↩️ રિટર્ન'), findsOneWidget);

    // Verify 'બિલ યાદી' option is available
    expect(find.text('બિલ યાદી'), findsOneWidget);
  });
}

