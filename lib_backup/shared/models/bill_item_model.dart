class BillItem {
  final int? id;
  final int billId;
  final int productId;
  final String? productNameSnapshot;
  final String? unitTypeSnapshot;
  final double? sellPriceSnapshot;
  final double qty;
  final double amount;
  final bool isReturned;

  const BillItem({
    this.id,
    required this.billId,
    required this.productId,
    this.productNameSnapshot,
    this.unitTypeSnapshot,
    this.sellPriceSnapshot,
    required this.qty,
    required this.amount,
    required this.isReturned,
  });

  factory BillItem.fromMap(Map<String, dynamic> map) {
    return BillItem(
      id: map['id'] as int?,
      billId: map['bill_id'] as int,
      productId: map['product_id'] as int,
      productNameSnapshot: map['product_name_snapshot'] as String?,
      unitTypeSnapshot: map['unit_type_snapshot'] as String?,
      sellPriceSnapshot: (map['sell_price_snapshot'] as num?)?.toDouble(),
      qty: (map['qty'] as num).toDouble(),
      amount: (map['amount'] as num).toDouble(),
      isReturned: (map['is_returned'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'bill_id': billId,
      'product_id': productId,
      'product_name_snapshot': productNameSnapshot,
      'unit_type_snapshot': unitTypeSnapshot,
      'sell_price_snapshot': sellPriceSnapshot,
      'qty': qty,
      'amount': amount,
      'is_returned': isReturned ? 1 : 0,
    };
  }
}
