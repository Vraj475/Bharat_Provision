import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bharat_provision/core/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await NotificationService.instance.clearAllAlertStatuses();
  });

  group('Low Stock Notification Deduplication Tests', () {
    test('Notification triggers only once per low stock drop', () async {
      // First low stock alert for product 1
      final alertedFirst = await NotificationService.instance.showLowStockAlert(
        productId: 1,
        productName: 'ખાંડ',
        qty: 5.0,
      );
      expect(alertedFirst, isTrue);

      // Repeated bill sale for the same product while still low stock
      final alertedSecond = await NotificationService.instance.showLowStockAlert(
        productId: 1,
        productName: 'ખાંડ',
        qty: 4.0,
      );
      expect(
        alertedSecond,
        isFalse,
        reason:
            'Should not spam notification for already notified low-stock product',
      );

      final alertedThird = await NotificationService.instance.showLowStockAlert(
        productId: 1,
        productName: 'ખાંડ',
        qty: 3.0,
      );
      expect(alertedThird, isFalse);

      // Different product should still alert once
      final alertedOther = await NotificationService.instance.showLowStockAlert(
        productId: 2,
        productName: 'ચોખા',
        qty: 2.0,
      );
      expect(alertedOther, isTrue);
    });

    test(
      'Notification resets after product is restocked above minimum stock',
      () async {
        // First low-stock event
        await NotificationService.instance.showLowStockAlert(
          productId: 10,
          productName: 'ચા',
          qty: 3.0,
        );
        expect(
          await NotificationService.instance.isLowStockNotified(10),
          isTrue,
        );

        // Product restocked, but still below minimum stock (e.g. min is 10, stock is 7)
        await NotificationService.instance.onProductRestocked(
          productId: 10,
          newStockQty: 7.0,
          minStockQty: 10.0,
        );
        // Status remains notified because it did not cross above min stock
        expect(
          await NotificationService.instance.isLowStockNotified(10),
          isTrue,
        );

        // Product restocked strictly above minimum stock (stock is now 25)
        await NotificationService.instance.onProductRestocked(
          productId: 10,
          newStockQty: 25.0,
          minStockQty: 10.0,
        );
        expect(
          await NotificationService.instance.isLowStockNotified(10),
          isFalse,
        );

        // Now when stock drops below min stock again later, it triggers notification once again
        final reAlert = await NotificationService.instance.showLowStockAlert(
          productId: 10,
          productName: 'ચા',
          qty: 9.0,
        );
        expect(
          reAlert,
          isTrue,
          reason: 'Should alert again once restocked and then dropped low',
        );

        // But subsequent sales are skipped again
        final reAlertRepeat = await NotificationService.instance
            .showLowStockAlert(productId: 10, productName: 'ચા', qty: 8.0);
        expect(reAlertRepeat, isFalse);
      },
    );

    test(
      'Out of stock alert triggers once and resets when restocked > 0',
      () async {
        // Out of stock alert
        final firstOut = await NotificationService.instance
            .showOutOfStockAlert(productId: 20, productName: 'તેલ');
        expect(firstOut, isTrue);

        // Repeated out of stock alert skipped
        final repeatOut = await NotificationService.instance
            .showOutOfStockAlert(productId: 20, productName: 'તેલ');
        expect(repeatOut, isFalse);

        // Restock item to positive qty
        await NotificationService.instance.onProductRestocked(
          productId: 20,
          newStockQty: 5.0,
          minStockQty: 10.0,
        );
        expect(
          await NotificationService.instance.isOutOfStockNotified(20),
          isFalse,
        );

        // Can alert again when hitting 0
        final reAlertOut = await NotificationService.instance
            .showOutOfStockAlert(productId: 20, productName: 'તેલ');
        expect(reAlertOut, isTrue);
      },
    );

    test('Persists notified IDs across instance reloads', () async {
      await NotificationService.instance.showLowStockAlert(
        productId: 99,
        productName: 'ઘઉં',
        qty: 2.0,
      );

      final prefs = await SharedPreferences.getInstance();
      final savedIds = prefs.getStringList('notified_low_stock_product_ids');
      expect(savedIds, contains('99'));
    });
  });
}
