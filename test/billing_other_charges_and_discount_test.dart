import 'package:flutter_test/flutter_test.dart';
import 'package:bharat_provision/features/billing/controllers/billing_controller.dart';
import 'package:bharat_provision/features/billing/models/bill_line_item.dart';
import 'package:bharat_provision/shared/models/product_model.dart';
import 'package:bharat_provision/shared/models/bill_model.dart';

void main() {
  group('BillingController Other Charges and Discount tests', () {
    late BillingController controller;

    setUp(() {
      controller = BillingController();
      // Add a line item of 100 Rs
      final product = Product(
        id: 1,
        barcode: '12345',
        nameGujarati: 'ખાંડ',
        nameEnglish: 'Sugar',
        transliterationKeys: 'khand sugar',
        unitType: 'kg',
        buyPrice: 40.0,
        sellPrice: 50.0,
        stockQty: 10.0,
        minStockQty: 2.0,
        isActive: true,
      );
      controller.addLine(
        BillLineItem(
          draftKey: 'draft_1',
          item: product,
          qtyGrams: 2000.0, // 2kg
          amount: 100.0,
        ),
      );
    });

    test('Initial subtotal and total are 100 with 0 discount and 0 other charges', () {
      final state = controller.debugState;
      expect(state.subtotal, 100.0);
      expect(state.discount, 0.0);
      expect(state.otherCharges, 0.0);
      expect(state.legitTotal, 100.0);
      expect(state.total, 100.0);
    });

    test('Adding more than 5 rupees above legit total adds excess as other charges', () {
      // Legit total is 100. User enters 115 (+15 rs > 5 rs)
      controller.commitGrandTotalEdit(115.0);

      final state = controller.debugState;
      expect(state.otherCharges, 15.0);
      expect(state.discount, 0.0);
      expect(state.total, 115.0);
      expect(state.isGrandTotalAdjusted, isTrue);
    });

    test('Adding 5 or fewer rupees above legit total does not add other charges', () {
      // Legit total is 100. User enters 104 (+4 rs <= 5 rs)
      controller.commitGrandTotalEdit(104.0);

      final state = controller.debugState;
      expect(state.otherCharges, 0.0);
      expect(state.discount, 0.0);
      expect(state.total, 100.0);
    });

    test('Adding exactly 5 rupees above legit total does not add other charges', () {
      // Legit total is 100. User enters 105 (+5 rs, not > 5 rs)
      controller.commitGrandTotalEdit(105.0);

      final state = controller.debugState;
      expect(state.otherCharges, 0.0);
      expect(state.discount, 0.0);
      expect(state.total, 100.0);
    });

    test('Reducing total below legit total adds the difference as discount', () {
      // Legit total is 100. User enters 90 (-10 rs)
      controller.commitGrandTotalEdit(90.0);

      final state = controller.debugState;
      expect(state.otherCharges, 0.0);
      expect(state.discount, 10.0);
      expect(state.legitTotal, 90.0);
      expect(state.total, 90.0);
      expect(state.isGrandTotalAdjusted, isTrue);
    });

    test('Editing grand total with existing discount respects legit total (subtotal - discount)', () {
      // Set discount of 20 -> legit total is 80
      controller.setDiscount(20.0);
      expect(controller.debugState.legitTotal, 80.0);

      // User enters 100 -> diff above legit total is 100 - 80 = 20 (> 5)
      controller.commitGrandTotalEdit(100.0);

      final state = controller.debugState;
      expect(state.discount, 20.0);
      expect(state.otherCharges, 20.0);
      expect(state.total, 100.0);
    });

    test('Clearing bill resets other charges, discount, and lines', () {
      controller.commitGrandTotalEdit(125.0);
      expect(controller.debugState.otherCharges, 25.0);

      controller.clearBill();
      final state = controller.debugState;
      expect(state.billLines, isEmpty);
      expect(state.discount, 0.0);
      expect(state.otherCharges, 0.0);
      expect(state.total, 0.0);
    });

    test('Bill model fromMap and toMap preserve other_charges', () {
      final bill = Bill(
        billNumber: '1001',
        billDate: '2026-10-13',
        subtotal: 100.0,
        discount: 10.0,
        gstAmount: 0.0,
        otherCharges: 25.0,
        totalAmount: 115.0,
        paidAmount: 115.0,
        isPrinted: false,
        isReturned: false,
        createdAt: '2026-10-13T10:00:00Z',
      );

      final map = bill.toMap();
      expect(map['other_charges'], 25.0);

      final reconstructed = Bill.fromMap(map);
      expect(reconstructed.otherCharges, 25.0);
      expect(reconstructed.totalAmount, 115.0);
    });
  });
}
