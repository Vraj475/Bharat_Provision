import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_helper.dart';
import '../../core/errors/error_handler.dart';
import '../../shared/models/expense_account_model.dart';
import '../../shared/models/product_model.dart';
import '../../shared/models/stock_log_model.dart';
import '../../data/repositories/stock_repository.dart';

// ─── Repository provider ──────────────────────────────────────────────────────

final stockRepositoryProvider = Provider<StockRepository>(
  (ref) => StockRepository(DatabaseHelper.instance),
);

// ─── Filter / search state ────────────────────────────────────────────────────

final stockSearchProvider = StateProvider<String>((ref) => '');
final stockStatusFilterProvider = StateProvider<StockStatusFilter>(
  (ref) => StockStatusFilter.all,
);
final stockCategoryFilterProvider = StateProvider<int?>((ref) => null);

enum StockStatusFilter { all, low, critical, outOfStock }

// ─── Dashboard data providers ─────────────────────────────────────────────────

final stockDashboardProductsProvider = FutureProvider<List<Product>>((
  ref,
) async {
  try {
    final repo = ref.watch(stockRepositoryProvider);
    final query = ref.watch(stockSearchProvider);
    return repo.getAllProducts(query: query.isEmpty ? null : query);
  } catch (e, st) {
    throw ErrorHandler.handle(
      e,
      st,
      context: 'StockProviders.stockDashboardProductsProvider',
    );
  }
});

final stockSummaryProvider = FutureProvider<StockSummary>((ref) async {
  try {
    // Re-runs when products list refreshes
    ref.watch(stockDashboardProductsProvider);
    final repo = ref.watch(stockRepositoryProvider);
    return repo.getSummary();
  } catch (e, st) {
    throw ErrorHandler.handle(
      e,
      st,
      context: 'StockProviders.stockSummaryProvider',
    );
  }
});

final stockCategoriesProvider = FutureProvider<List<StockCategory>>((
  ref,
) async {
  try {
    final repo = ref.watch(stockRepositoryProvider);
    final cats = await repo.getCategories();
    return cats
        .map((c) => StockCategory(id: c.id, name: c.nameGujarati))
        .toList();
  } catch (e, st) {
    throw ErrorHandler.handle(
      e,
      st,
      context: 'StockProviders.stockCategoriesProvider',
    );
  }
});

final expenseAccountsProvider = FutureProvider<List<ExpenseAccount>>((
  ref,
) async {
  try {
    final repo = ref.watch(stockRepositoryProvider);
    return repo.getExpenseAccounts();
  } catch (e, st) {
    throw ErrorHandler.handle(
      e,
      st,
      context: 'StockProviders.expenseAccountsProvider',
    );
  }
});

final stockHistoryProvider =
    FutureProvider.family<List<StockLogEntry>, HistoryParams>((
      ref,
      params,
    ) async {
      try {
        final repo = ref.watch(stockRepositoryProvider);
        return repo.getStockHistory(
          params.productId,
          transactionType: params.transactionType,
          fromDate: params.fromDate,
          toDate: params.toDate,
        );
      } catch (e, st) {
        throw ErrorHandler.handle(
          e,
          st,
          context: 'StockProviders.stockHistoryProvider',
        );
      }
    });

final productDetailProvider = FutureProvider.family<Product?, int>((
  ref,
  id,
) async {
  try {
    final repo = ref.watch(stockRepositoryProvider);
    return repo.getProductById(id);
  } catch (e, st) {
    throw ErrorHandler.handle(
      e,
      st,
      context: 'StockProviders.productDetailProvider',
    );
  }
});

// ─── Alert badge state (updated after each bill save) ─────────────────────────

final stockAlertCountProvider = StateProvider<int>((ref) => 0);

// ─── Helpers ─────────────────────────────────────────────────────────────────

class StockCategory {
  const StockCategory({required this.id, required this.name});
  final int id;
  final String name;
}

class HistoryParams {
  const HistoryParams({
    required this.productId,
    this.transactionType,
    this.fromDate,
    this.toDate,
  });
  final int productId;
  final String? transactionType;
  final DateTime? fromDate;
  final DateTime? toDate;

  @override
  bool operator ==(Object other) =>
      other is HistoryParams &&
      other.productId == productId &&
      other.transactionType == transactionType &&
      other.fromDate == fromDate &&
      other.toDate == toDate;

  @override
  int get hashCode =>
      productId.hashCode ^
      transactionType.hashCode ^
      fromDate.hashCode ^
      toDate.hashCode;
}
