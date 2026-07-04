import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/report_repository.dart';

final reportDateRangeProvider = StateProvider<DateTimeRange>((ref) {
  final now = DateTime.now();
  return DateTimeRange(start: DateTime(now.year, now.month, now.day), end: now);
});

final salesReportProvider = FutureProvider<SalesSummary>((ref) async {
  final repo = await ref.watch(reportRepositoryFutureProvider.future);
  final range = ref.watch(reportDateRangeProvider);
  final start = range.start.millisecondsSinceEpoch;
  final end = range.end.add(const Duration(days: 1)).millisecondsSinceEpoch;
  return repo.getSalesSummary(start, end);
});

final outstandingKhataProvider = FutureProvider<List<OutstandingCustomer>>((
  ref,
) async {
  final repo = await ref.watch(reportRepositoryFutureProvider.future);
  return repo.getOutstandingKhata();
});
