import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:bharat_provision/shared/models/bill_model.dart';
import 'package:bharat_provision/core/utils/currency_format.dart';

bool isBillFromToday(Bill bill, [DateTime? referenceNow]) {
  final now = referenceNow ?? DateTime.now();
  final todayDateOnly = DateTime(now.year, now.month, now.day);

  bool isSameCalendarDay(DateTime dt) {
    final local = dt.toLocal();
    return local.year == todayDateOnly.year &&
        local.month == todayDateOnly.month &&
        local.day == todayDateOnly.day;
  }

  final todayIsoPrefix = DateFormat('yyyy-MM-dd').format(now);
  final rawDate = bill.billDate.trim();
  if (rawDate.isNotEmpty) {
    if (rawDate.startsWith(todayIsoPrefix)) {
      return true;
    }
    final parsed = DateTime.tryParse(rawDate);
    if (parsed != null) {
      return isSameCalendarDay(parsed);
    }
    final epochMs = int.tryParse(rawDate);
    if (epochMs != null && epochMs > 100000000000) {
      final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
      return isSameCalendarDay(dt);
    }
  }

  final rawCreated = bill.createdAt.trim();
  if (rawCreated.isNotEmpty) {
    if (rawCreated.startsWith(todayIsoPrefix)) {
      return true;
    }
    final parsedCreated = DateTime.tryParse(rawCreated);
    if (parsedCreated != null) {
      return isSameCalendarDay(parsedCreated);
    }
  }

  return false;
}

void main() {
  group('Bill History 1-day Total Amount Tests', () {
    final testDate = DateTime(2026, 10, 14, 11, 30);
    final todayStr = DateFormat('yyyy-MM-dd').format(testDate);
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(testDate.subtract(const Duration(days: 1)));

    final billYesterday1 = Bill(
      id: 1,
      billNumber: 'BILL-001',
      billDate: yesterdayStr,
      subtotal: 500.0,
      discount: 0.0,
      gstAmount: 0.0,
      totalAmount: 500.0,
      paidAmount: 500.0,
      isPrinted: true,
      isReturned: false,
      createdAt: '${yesterdayStr}T10:00:00.000',
    );

    final billYesterday2 = Bill(
      id: 2,
      billNumber: 'BILL-002',
      billDate: yesterdayStr,
      subtotal: 300.0,
      discount: 0.0,
      gstAmount: 0.0,
      totalAmount: 300.0,
      paidAmount: 300.0,
      isPrinted: true,
      isReturned: false,
      createdAt: '${yesterdayStr}T15:30:00.000',
    );

    final billToday1 = Bill(
      id: 3,
      billNumber: 'BILL-003',
      billDate: todayStr,
      subtotal: 450.0,
      discount: 0.0,
      gstAmount: 0.0,
      totalAmount: 450.0,
      paidAmount: 450.0,
      isPrinted: true,
      isReturned: false,
      createdAt: '${todayStr}T09:15:00.000',
    );

    final billToday2 = Bill(
      id: 4,
      billNumber: 'BILL-004',
      billDate: todayStr,
      subtotal: 250.0,
      discount: 0.0,
      gstAmount: 0.0,
      totalAmount: 250.0,
      paidAmount: 250.0,
      isPrinted: true,
      isReturned: false,
      createdAt: '${todayStr}T14:45:00.000',
    );

    test('When day changes and no bills created today, total amount is zero (₹0.00)', () {
      final bills = [billYesterday1, billYesterday2];

      final todayBills = bills.where((b) => isBillFromToday(b, testDate)).toList();
      final todayTotal = todayBills.fold<double>(0, (sum, b) => sum + b.totalAmount);

      expect(todayBills, isEmpty);
      expect(todayTotal, 0.0);
      expect(formatCurrency(todayTotal), contains('0.00'));
    });

    test('When bills are created today, total amount sums 1-day bills only', () {
      final bills = [billToday2, billToday1, billYesterday2, billYesterday1];

      final todayBills = bills.where((b) => isBillFromToday(b, testDate)).toList();
      final todayTotal = todayBills.fold<double>(0, (sum, b) => sum + b.totalAmount);

      expect(todayBills.length, 2);
      expect(todayTotal, 700.0); // 450 + 250
      expect(formatCurrency(todayTotal), contains('700.00'));

      // Lifetime total would have been 1500, but 1-day total is 700
      final lifetimeTotal = bills.fold<double>(0, (sum, b) => sum + b.totalAmount);
      expect(lifetimeTotal, 1500.0);
    });

    test('When day changes to tomorrow, previous day bills no longer count towards today', () {
      final tomorrowDate = testDate.add(const Duration(days: 1));
      final bills = [billToday2, billToday1, billYesterday2, billYesterday1];

      final tomorrowBills = bills.where((b) => isBillFromToday(b, tomorrowDate)).toList();
      final tomorrowTotal = tomorrowBills.fold<double>(0, (sum, b) => sum + b.totalAmount);

      expect(tomorrowBills, isEmpty);
      expect(tomorrowTotal, 0.0);
      expect(formatCurrency(tomorrowTotal), contains('0.00'));
    });

    test('Bill date in ISO format or timestamp correctly identified', () {
      final isoBill = Bill(
        id: 5,
        billNumber: 'BILL-005',
        billDate: '${todayStr}T18:20:00.123',
        subtotal: 120.0,
        discount: 0.0,
        gstAmount: 0.0,
        totalAmount: 120.0,
        paidAmount: 120.0,
        isPrinted: true,
        isReturned: false,
        createdAt: '${todayStr}T18:20:00.123',
      );

      expect(isBillFromToday(isoBill, testDate), isTrue);
      expect(isBillFromToday(isoBill, testDate.add(const Duration(days: 1))), isFalse);
    });
  });
}
