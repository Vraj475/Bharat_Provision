import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/report_repository.dart';
import '../../shared/models/product_model.dart';

final reportRepositoryProvider = FutureProvider<ReportRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return ReportRepository(db);
});

final todaysSalesProvider = FutureProvider<double>((ref) async {
  final repo = await ref.watch(reportRepositoryProvider.future);
  return repo.getTodaysSales();
});

final todaysExpensesProvider = FutureProvider<double>((ref) async {
  final repo = await ref.watch(reportRepositoryProvider.future);
  return repo.getTodaysExpenses();
});

final lowStockProductsProvider = FutureProvider<List<Product>>((ref) async {
  final repo = await ref.watch(reportRepositoryProvider.future);
  return repo.getLowStockProducts();
});

final sevenDaySalesProvider = FutureProvider<List<DailySales>>((ref) async {
  final repo = await ref.watch(reportRepositoryProvider.future);
  return repo.get7DaySales();
});

final totalUdhaarOutstandingProvider = FutureProvider<double>((ref) async {
  final repo = await ref.watch(reportRepositoryProvider.future);
  return repo.getTotalUdhaarOutstanding();
});

final todaysNetProfitProvider = FutureProvider<double>((ref) async {
  final repo = await ref.watch(reportRepositoryProvider.future);
  return repo.getTodaysNetProfit();
});

final todaysBillCountProvider = FutureProvider<int>((ref) async {
  final repo = await ref.watch(reportRepositoryProvider.future);
  return repo.getTodaysBillCount();
});
