class UdhaarLedgerEntry {
  final int? id;
  final int customerId;
  final int? billId;
  final String transactionType; // credit | payment
  final double amount;
  final double runningBalance;
  final String? paymentMode;
  final String? note;
  final String createdAt;

  const UdhaarLedgerEntry({
    this.id,
    required this.customerId,
    this.billId,
    required this.transactionType,
    required this.amount,
    required this.runningBalance,
    this.paymentMode,
    this.note,
    required this.createdAt,
  });

  factory UdhaarLedgerEntry.fromMap(Map<String, dynamic> map) {
    return UdhaarLedgerEntry(
      id: map['id'] as int?,
      customerId: map['customer_id'] as int,
      billId: map['bill_id'] as int?,
      transactionType: map['transaction_type'] as String,
      amount: (map['amount'] as num).toDouble(),
      runningBalance: (map['running_balance'] as num).toDouble(),
      paymentMode: map['payment_mode'] as String?,
      note: map['note'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'customer_id': customerId,
      'bill_id': billId,
      'transaction_type': transactionType,
      'amount': amount,
      'running_balance': runningBalance,
      'payment_mode': paymentMode,
      'note': note,
      'created_at': createdAt,
    };
  }
}
