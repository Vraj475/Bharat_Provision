class ReplaceTransaction {
  final int? id;
  final int returnId;
  final int returnedProductId;
  final double returnedQty;
  final double returnedValue;
  final int replacementProductId;
  final double replacementQtyCalculated;
  final double replacementQtyGiven;
  final double priceDifference;
  final String? differenceMode; // cash_paid | cash_received | udhaar
  final String createdAt;

  const ReplaceTransaction({
    this.id,
    required this.returnId,
    required this.returnedProductId,
    required this.returnedQty,
    required this.returnedValue,
    required this.replacementProductId,
    required this.replacementQtyCalculated,
    required this.replacementQtyGiven,
    required this.priceDifference,
    this.differenceMode,
    required this.createdAt,
  });

  factory ReplaceTransaction.fromMap(Map<String, dynamic> map) {
    return ReplaceTransaction(
      id: map['id'] as int?,
      returnId: map['return_id'] as int,
      returnedProductId: map['returned_product_id'] as int,
      returnedQty: (map['returned_qty'] as num).toDouble(),
      returnedValue: (map['returned_value'] as num).toDouble(),
      replacementProductId: map['replacement_product_id'] as int,
      replacementQtyCalculated: (map['replacement_qty_calculated'] as num)
          .toDouble(),
      replacementQtyGiven: (map['replacement_qty_given'] as num).toDouble(),
      priceDifference: (map['price_difference'] as num?)?.toDouble() ?? 0,
      differenceMode: map['difference_mode'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'return_id': returnId,
      'returned_product_id': returnedProductId,
      'returned_qty': returnedQty,
      'returned_value': returnedValue,
      'replacement_product_id': replacementProductId,
      'replacement_qty_calculated': replacementQtyCalculated,
      'replacement_qty_given': replacementQtyGiven,
      'price_difference': priceDifference,
      'difference_mode': differenceMode,
      'created_at': createdAt,
    };
  }
}
