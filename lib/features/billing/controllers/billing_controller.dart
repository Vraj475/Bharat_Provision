import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bill_line_item.dart';
import '../../../data/models/item.dart';

class BillingState {
  final List<BillLineItem> billLines;
  final double discount;
  final int? customerId;
  final String? customerName;
  final String? shopName;
  final bool isEditingGrandTotal;
  final bool isGrandTotalAdjusted;

  BillingState({
    this.billLines = const [],
    this.discount = 0.0,
    this.customerId,
    this.customerName,
    this.shopName,
    this.isEditingGrandTotal = false,
    this.isGrandTotalAdjusted = false,
  });

  double get subtotal => billLines.fold(0, (sum, line) => sum + line.amount);
  double get total => subtotal - discount;

  BillingState copyWith({
    List<BillLineItem>? billLines,
    double? discount,
    int? customerId,
    String? customerName,
    String? shopName,
    bool? isEditingGrandTotal,
    bool? isGrandTotalAdjusted,
  }) {
    return BillingState(
      billLines: billLines ?? this.billLines,
      discount: discount ?? this.discount,
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

  void startGrandTotalEdit() {
    state = state.copyWith(isEditingGrandTotal: true);
  }

  void commitGrandTotalEdit(double newTotal) {
    final newDiscount = state.subtotal - newTotal;
    state = state.copyWith(
      discount: newDiscount < 0 ? 0 : newDiscount,
      isEditingGrandTotal: false,
      isGrandTotalAdjusted: true,
    );
  }

  void clearBill() {
    state = BillingState(
      shopName: state.shopName,
    );
  }

  void addLine(BillLineItem line) {
    state = state.copyWith(billLines: [...state.billLines, line]);
  }

  void removeLine(int index) {
    final newLines = List<BillLineItem>.from(state.billLines)..removeAt(index);
    state = state.copyWith(billLines: newLines);
  }

  void updateLine(int index, BillLineItem updatedLine) {
    final newLines = List<BillLineItem>.from(state.billLines);
    newLines[index] = updatedLine;
    state = state.copyWith(billLines: newLines);
  }
}

final billingControllerProvider = StateNotifierProvider<BillingController, BillingState>((ref) {
  return BillingController();
});
