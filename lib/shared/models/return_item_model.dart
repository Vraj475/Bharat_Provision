class ReturnItem {
  final int? id;
  final int returnId;
  final int productId;
  final double qtyReturned;
  final double valueAtReturn;

  const ReturnItem({
    this.id,
    required this.returnId,
    required this.productId,
    required this.qtyReturned,
    required this.valueAtReturn,
  });

  factory ReturnItem.fromMap(Map<String, dynamic> map) {
    return ReturnItem(
      id: map['id'] as int?,
      returnId: map['return_id'] as int,
      productId: map['product_id'] as int,
      qtyReturned: (map['qty_returned'] as num).toDouble(),
      valueAtReturn: (map['value_at_return'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'return_id': returnId,
      'product_id': productId,
      'qty_returned': qtyReturned,
      'value_at_return': valueAtReturn,
    };
  }
}
