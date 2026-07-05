import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/expense_repository.dart';

final expenseRepositoryProvider = FutureProvider<ExpenseRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return ExpenseRepository(db);
});