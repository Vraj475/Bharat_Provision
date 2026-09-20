import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/report_repository.dart';
import '../../shared/models/product_model.dart';

export '../../data/providers.dart' show reportRepositoryProvider;

final todaysSalesProvider = FutureProvider<double>((ref) async {
  final repo = ref.watch(reportRepositoryProvider);
  return repo.getTodaysSales();
});

final todaysExpensesProvider = FutureProvider<double>((ref) async {
  final repo = ref.watch(reportRepositoryProvider);
  return repo.getTodaysExpenses();
});

final lowStockProductsProvider = FutureProvider<List<Product>>((ref) async {
  final repo = ref.watch(reportRepositoryProvider);
  return repo.getLowStockProducts();
});

final sevenDaySalesProvider = FutureProvider<List<DailySales>>((ref) async {
  final repo = ref.watch(reportRepositoryProvider);
  return repo.get7DaySales();
});

final totalUdhaarOutstandingProvider = FutureProvider<double>((ref) async {
  final repo = ref.watch(reportRepositoryProvider);
  return repo.getTotalUdhaarOutstanding();
});

final todaysNetProfitProvider = FutureProvider<double>((ref) async {
  final repo = ref.watch(reportRepositoryProvider);
  return repo.getTodaysNetProfit();
});

final todaysBillCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(reportRepositoryProvider);
  return repo.getTodaysBillCount();
});
