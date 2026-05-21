import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/foundation.dart' show debugPrint;

import '../../core/errors/error_handler.dart';
import '../../data/models/item.dart';
import '../../data/providers.dart';

// Billing search provider
final billingSearchProvider = StateProvider<String>((ref) => '');

// Items provider for billing - fetches from the same items table as inventory
final billingItemsProvider = FutureProvider<List<Item>>((ref) async {
  try {
    final repo = await ref.watch(itemRepositoryFutureProvider.future);
    final query = ref.watch(billingSearchProvider);

    if (query.isEmpty) {
      return repo.getAll();
    }

    return repo.search(query, lowStockOnly: false);
  } catch (e, st) {
    throw ErrorHandler.handle(
      e,
      st,
      context: 'BillingProviders.billingItemsProvider',
    );
  }
});

/// Single line in a bill draft.
class BillLine {
  BillLine({required this.item, required this.qtyGrams, required this.amount});

  final Item item;

  /// Stored in grams for weight-based units, or as "units" for count / litre.
  final double qtyGrams;

  /// Final line amount in ₹.
  final double amount;
}

/// Per-tab draft state – corresponds to one bill tab.
class BillDraft {
  BillDraft({
    this.lines = const [],
    this.discountAmount = 0,
    this.customerId,
    this.customerName,
    this.transactionType = 'cash',
  });

  final List<BillLine> lines;
  final double discountAmount;
  final int? customerId;
  final String? customerName;
  final String transactionType; // 'cash' or 'udhaar'

  double get subtotal => lines.fold(0, (s, l) => s + l.amount);
  double get total => subtotal - discountAmount;

  BillDraft copyWith({
    List<BillLine>? lines,
    double? discountAmount,
    int? customerId,
    String? customerName,
    String? transactionType,
  }) {
    return BillDraft(
      lines: lines ?? this.lines,
      discountAmount: discountAmount ?? this.discountAmount,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      transactionType: transactionType ?? this.transactionType,
    );
  }

  bool get isEmpty =>
      lines.isEmpty && discountAmount == 0 && customerId == null;
}

/// Overall billing tabs state – holds five independent drafts.
class BillingTabsState {
  BillingTabsState({required this.activeIndex, required this.drafts})
    : assert(drafts.length == 5, 'Must always maintain 5 bill drafts');

  final int activeIndex;
  final List<BillDraft> drafts;

  BillDraft get activeDraft => drafts[activeIndex];

  BillingTabsState copyWith({int? activeIndex, List<BillDraft>? drafts}) {
    return BillingTabsState(
      activeIndex: activeIndex ?? this.activeIndex,
      drafts: drafts ?? this.drafts,
    );
  }
}

class BillingTabsNotifier extends StateNotifier<BillingTabsState> {
  BillingTabsNotifier()
    : super(
        BillingTabsState(
          activeIndex: 0,
          drafts: List<BillDraft>.generate(5, (_) => BillDraft()),
        ),
      );

  void switchToTab(int index) {
    if (index < 0 || index >= state.drafts.length) return;
    state = state.copyWith(activeIndex: index);
  }

  void addLineToActive(BillLine line) {
    final drafts = [...state.drafts];
    final current = drafts[state.activeIndex];
    drafts[state.activeIndex] = current.copyWith(
      lines: [...current.lines, line],
    );
    state = state.copyWith(drafts: drafts);
  }

  void updateLineInActive(int index, BillLine updatedLine) {
    final drafts = [...state.drafts];
    final current = drafts[state.activeIndex];
    if (index < 0 || index >= current.lines.length) return;
    final newLines = [...current.lines]..[index] = updatedLine;
    drafts[state.activeIndex] = current.copyWith(lines: newLines);
    state = state.copyWith(drafts: drafts);
  }

  void removeLineFromActive(int index) {
    final drafts = [...state.drafts];
    final current = drafts[state.activeIndex];
    if (index < 0 || index >= current.lines.length) return;
    final newLines = [...current.lines]..removeAt(index);
    drafts[state.activeIndex] = current.copyWith(lines: newLines);
    state = state.copyWith(drafts: drafts);
  }

  void setDiscountForActive(double amount) {
    final drafts = [...state.drafts];
    final current = drafts[state.activeIndex];
    drafts[state.activeIndex] = current.copyWith(discountAmount: amount);
    state = state.copyWith(drafts: drafts);
  }

  void setCustomerForActive({
    required int? customerId,
    required String? customerName,
  }) {
    final drafts = [...state.drafts];
    final current = drafts[state.activeIndex];
    drafts[state.activeIndex] = current.copyWith(
      customerId: customerId,
      customerName: customerName,
    );
    state = state.copyWith(drafts: drafts);
  }

  void setSelectedCustomer(int customerId, String customerName) {
    debugPrint('CUSTOMER SET: id=$customerId name=$customerName');
    setCustomerForActive(
      customerId: customerId,
      customerName: customerName,
    );
  }

  void setTransactionTypeForActive(String type) {
    final drafts = [...state.drafts];
    final current = drafts[state.activeIndex];
    // When switching from udhaar to cash, clear customer selection
    if (current.transactionType == 'udhaar' && type == 'cash') {
      drafts[state.activeIndex] = current.copyWith(
        transactionType: type,
        customerId: null,
        customerName: null,
      );
    } else {
      drafts[state.activeIndex] = current.copyWith(transactionType: type);
    }
    state = state.copyWith(drafts: drafts);
  }

  /// Clears only the currently active tab draft.
  void clearActive() {
    final drafts = [...state.drafts];
    drafts[state.activeIndex] = BillDraft();
    state = state.copyWith(drafts: drafts);
  }

  /// Clears a specific tab (used by "close tab" behaviour).
  void clearTab(int index) {
    if (index < 0 || index >= state.drafts.length) return;
    final drafts = [...state.drafts];
    drafts[index] = BillDraft();
    state = state.copyWith(drafts: drafts);
  }
}

/// Riverpod provider exposing the billing tabs state.
final billingTabsProvider =
    StateNotifierProvider<BillingTabsNotifier, BillingTabsState>((ref) {
      return BillingTabsNotifier();
    });
