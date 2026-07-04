class StockLogEntry {
  final int? id;
  final int productId;
  final String
  transactionType; // purchase | sale | return | replace_in | replace_out | manual_adjust
  final double qtyChange;
  final double qtyBefore;
  final double qtyAfter;
  final int? referenceId;
  final String? referenceType; // bill | return | replace | manual
  final String? note;
  final String createdAt;

  const StockLogEntry({
    this.id,
    required this.productId,
    required this.transactionType,
    required this.qtyChange,
    required this.qtyBefore,
    required this.qtyAfter,
    this.referenceId,
    this.referenceType,
    this.note,
    required this.createdAt,
  });

  factory StockLogEntry.fromMap(Map<String, dynamic> map) {
    return StockLogEntry(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      transactionType: map['transaction_type'] as String,
      qtyChange: (map['qty_change'] as num).toDouble(),
      qtyBefore: (map['qty_before'] as num).toDouble(),
      qtyAfter: (map['qty_after'] as num).toDouble(),
      referenceId: map['reference_id'] as int?,
      referenceType: map['reference_type'] as String?,
      note: map['note'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'product_id': productId,
      'transaction_type': transactionType,
      'qty_change': qtyChange,
      'qty_before': qtyBefore,
      'qty_after': qtyAfter,
      'reference_id': referenceId,
      'reference_type': referenceType,
      'note': note,
      'created_at': createdAt,
    };
  }
}
