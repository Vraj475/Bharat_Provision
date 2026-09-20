import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/bill_service.dart';
import '../providers.dart';

/// Bill service provider
final billServiceProvider = FutureProvider<BillService>((ref) async {
  final db = ref.watch(databaseProvider);
  return BillService(db);
});

/// Today's bills provider
final todaysBillsProvider = FutureProvider<List<dynamic>>((ref) async {
  final billService = await ref.watch(billServiceProvider.future);
  return billService.getTodaysBills();
});

/// Today's sales summary provider
final todaysSalesSummaryProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final billService = await ref.watch(billServiceProvider.future);
  return billService.getTodaysSalesSummary();
});

/// Bill details provider (cached)
final billDetailsProvider = FutureProvider.family<dynamic, int>((
  ref,
  billId,
) async {
  final billService = await ref.watch(billServiceProvider.future);
  return billService.getBillWithItems(billId);
});
