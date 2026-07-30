import '../../../shared/models/product_model.dart';

class BillLineItem {
  BillLineItem({
    required this.draftKey,
    required this.item,
    required this.qtyGrams,
    required this.amount,
  });

  final String draftKey;
  final Product item;
  final double qtyGrams;
  final double amount;

  BillLineItem copyWith({
    String? draftKey,
    Product? item,
    double? qtyGrams,
    double? amount,
  }) {
    return BillLineItem(
      draftKey: draftKey ?? this.draftKey,
      item: item ?? this.item,
      qtyGrams: qtyGrams ?? this.qtyGrams,
      amount: amount ?? this.amount,
    );
  }
}
