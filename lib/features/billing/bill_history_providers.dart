import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/bill_model.dart';
import '../returns/returns_providers.dart';

class BillHistoryQueryParams {
  const BillHistoryQueryParams({
    this.query = '',
    this.from,
    this.to,
    this.limit,
  });

  final String query;
  final DateTime? from;
  final DateTime? to;
  final int? limit;

  @override
  bool operator ==(Object other) {
    return other is BillHistoryQueryParams &&
        other.query == query &&
        other.from == from &&
        other.to == to &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(query, from, to, limit);
}

class BillHistoryPreviewResult {
  const BillHistoryPreviewResult({required this.bills, required this.hasMore});

  final List<Bill> bills;
  final bool hasMore;
}

final billHistoryProvider =
    FutureProvider.family<List<Bill>, BillHistoryQueryParams>((
      ref,
      params,
    ) async {
      final repo = ref.watch(returnRepositoryProvider);
      return repo.getBillHistory(
        query: params.query,
        from: params.from,
        to: params.to,
        limit: params.limit,
      );
    });

final billHistoryPreviewProvider =
    FutureProvider.family<BillHistoryPreviewResult, BillHistoryQueryParams>((
      ref,
      params,
    ) async {
      final repo = ref.watch(returnRepositoryProvider);
      final previewLimit = params.limit ?? 15;
      final rows = await repo.getBillHistory(
        query: params.query,
        from: params.from,
        to: params.to,
        limit: previewLimit + 1,
      );
      return BillHistoryPreviewResult(
        bills: rows.take(previewLimit).toList(),
        hasMore: rows.length > previewLimit,
      );
    });
