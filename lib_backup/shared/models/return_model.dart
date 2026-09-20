class ReturnEntry {
  final int? id;
  final int? originalBillId;
  final int? customerId;
  final String returnDate;
  final double totalReturnValue;
  final String? returnMode; // cash_refund | udhaar_credit | replace
  final String? notes;

  const ReturnEntry({
    this.id,
    this.originalBillId,
    this.customerId,
    required this.returnDate,
    required this.totalReturnValue,
    this.returnMode,
    this.notes,
  });

  factory ReturnEntry.fromMap(Map<String, dynamic> map) {
    return ReturnEntry(
      id: map['id'] as int?,
      originalBillId: map['original_bill_id'] as int?,
      customerId: map['customer_id'] as int?,
      returnDate: map['return_date'] as String,
      totalReturnValue: (map['total_return_value'] as num).toDouble(),
      returnMode: map['return_mode'] as String?,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'original_bill_id': originalBillId,
      'customer_id': customerId,
      'return_date': returnDate,
      'total_return_value': totalReturnValue,
      'return_mode': returnMode,
      'notes': notes,
    };
  }
}
