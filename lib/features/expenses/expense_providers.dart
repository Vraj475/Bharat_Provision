import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_handler.dart';
import '../../data/providers.dart';
import '../../shared/models/expense_account_model.dart';

export '../../data/providers.dart' show expenseRepositoryProvider;

/// Provider that returns ALL accounts (active & inactive) directly from SQLite database
final allExpenseAccountsProvider =
    FutureProvider<List<ExpenseAccount>>((ref) async {
  try {
    final repo = ref.watch(expenseRepositoryProvider);
    return await repo.getExpenseAccounts(activeOnly: false);
  } catch (e, st) {
    throw ErrorHandler.handle(
      e,
      st,
      context: 'ExpenseProviders.allExpenseAccountsProvider',
    );
  }
});

/// Provider that returns ONLY ACTIVE accounts for dropdown selections
final activeExpenseAccountsProvider =
    FutureProvider<List<ExpenseAccount>>((ref) async {
  try {
    final repo = ref.watch(expenseRepositoryProvider);
    return await repo.getExpenseAccounts(activeOnly: true);
  } catch (e, st) {
    throw ErrorHandler.handle(
      e,
      st,
      context: 'ExpenseProviders.activeExpenseAccountsProvider',
    );
  }
});

/// Alias for active accounts to support backward compatibility
final expenseAccountsProvider = activeExpenseAccountsProvider;
