class Bill {
  final int? id;
  final String billNumber;
  final int? customerId;
  final String? customerNameSnapshot;
  final String billDate;
  final double subtotal;
  final double discount;
  final double gstAmount;
  final double totalAmount;
  final double paidAmount;
  final double udhaarAmount;
  final String? paymentMode; // cash | upi | card | udhaar | split
  final String?
  paymentStatus; // paid | udhaar | partial | partial_return | fully_returned
  final bool isPrinted;
  final bool isReturned;
  final String? notes;
  final String? createdByRole;
  final String createdAt;

  const Bill({
    this.id,
    required this.billNumber,
    this.customerId,
    this.customerNameSnapshot,
    required this.billDate,
    required this.subtotal,
    required this.discount,
    required this.gstAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.udhaarAmount,
    this.paymentMode,
    this.paymentStatus,
    required this.isPrinted,
    required this.isReturned,
    this.notes,
    this.createdByRole,
    required this.createdAt,
  });

  factory Bill.fromMap(Map<String, dynamic> map) {
    final rawDateTime = map['date_time'];
    final dateTimeIso = rawDateTime is int
        ? DateTime.fromMillisecondsSinceEpoch(rawDateTime).toIso8601String()
        : DateTime.now().toIso8601String();

    return Bill(
      id: map['id'] as int?,
      billNumber: (map['bill_number'] ?? '').toString(),
      customerId: map['customer_id'] as int?,
      customerNameSnapshot: map['customer_name_snapshot'] as String?,
      billDate: (map['bill_date'] ?? dateTimeIso).toString(),
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
      discount:
          ((map['discount'] ?? map['discount_amount']) as num?)?.toDouble() ??
          0,
      gstAmount:
          ((map['gst_amount'] ?? map['tax_amount']) as num?)?.toDouble() ?? 0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0,
      udhaarAmount: (map['udhaar_amount'] as num?)?.toDouble() ?? 0,
      paymentMode: map['payment_mode'] as String?,
      paymentStatus: map['payment_status'] as String?,
      isPrinted: (map['is_printed'] as int? ?? 0) == 1,
      isReturned: (map['is_returned'] as int? ?? 0) == 1,
      notes: map['notes'] as String?,
      createdByRole: map['created_by_role'] as String?,
      createdAt: (map['created_at'] ?? dateTimeIso).toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'bill_number': billNumber,
      'customer_id': customerId,
      'customer_name_snapshot': customerNameSnapshot,
      'bill_date': billDate,
      'subtotal': subtotal,
      'discount': discount,
      'gst_amount': gstAmount,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'udhaar_amount': udhaarAmount,
      'payment_mode': paymentMode,
      'payment_status': paymentStatus,
      'is_printed': isPrinted ? 1 : 0,
      'is_returned': isReturned ? 1 : 0,
      'notes': notes,
      'created_by_role': createdByRole,
      'created_at': createdAt,
    };
  }
}
