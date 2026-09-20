import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_helper.dart';
import '../../core/errors/error_handler.dart';
import '../../data/repositories/udhaar_repository.dart';
import '../../shared/models/bill_item_model.dart';
import '../../shared/models/customer_model.dart';

// ─── Core repository provider ─────────────────────────────────────────────────

final udhaarRepositoryProvider = Provider<UdhaarRepository>(
  (ref) => UdhaarRepository(DatabaseHelper.instance),
);

// ─── Master Udhaar Provider - Single Source of Truth for Credit Data ─────────

class UdhaarNotifier extends AsyncNotifier<List<CustomerSummaryRow>> {
  @override
  Future<List<CustomerSummaryRow>> build() async {
    final repo = ref.watch(udhaarRepositoryProvider);
    return repo.getAllCustomersSorted();
  }
}

/// MASTER provider for all udhaar/credit data - single source of truth
/// All screens showing udhaar info should watch this provider
final udhaarProvider =
    AsyncNotifierProvider<UdhaarNotifier, List<CustomerSummaryRow>>(
      () => UdhaarNotifier(),
    );

// ─── Dashboard providers ──────────────────────────────────────────────────────

final udhaarTotalOutstandingProvider = FutureProvider<double>((ref) async {
  try {
    return ref.watch(udhaarRepositoryProvider).getTotalOutstanding();
  } catch (e, st) {
    throw ErrorHandler.handle(
      e,
      st,
      context: 'UdhaarProviders.totalOutstanding',
    );
  }
});

final udhaarCustomerListProvider = FutureProvider<List<CustomerSummaryRow>>((
  ref,
) async {
  try {
    return ref.watch(udhaarRepositoryProvider).getAllCustomersSorted();
  } catch (e, st) {
    throw ErrorHandler.handle(e, st, context: 'UdhaarProviders.customerList');
  }
});

// ─── Per-customer providers ───────────────────────────────────────────────────

final udhaarCustomerProvider = FutureProvider.family<Customer?, int>((
  ref,
  customerId,
) async {
  try {
    return ref.watch(udhaarRepositoryProvider).getCustomerById(customerId);
  } catch (e, st) {
    throw ErrorHandler.handle(e, st, context: 'UdhaarProviders.customer');
  }
});

final unpaidBillsProvider = FutureProvider.autoDispose
    .family<List<UnpaidBillRow>, int>((ref, customerId) async {
      try {
        return ref.watch(udhaarRepositoryProvider).getUnpaidBills(customerId);
      } catch (e, st) {
        throw ErrorHandler.handle(
          e,
          st,
          context: 'UdhaarProviders.unpaidBills',
        );
      }
    });

final finalTotalProvider = FutureProvider.autoDispose
    .family<FinalTotalData, int>((ref, customerId) async {
      try {
        return ref.watch(udhaarRepositoryProvider).getFinalTotal(customerId);
      } catch (e, st) {
        throw ErrorHandler.handle(e, st, context: 'UdhaarProviders.finalTotal');
      }
    });

final availableMonthsProvider = FutureProvider.autoDispose
    .family<List<String>, int>((ref, customerId) async {
      try {
        return ref
            .watch(udhaarRepositoryProvider)
            .getAvailableMonths(customerId);
      } catch (e, st) {
        throw ErrorHandler.handle(
          e,
          st,
          context: 'UdhaarProviders.availableMonths',
        );
      }
    });

// ─── Settings provider ────────────────────────────────────────────────────────

final udhaarSettingsProvider = FutureProvider.autoDispose<Map<String, String>>((
  ref,
) async {
  try {
    return ref.watch(udhaarRepositoryProvider).getSettings([
      'reminder_whatsapp',
      'reminder_sms',
      'reminder_pdf',
      'print_payment_receipt',
      'shop_name',
    ]);
  } catch (e, st) {
    throw ErrorHandler.handle(e, st, context: 'UdhaarProviders.settings');
  }
});

// ─── Bill items (on-demand, loaded when a ledger row is expanded) ─────────────

final billItemsProvider = FutureProvider.autoDispose
    .family<List<BillItem>, int>((ref, billId) async {
      try {
        return ref.watch(udhaarRepositoryProvider).getBillItems(billId);
      } catch (e, st) {
        throw ErrorHandler.handle(e, st, context: 'UdhaarProviders.billItems');
      }
    });
