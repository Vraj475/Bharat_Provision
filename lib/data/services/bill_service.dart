import '../../core/database/database_helper.dart';
import '../../shared/models/bill_model.dart';
import '../../shared/models/bill_item_model.dart';
import '../../core/errors/error_handler.dart';

class BillService {
  final DatabaseHelper _dbHelper;

  BillService([DatabaseHelper? dbHelper])
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Save a bill with customer, items, and stock updates in a single transaction
  /// Returns: bill ID on success, throws BillException on failure
  /// Save a bill with customer, items, and stock updates in a single transaction
  /// DEPRECATED: Use [BillRepository.createBill] instead. This method is disabled to prevent
  /// schema mismatch errors and corrupting transaction balance records.
  Future<int> saveBill({
    required int? customerId,
    required String? customerName,
    required List<BillItem> items,
    required double discountAmount,
    required double paidAmount,
    required String paymentMode,
    required int userId,
    bool isPrintEnabled = true,
  }) async {
    throw UnsupportedError(
      'BillService.saveBill is deprecated and unsafe. Use BillRepository.createBill instead.',
    );
  }

  /// Get a bill by ID with all its items
  Future<BillWithItems?> getBillWithItems(int billId) async {
    try {
      final db = await _dbHelper.database;
      final billMaps = await db.query(
        'bills',
        where: 'id = ?',
        whereArgs: [billId],
      );

      if (billMaps.isEmpty) return null;

      final itemMaps = await db.query(
        'bill_items',
        where: 'bill_id = ?',
        whereArgs: [billId],
      );

      final normalizedBill = Map<String, dynamic>.from(billMaps.first);

      return BillWithItems(
        bill: Bill.fromMap(normalizedBill),
        items: itemMaps.map((item) {
          final normalized = Map<String, dynamic>.from(item);
          return BillItem.fromMap(normalized);
        }).toList(),
      );
    } catch (e, st) {
      throw ErrorHandler.handle(e, st, context: 'BillService.getBillWithItems');
    }
  }

  /// Mark a bill as printed
  Future<void> markPrinted(int billId) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'bills',
        {'is_printed': 1},
        where: 'id = ?',
        whereArgs: [billId],
      );
    } catch (e, st) {
      throw ErrorHandler.handle(e, st, context: 'BillService.markPrinted');
    }
  }

  /// Reprint a bill (deprecated alias for [markPrinted])
  Future<void> reprintBill(int billId) async => markPrinted(billId);

  /// Update payment status (e.g. paid, udhaar, partial)
  Future<void> updatePaymentStatus(int billId, String paymentStatus) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'bills',
        {'payment_status': paymentStatus},
        where: 'id = ?',
        whereArgs: [billId],
      );
    } catch (e, st) {
      throw ErrorHandler.handle(e, st, context: 'BillService.updatePaymentStatus');
    }
  }

  /// Update bill status (deprecated alias for [updatePaymentStatus])
  Future<void> updateBillStatus(int billId, String status) async => updatePaymentStatus(billId, status);

  /// Get all bills for today
  Future<List<Bill>> getTodaysBills() async {
    try {
      final db = await _dbHelper.database;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final maps = await db.query(
        'bills',
        where: 'bill_date = ? OR created_at LIKE ?',
        whereArgs: [todayStr, '$todayStr%'],
        orderBy: 'id DESC',
      );

      return maps.map((map) => Bill.fromMap(map)).toList();
    } catch (e, st) {
      throw ErrorHandler.handle(e, st, context: 'BillService.getTodaysBills');
    }
  }

  /// Calculate today's sales summary
  Future<Map<String, dynamic>> getTodaysSalesSummary() async {
    try {
      final db = await _dbHelper.database;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final result = await db.rawQuery(
        '''
        SELECT 
          COUNT(*) as bill_count,
          SUM(total_amount) as total_sales,
          SUM(CASE WHEN payment_mode = 'udhaar' THEN total_amount ELSE 0 END) as udhaar_amount,
          SUM(CASE WHEN payment_mode = 'cash' THEN total_amount ELSE 0 END) as cash_amount,
          SUM(CASE WHEN payment_mode = 'upi' THEN total_amount ELSE 0 END) as upi_amount
        FROM bills
        WHERE bill_date = ? OR created_at LIKE ?
        ''',
        [todayStr, '$todayStr%'],
      );

      if (result.isEmpty || result[0]['bill_count'] == null) {
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
        'total_sales': (result[0]['total_sales'] as num?)?.toDouble() ?? 0.0,
        'udhaar_amount': (result[0]['udhaar_amount'] as num?)?.toDouble() ?? 0.0,
        'cash_amount': (result[0]['cash_amount'] as num?)?.toDouble() ?? 0.0,
        'upi_amount': (result[0]['upi_amount'] as num?)?.toDouble() ?? 0.0,
      };
    } catch (e, st) {
      throw ErrorHandler.handle(e, st, context: 'BillService.getTodaysSalesSummary');
    }
  }
}

/// Combined bill with items
class BillWithItems {
  final Bill bill;
  final List<BillItem> items;

  BillWithItems({required this.bill, required this.items});

  double get subtotal => items.fold(0, (sum, item) => sum + item.amount);
  double get total => bill.totalAmount > 0 ? bill.totalAmount : (subtotal - bill.discount);
}
