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

/// Master provider for saved bills - single source of truth for all bill data.
/// All screens that display bills should watch this provider.
class BillsNotifier extends AsyncNotifier<List<Bill>> {
  @override
  Future<List<Bill>> build() async {
    // Load all bills initially with no filters
    final repo = ref.watch(returnRepositoryProvider);
    return repo.getBillHistory();
  }

  /// Fetch bills with optional filters
  Future<List<Bill>> fetchBills({
    String? query,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final repo = ref.read(returnRepositoryProvider);
    return repo.getBillHistory(
      query: query,
      from: from,
      to: to,
      limit: limit,
    );
  }

  /// Update bill date and invalidate provider so all watching screens refresh
  Future<void> updateBillDate(int billId, String newBillDate) async {
    final repo = ref.read(returnRepositoryProvider);
    await repo.updateBillDate(billId, newBillDate);
    
    // Reload bills after update
    state = await AsyncValue.guard(() => _reloadBills());
  }

  /// Reload all bills from database
  Future<List<Bill>> _reloadBills() async {
    final repo = ref.read(returnRepositoryProvider);
    return repo.getBillHistory();
  }
}

/// MASTER provider for all saved bills - single source of truth
final billsProvider = AsyncNotifierProvider<BillsNotifier, List<Bill>>(
  () => BillsNotifier(),
);

/// Provider for filtered bill history - uses billsProvider and filters in-memory
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
