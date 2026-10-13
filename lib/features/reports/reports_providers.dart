import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/report_repository.dart';

final reportDateRangeProvider = StateProvider<DateTimeRange>((ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
  return DateTimeRange(start: start, end: end);
});

final salesReportProvider = FutureProvider<SalesSummary>((ref) async {
  final repo = ref.watch(reportRepositoryProvider);
  final range = ref.watch(reportDateRangeProvider);
  final start = range.start.millisecondsSinceEpoch;
  final end = range.end.millisecondsSinceEpoch;
  return repo.getSalesSummary(start, end);
});

final outstandingKhataProvider = FutureProvider<List<OutstandingCustomer>>((
  ref,
) async {
  final repo = ref.watch(reportRepositoryProvider);
  return repo.getOutstandingKhata();
});

final dailyReportProvider = FutureProvider.family<DailyReportData, DateTime>((ref, date) async {
  final repo = ref.watch(reportRepositoryProvider);
  return repo.getDailyReport(date);
});

class PLReportQueryParams {
  final int startEpoch;
  final int endEpoch;

  const PLReportQueryParams({required this.startEpoch, required this.endEpoch});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PLReportQueryParams &&
          runtimeType == other.runtimeType &&
          startEpoch == other.startEpoch &&
          endEpoch == other.endEpoch;

  @override
  int get hashCode => startEpoch.hashCode ^ endEpoch.hashCode;
}

final plSummaryProvider = FutureProvider.family<PLSummary, PLReportQueryParams>((ref, params) async {
  final repo = ref.watch(reportRepositoryProvider);
  return repo.getPLSummary(params.startEpoch, params.endEpoch);
});

final dailyPLChartProvider = FutureProvider.family<List<DailyPL>, PLReportQueryParams>((ref, params) async {
  final repo = ref.watch(reportRepositoryProvider);
  return repo.getDailyPL(params.startEpoch, params.endEpoch);
});
