import 'package:sqflite_sqlcipher/sqflite.dart' hide DatabaseException;
import '../models/incomplete_transaction.dart';
import '../../core/utils/error_handler.dart';

class TransactionRecoveryService {
  final Database _db;

  TransactionRecoveryService(this._db);

  /// Log an incomplete transaction for recovery
  Future<int> logIncompleteTransaction({
    required String transactionType,
    required Map<String, dynamic> data,
  }) async {
    try {
      return await _db.insert('incomplete_transactions', {
        'transaction_type': transactionType,
        'data': _serializeData(data),
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'recovered': 0,
      });
    } catch (e) {
      throw DatabaseException(
        message: 'અધૂરી ક્રિયા લૉગ કરી શકાયું નથી',
        originalError: e,
      );
    }
  }

  /// Get all incomplete transactions
  Future<List<IncompleteTransaction>> getIncompleteTransactions() async {
    try {
      final maps = await _db.query(
        'incomplete_transactions',
        where: 'recovered = 0',
        orderBy: 'created_at DESC',
      );

      return maps.map((map) {
        map['data'] = _deserializeData(map['data'] as String);
        return IncompleteTransaction.fromMap(map);
      }).toList();
    } catch (e) {
      throw DatabaseException(
        message: 'અધૂરી ક્રિયાઓ મેળવી શકાયું નથી',
        originalError: e,
      );
    }
  }

  /// Attempt to recover all incomplete transactions
  Future<RecoveryResult> attemptRecovery() async {
    try {
      final transactions = await getIncompleteTransactions();

      if (transactions.isEmpty) {
        return RecoveryResult(
          success: true,
          recoveredTransactions: [],
          failedTransactions: [],
        );
      }

      final recovered = <String>[];
      final failed = <String>[];

      for (final txn in transactions) {
        try {
          await _recoverTransaction(txn);
          recovered.add(txn.description);

          // Mark as recovered
          await _db.update(
            'incomplete_transactions',
            {
              'recovered': 1,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [txn.id],
          );
        } catch (e) {
          failed.add('${txn.description}: $e');
        }
      }

      return RecoveryResult(
        success: failed.isEmpty,
        recoveredTransactions: recovered,
        failedTransactions: failed,
      );
    } catch (e) {
      return RecoveryResult(success: false, errorMessage: e.toString());
    }
  }

  /// Mark transaction as recovered
  Future<void> markAsRecovered(int transactionId) async {
    try {
      await _db.update(
        'incomplete_transactions',
        {'recovered': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [transactionId],
      );
    } catch (e) {
      throw DatabaseException(
        message: 'ક્રિયાને પુનઃપ્રાપ્ત તરીકે ચિહ્નિત કરી શકાયું નથી',
        originalError: e,
      );
    }
  }

  /// Delete a recovered transaction
  Future<void> deleteRecoveredTransaction(int transactionId) async {
    try {
      await _db.delete(
        'incomplete_transactions',
        where: 'id = ? AND recovered = 1',
        whereArgs: [transactionId],
      );
    } catch (e) {
      throw DatabaseException(
        message: 'પુનઃપ્રાપ્ત ક્રિયા કાઢી શકાયું નથી',
        originalError: e,
      );
    }
  }

  /// Internal: Recover a single transaction
  Future<void> _recoverTransaction(IncompleteTransaction transaction) async {
    switch (transaction.transactionType) {
      case 'bill_save':
        await _recoverBillSave(transaction.data);
        break;
      case 'stock_purchase':
        await _recoverStockPurchase(transaction.data);
        break;
      case 'return':
        await _recoverReturn(transaction.data);
        break;
      case 'expense':
        await _recoverExpense(transaction.data);
        break;
      default:
        throw Exception(
          'Unknown transaction type: ${transaction.transactionType}',
        );
    }
  }

  Future<void> _recoverBillSave(Map<String, dynamic> data) async {
    // If bill was not created, create it now
    final billId = data['billId'] as int?;
    if (billId == null) {
      // Re-create the bill with the stored data
      await _db.insert('bills', {
        ...data,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  Future<void> _recoverStockPurchase(Map<String, dynamic> data) async {
    // Similar recovery logic
  }

  Future<void> _recoverReturn(Map<String, dynamic> data) async {
    // Similar recovery logic
  }

  Future<void> _recoverExpense(Map<String, dynamic> data) async {
    // Similar recovery logic
  }

  String _serializeData(Map<String, dynamic> data) {
    // In a real app, use JSON serialization
    return data.toString();
  }

  Map<String, dynamic> _deserializeData(String serialized) {
    // In a real app, use JSON deserialization
    return {};
  }
}
