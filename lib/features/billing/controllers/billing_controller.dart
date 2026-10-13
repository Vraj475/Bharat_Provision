import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bill_line_item.dart';

class BillingState {
  final List<BillLineItem> billLines;
  final double discount;
  final double otherCharges;
  final int? customerId;
  final String? customerName;
  final String? shopName;
  final bool isEditingGrandTotal;
  final bool isGrandTotalAdjusted;

  BillingState({
    this.billLines = const [],
    this.discount = 0.0,
    this.otherCharges = 0.0,
    this.customerId,
    this.customerName,
    this.shopName,
    this.isEditingGrandTotal = false,
    this.isGrandTotalAdjusted = false,
  });

  double get subtotal => billLines.fold(0, (sum, line) => sum + line.amount);
  double get legitTotal => (subtotal - discount).clamp(0.0, double.infinity);
  double get total => (legitTotal + otherCharges).clamp(0.0, double.infinity);

  BillingState copyWith({
    List<BillLineItem>? billLines,
    double? discount,
    double? otherCharges,
    int? customerId,
    String? customerName,
    String? shopName,
    bool? isEditingGrandTotal,
    bool? isGrandTotalAdjusted,
  }) {
    return BillingState(
      billLines: billLines ?? this.billLines,
      discount: discount ?? this.discount,
      otherCharges: otherCharges ?? this.otherCharges,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      shopName: shopName ?? this.shopName,
      isEditingGrandTotal: isEditingGrandTotal ?? this.isEditingGrandTotal,
      isGrandTotalAdjusted: isGrandTotalAdjusted ?? this.isGrandTotalAdjusted,
    );
  }
}

class BillingController extends StateNotifier<BillingState> {
  BillingController() : super(BillingState());

  void setShopName(String name) {
    state = state.copyWith(shopName: name);
  }

  void setCustomer(int? id, String? name) {
    state = state.copyWith(customerId: id, customerName: name);
  }

  void setDiscount(double discount) {
    state = state.copyWith(discount: discount);
  }

  void setOtherCharges(double otherCharges) {
    state = state.copyWith(otherCharges: otherCharges);
  }

  void startGrandTotalEdit() {
    state = state.copyWith(isEditingGrandTotal: true);
  }

  void cancelGrandTotalEdit() {
    state = state.copyWith(isEditingGrandTotal: false);
  }

  void commitGrandTotalEdit(double newTotal) {
    // Legit total is subtotal minus current discount
    final legitTotal = (state.subtotal - state.discount).clamp(0.0, double.infinity);
    final diff = newTotal - legitTotal;

    if (diff > 5.0) {
      // Whenever the user adds more than 5 rupees in the final total above the legit total,
      // the excess amount is added as other charges in the bill
      state = state.copyWith(
        otherCharges: diff,
        isEditingGrandTotal: false,
        isGrandTotalAdjusted: true,
      );
    } else if (newTotal < legitTotal) {
      // Amount reduced below legit total -> becomes discount
      final newDiscount = (state.subtotal - newTotal).clamp(0.0, double.infinity);
      state = state.copyWith(
        discount: newDiscount,
        otherCharges: 0.0,
        isEditingGrandTotal: false,
        isGrandTotalAdjusted: true,
      );
    } else {
      // Diff is between 0 and 5 rupees above legit total -> not more than 5 rupees
      state = state.copyWith(
        otherCharges: 0.0,
        isEditingGrandTotal: false,
        isGrandTotalAdjusted: diff != 0,
      );
    }
  }

  void clearBill() {
    state = BillingState(
      shopName: state.shopName,
    );
  }

  void addLine(BillLineItem line) {
    state = state.copyWith(billLines: [...state.billLines, line]);
  }

  void insertLine(int index, BillLineItem line) {
    final validIndex = index.clamp(0, state.billLines.length);
    final newLines = List<BillLineItem>.from(state.billLines)..insert(validIndex, line);
    state = state.copyWith(billLines: newLines);
  }

  void removeLine(int index) {
    if (index < 0 || index >= state.billLines.length) return;
    final newLines = List<BillLineItem>.from(state.billLines)..removeAt(index);
    state = state.copyWith(billLines: newLines);
  }

  void updateLine(int index, BillLineItem updatedLine) {
    if (index < 0 || index >= state.billLines.length) return;
    final newLines = List<BillLineItem>.from(state.billLines);
    newLines[index] = updatedLine;
    state = state.copyWith(billLines: newLines);
  }

  void syncLines(List<BillLineItem> lines) {
    state = state.copyWith(billLines: lines);
  }
}

final billingControllerProvider = StateNotifierProvider<BillingController, BillingState>((ref) {
  return BillingController();
});
