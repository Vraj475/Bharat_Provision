import '../../../data/models/item.dart';

class BillLineItem {
  BillLineItem({
    required this.draftKey,
    required this.item,
    required this.qtyGrams,
    required this.amount,
  });

  final String draftKey;
  final Item item;
  final double qtyGrams;
  final double amount;

  BillLineItem copyWith({
    String? draftKey,
    Item? item,
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
