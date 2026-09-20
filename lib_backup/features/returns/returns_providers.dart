import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_helper.dart';
import '../../data/repositories/return_repository.dart';
import '../../shared/models/bill_model.dart';

final returnRepositoryProvider = Provider<ReturnRepository>(
  (ref) => ReturnRepository(DatabaseHelper.instance),
);

class BillListQueryParams {
  const BillListQueryParams({
    this.query = '',
    this.status = 'all',
    this.from,
    this.to,
  });

  final String query;
  final String status;
  final DateTime? from;
  final DateTime? to;

  @override
  bool operator ==(Object other) {
    return other is BillListQueryParams &&
        other.query == query &&
        other.status == status &&
        other.from == from &&
        other.to == to;
  }

  @override
  int get hashCode => Object.hash(query, status, from, to);
}

final returnBillListProvider =
    FutureProvider.family<List<Bill>, BillListQueryParams>((ref, params) async {
      final repo = ref.watch(returnRepositoryProvider);
      return repo.getBillHistory(
        query: params.query,
        paymentStatus: params.status == 'all' ? null : params.status,
        from: params.from,
        to: params.to,
      );
    });

final returnSearchQueryProvider = StateProvider<String>((ref) => '');

final returnSelectedBillProvider = StateProvider<int?>((ref) => null);

final returnModeProvider = StateProvider<String>((ref) => 'cash_refund');

final returnSelectedItemsProvider = StateProvider<List<int>>((ref) => []);

final replaceSelectedProductProvider = StateProvider<int?>((ref) => null);

// Add other providers as needed for return flow state.
