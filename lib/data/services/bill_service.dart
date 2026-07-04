import 'package:sqflite_sqlcipher/sqflite.dart' hide DatabaseException;
import '../models/bill.dart';
import '../models/bill_item.dart';
import '../models/bill_item_input.dart';
import '../../core/database/transaction_helper.dart';
import '../../core/errors/error_handler.dart';

class BillService {
  final Database _db;
  late final TransactionHelper _transactionHelper;

  BillService(this._db) {
    _transactionHelper = TransactionHelper(_db);
  }

  /// Save a bill with customer, items, and stock updates in a single transaction
  /// Returns: bill ID on success, throws BillException on failure
  Future<int> saveBill({
    required int? customerId,
    required String? customerName,
    required List<BillItemInput> items,
    required double discountAmount,
    required double paidAmount,
    required String paymentMode,
    required int userId,
    bool isPrintEnabled = true,
  }) async {
    try {
      if (items.isEmpty) {
        throw ErrorHandler.handle(
          ArgumentError('બીલમાં કમ- એક આઇટમ હોવી જોઈએ.'),
          StackTrace.current,
          context: 'BillService.saveBill',
        );
      }

      // Calculate totals
      double subtotal = 0;
      for (final item in items) {
        subtotal += item.quantity * item.unitPrice;
      }
      final totalAmount = subtotal - discountAmount;

      if (totalAmount < 0) {
        throw ErrorHandler.handle(
          ArgumentError('બીલ રકમ નકારાત્મક હોઈ શકતી નથી.'),
          StackTrace.current,
          context: 'BillService.saveBill',
        );
      }

      // Execute transaction
      return await _transactionHelper.executeTransaction((txn) async {
        final billNumber = await _getNextBillNumber(txn);
        final now = DateTime.now().millisecondsSinceEpoch;

        // 1. Insert bill
        final billId = await txn.insert('bills', {
          'bill_number': billNumber.toString(),
          'date_time': now,
          'customer_id': customerId,
          'customer_name': customerName, // Add for walk-in bills
          'subtotal': subtotal,
          'discount_amount': discountAmount,
          'tax_amount': 0,
          'total_amount': totalAmount,
          'paid_amount': paidAmount,
          'payment_mode': paymentMode,
          'status': 'completed',
          'created_by_user_id': userId,
          'is_print_enabled': isPrintEnabled ? 1 : 0,
        });

        // 2. Insert bill items
        for (final item in items) {
          final lineTotal = item.quantity * item.unitPrice;
          await txn.insert('bill_items', {
            'bill_id': billId,
            'item_id': item.itemId,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
            'line_total': lineTotal,
          });

          // 3. Update stock
          await txn.rawUpdate(
            'UPDATE items SET current_stock = current_stock - ? WHERE id = ?',
            [item.quantity, item.itemId],
          );
        }

        // 4. If payment mode is cash or udhaar, update payment tracking
        if (paymentMode == 'cash' || paymentMode == 'upi') {
          await txn.insert('payments', {
            'bill_id': billId,
            'amount': paidAmount,
            'payment_mode': paymentMode,
            'date_time': now,
          });
        }

        // 5. Increment bill counter
        await _incrementBillCounter(txn, billNumber);

        return billId;
      });
    } catch (e, st) {
      throw ErrorHandler.handle(e, st, context: 'BillService.saveBill');
    }
  }

  /// Get a bill by ID with all its items
  Future<BillWithItems?> getBillWithItems(int billId) async {
    try {
      final billMaps = await _db.query(
        'bills',
        where: 'id = ?',
        whereArgs: [billId],
      );

      if (billMaps.isEmpty) return null;

      final itemMaps = await _db.query(
        'bill_items',
        where: 'bill_id = ?',
        whereArgs: [billId],
      );

      return BillWithItems(
        bill: Bill.fromMap(billMaps.first),
        items: itemMaps.map((item) => BillItem.fromMap(item)).toList(),
      );
    } catch (e, st) {
      throw ErrorHandler.handle(e, st, context: 'BillService.getBillWithItems');
    }
  }

  /// Reprint a bill (creates no new bill in history)
  Future<void> reprintBill(int billId) async {
    try {
      final billData = await getBillWithItems(billId);
      if (billData == null) {
        throw ErrorHandler.handle(
          ArgumentError('બીલ મળ્યું નથી.'),
          StackTrace.current,
          context: 'BillService.reprintBill',
        );
      }

      // Just mark as reprinted, don't create duplicate
      await _db.update(
        'bills',
        {'last_reprintedAt': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [billId],
      );
    } catch (e, st) {
      throw ErrorHandler.handle(e, st, context: 'BillService.reprintBill');
    }
  }

  /// Update bill status (e.g., mark as partial_return)
  Future<void> updateBillStatus(int billId, String status) async {
    try {
      await _db.update(
        'bills',
        {'status': status},
        where: 'id = ?',
        whereArgs: [billId],
      );
    } catch (e, st) {
      throw ErrorHandler.handle(e, st, context: 'BillService.updateBillStatus');
    }
  }

  /// Get all bills for today
  Future<List<Bill>> getTodaysBills() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(
        today.year,
        today.month,
        today.day,
      ).millisecondsSinceEpoch;
      final endOfDay = startOfDay + (24 * 60 * 60 * 1000);

      final maps = await _db.query(
        'bills',
        where: 'date_time >= ? AND date_time < ?',
        whereArgs: [startOfDay, endOfDay],
        orderBy: 'date_time DESC',
      );

      return maps.map((map) => Bill.fromMap(map)).toList();
    } catch (e, st) {
      throw ErrorHandler.handle(e, st, context: 'BillService.getTodaysBills');
    }
  }

  /// Calculate today's sales summary
  Future<Map<String, dynamic>> getTodaysSalesSummary() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(
        today.year,
        today.month,
        today.day,
      ).millisecondsSinceEpoch;

      final result = await _db.rawQuery(
        '''
        SELECT 
          COUNT(*) as bill_count,
          SUM(total_amount) as total_sales,
          SUM(CASE WHEN payment_mode = 'udhaar' THEN total_amount ELSE 0 END) as udhaar_amount,
          SUM(CASE WHEN payment_mode = 'cash' THEN total_amount ELSE 0 END) as cash_amount,
          SUM(CASE WHEN payment_mode = 'upi' THEN total_amount ELSE 0 END) as upi_amount
        FROM bills
        WHERE date_time >= ?
        ''',
        [startOfDay],
      );

      if (result.isEmpty) {
        return {
          'bill_count': 0,
          'total_sales': 0.0,
          'udhaar_amount': 0.0,
          'cash_amount': 0.0,
          'upi_amount': 0.0,
        };
      }

      return {
        'bill_count': result[0]['bill_count'] ?? 0,
        'total_sales': result[0]['total_sales'] ?? 0.0,
        'udhaar_amount': result[0]['udhaar_amount'] ?? 0.0,
        'cash_amount': result[0]['cash_amount'] ?? 0.0,
        'upi_amount': result[0]['upi_amount'] ?? 0.0,
      };
    } catch (e, st) {
      throw ErrorHandler.handle(e, st, context: 'BillService.getTodaysSalesSummary');
    }
  }

  Future<int> _getNextBillNumber(Transaction txn) async {
    final counter = await txn.rawQuery(
      "SELECT value FROM settings WHERE key = 'bill_counter'",
    );
    return counter.isNotEmpty
        ? int.tryParse(counter.first['value'] as String? ?? '1') ?? 1
        : 1;
  }

  Future<void> _incrementBillCounter(Transaction txn, int currentNumber) async {
    await txn.update('settings', {
      'value': (currentNumber + 1).toString(),
    }, where: "key = 'bill_counter'");
  }
}

/// Combined bill with items
class BillWithItems {
  final Bill bill;
  final List<BillItem> items;

  BillWithItems({required this.bill, required this.items});

  double get subtotal => items.fold(0, (sum, item) => sum + item.lineTotal);
  double get total => subtotal - bill.discountAmount;
}
