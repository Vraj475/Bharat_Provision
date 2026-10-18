import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/weighted_average.dart';
import '../../../data/providers.dart';
import '../../../shared/models/product_model.dart';
import '../../../shared/models/purchase_model.dart';

class PurchaseFilterState {
  final DateTime? startDate;
  final DateTime? endDate;
  final String query;

  const PurchaseFilterState({
    this.startDate,
    this.endDate,
    this.query = '',
  });

  PurchaseFilterState copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? query,
    bool clearDates = false,
  }) {
    return PurchaseFilterState(
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
      query: query ?? this.query,
    );
  }
}

final purchaseFilterProvider = StateProvider<PurchaseFilterState>((ref) {
  return const PurchaseFilterState();
});

final purchasesListProvider = FutureProvider<List<Purchase>>((ref) async {
  final repo = ref.watch(purchaseRepositoryProvider);
  final filter = ref.watch(purchaseFilterProvider);
  return repo.getPurchases(
    startDate: filter.startDate,
    endDate: filter.endDate,
    query: filter.query,
  );
});

final purchaseSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(purchaseRepositoryProvider);
  final filter = ref.watch(purchaseFilterProvider);
  return repo.getPurchaseSummary(
    startDate: filter.startDate,
    endDate: filter.endDate,
  );
});

final registeredSuppliersProvider =
    FutureProvider<List<Map<String, String>>>((ref) async {
  final repo = ref.watch(purchaseRepositoryProvider);
  return repo.getRegisteredSuppliers();
});

class PurchaseLineDraft {
  final Product product;
  double qty;
  double unitCost;
  double? customSellPrice;

  PurchaseLineDraft({
    required this.product,
    this.qty = 1.0,
    required this.unitCost,
    this.customSellPrice,
  });

  double get totalCost => double.parse((qty * unitCost).toStringAsFixed(2));

  double get newAvgCost => WeightedAverageCalculator.calculateWeightedAverage(
        oldQty: product.stockQty,
        oldCost: product.buyPrice,
        newQty: qty,
        newCost: unitCost,
      );

  bool get hasSignificantIncrease =>
      WeightedAverageCalculator.hasSignificantCostIncrease(
        oldCost: product.buyPrice,
        newCost: newAvgCost,
      );

  double get percentageIncrease =>
      WeightedAverageCalculator.calculateCostChangePercentage(
        oldCost: product.buyPrice,
        newCost: newAvgCost,
      );

  double get suggestedSellPrice =>
      WeightedAverageCalculator.suggestSellingPrice(
        oldCost: product.buyPrice,
        oldSell: product.sellPrice,
        newCost: newAvgCost,
      );

  PurchaseLineDraft copyWith({
    Product? product,
    double? qty,
    double? unitCost,
    double? customSellPrice,
  }) {
    return PurchaseLineDraft(
      product: product ?? this.product,
      qty: qty ?? this.qty,
      unitCost: unitCost ?? this.unitCost,
      customSellPrice: customSellPrice ?? this.customSellPrice,
    );
  }
}

class PurchaseDraftState {
  final String? purchaseNo;
  final DateTime purchaseDate;
  final String supplierName;
  final String supplierPhone;
  final String paymentMode;
  final double paidAmount;
  final String notes;
  final List<PurchaseLineDraft> items;

  PurchaseDraftState({
    this.purchaseNo,
    DateTime? purchaseDate,
    this.supplierName = '',
    this.supplierPhone = '',
    this.paymentMode = 'cash',
    this.paidAmount = 0.0,
    this.notes = '',
    this.items = const [],
  }) : purchaseDate = purchaseDate ?? DateTime.now();

  double get totalAmount =>
      items.fold(0.0, (sum, item) => sum + item.totalCost);

  PurchaseDraftState copyWith({
    String? purchaseNo,
    DateTime? purchaseDate,
    String? supplierName,
    String? supplierPhone,
    String? paymentMode,
    double? paidAmount,
    String? notes,
    List<PurchaseLineDraft>? items,
  }) {
    return PurchaseDraftState(
      purchaseNo: purchaseNo ?? this.purchaseNo,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      supplierName: supplierName ?? this.supplierName,
      supplierPhone: supplierPhone ?? this.supplierPhone,
      paymentMode: paymentMode ?? this.paymentMode,
      paidAmount: paidAmount ?? this.paidAmount,
      notes: notes ?? this.notes,
      items: items ?? this.items,
    );
  }
}

class PurchaseDraftNotifier extends StateNotifier<PurchaseDraftState> {
  PurchaseDraftNotifier() : super(PurchaseDraftState());

  void setSupplierName(String name) {
    state = state.copyWith(supplierName: name);
  }

  void setSupplierPhone(String phone) {
    state = state.copyWith(supplierPhone: phone);
  }

  void setPurchaseDate(DateTime date) {
    state = state.copyWith(purchaseDate: date);
  }

  void setPaymentMode(String mode) {
    state = state.copyWith(paymentMode: mode);
  }

  void setPaidAmount(double amount) {
    state = state.copyWith(paidAmount: amount);
  }

  void setNotes(String notes) {
    state = state.copyWith(notes: notes);
  }

  void addProduct(Product product, {double qty = 1.0, double? unitCost}) {
    final effectiveCost = unitCost ?? (product.buyPrice > 0 ? product.buyPrice : product.sellPrice * 0.8);
    // Check if item already in list
    final existingIndex = state.items.indexWhere((i) => i.product.id == product.id);
    if (existingIndex >= 0) {
      final existing = state.items[existingIndex];
      final updated = existing.copyWith(qty: existing.qty + qty);
      final newItems = List<PurchaseLineDraft>.from(state.items);
      newItems[existingIndex] = updated;
      state = state.copyWith(items: newItems, paidAmount: _calcPaidAmount(newItems));
    } else {
      final newItem = PurchaseLineDraft(
        product: product,
        qty: qty,
        unitCost: effectiveCost,
      );
      final newItems = [...state.items, newItem];
      state = state.copyWith(items: newItems, paidAmount: _calcPaidAmount(newItems));
    }
  }

  void updateItemQty(int index, double qty) {
    if (index < 0 || index >= state.items.length) return;
    final item = state.items[index];
    final updated = item.copyWith(qty: qty);
    final newItems = List<PurchaseLineDraft>.from(state.items);
    newItems[index] = updated;
    state = state.copyWith(items: newItems, paidAmount: _calcPaidAmount(newItems));
  }

  void updateItemUnitCost(int index, double unitCost) {
    if (index < 0 || index >= state.items.length) return;
    final item = state.items[index];
    final updated = item.copyWith(unitCost: unitCost);
    final newItems = List<PurchaseLineDraft>.from(state.items);
    newItems[index] = updated;
    state = state.copyWith(items: newItems, paidAmount: _calcPaidAmount(newItems));
  }

  void updateItemSellPrice(int index, double? customSellPrice) {
    if (index < 0 || index >= state.items.length) return;
    final item = state.items[index];
    final updated = item.copyWith(customSellPrice: customSellPrice);
    final newItems = List<PurchaseLineDraft>.from(state.items);
    newItems[index] = updated;
    state = state.copyWith(items: newItems);
  }

  void removeItem(int index) {
    if (index < 0 || index >= state.items.length) return;
    final newItems = List<PurchaseLineDraft>.from(state.items)..removeAt(index);
    state = state.copyWith(items: newItems, paidAmount: _calcPaidAmount(newItems));
  }

  double _calcPaidAmount(List<PurchaseLineDraft> items) {
    final total = items.fold(0.0, (sum, item) => sum + item.totalCost);
    // If payment mode is cash or bank, default paidAmount to full amount
    if (state.paymentMode == 'cash' || state.paymentMode == 'bank') {
      return total;
    }
    return state.paidAmount;
  }

  void reset() {
    state = PurchaseDraftState();
  }
}

final purchaseDraftProvider =
    StateNotifierProvider<PurchaseDraftNotifier, PurchaseDraftState>((ref) {
  return PurchaseDraftNotifier();
});
