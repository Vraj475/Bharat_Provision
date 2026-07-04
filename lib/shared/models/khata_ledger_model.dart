class KhataLedgerEntry {
  final int? id;
  final String entryType; // debit | credit
  final String accountName;
  final int? customerId;
  final double amount;
  final String? paymentMode;
  final String? referenceType; // bill | expense | manual | udhaar_payment
  final int? referenceId;
  final String? note;
  final String entryDate;
  final String createdAt;

  const KhataLedgerEntry({
    this.id,
    required this.entryType,
    required this.accountName,
    this.customerId,
    required this.amount,
    this.paymentMode,
    this.referenceType,
    this.referenceId,
    this.note,
    required this.entryDate,
    required this.createdAt,
  });

  factory KhataLedgerEntry.fromMap(Map<String, dynamic> map) {
    return KhataLedgerEntry(
      id: map['id'] as int?,
      entryType: map['entry_type'] as String,
      accountName: map['account_name'] as String,
      customerId: map['customer_id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      paymentMode: map['payment_mode'] as String?,
      referenceType: map['reference_type'] as String?,
      referenceId: map['reference_id'] as int?,
      note: map['note'] as String?,
      entryDate: map['entry_date'] as String,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'entry_type': entryType,
      'account_name': accountName,
      'customer_id': customerId,
      'amount': amount,
      'payment_mode': paymentMode,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'note': note,
      'entry_date': entryDate,
      'created_at': createdAt,
    };
  }
}
