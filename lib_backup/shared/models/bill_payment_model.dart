class BillPayment {
  final int? id;
  final int billId;
  final int customerId;
  final double amountPaid;
  final String paymentMode;
  final String paymentDate;
  final String? note;

  const BillPayment({
    this.id,
    required this.billId,
    required this.customerId,
    required this.amountPaid,
    required this.paymentMode,
    required this.paymentDate,
    this.note,
  });

  factory BillPayment.fromMap(Map<String, dynamic> map) {
    return BillPayment(
      id: map['id'] as int?,
      billId: map['bill_id'] as int,
      customerId: map['customer_id'] as int,
      amountPaid: (map['amount_paid'] as num).toDouble(),
      paymentMode: map['payment_mode'] as String,
      paymentDate: map['payment_date'] as String,
      note: map['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'bill_id': billId,
      'customer_id': customerId,
      'amount_paid': amountPaid,
      'payment_mode': paymentMode,
      'payment_date': paymentDate,
      'note': note,
    };
  }
}
