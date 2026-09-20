import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/bill_service.dart';
import '../providers.dart';

/// Bill service provider
final billServiceProvider = Provider<BillService>((ref) {
  return BillService(ref.watch(databaseHelperProvider));
});

/// Today's bills provider
final todaysBillsProvider = FutureProvider<List<dynamic>>((ref) async {
  final billService = ref.watch(billServiceProvider);
  return billService.getTodaysBills();
});

/// Today's sales summary provider
final todaysSalesSummaryProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final billService = ref.watch(billServiceProvider);
  return billService.getTodaysSalesSummary();
});

/// Bill details provider (cached)
final billDetailsProvider = FutureProvider.family<dynamic, int>((
  ref,
  billId,
) async {
  final billService = ref.watch(billServiceProvider);
  return billService.getBillWithItems(billId);
});
