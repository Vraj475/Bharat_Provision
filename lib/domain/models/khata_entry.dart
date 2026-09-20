class KhataEntry {
  final int? id;
  final int customerId;
  final int? relatedBillId;
  final int dateTime;
  final String type; // 'debit' | 'credit'
  final double amount;
  final String? note;
  final double balanceAfter;

  const KhataEntry({
    this.id,
    required this.customerId,
    this.relatedBillId,
    required this.dateTime,
    required this.type,
    required this.amount,
    this.note,
    required this.balanceAfter,
  });

  factory KhataEntry.fromMap(Map<String, dynamic> map) {
    return KhataEntry(
      id: map['id'] as int?,
      customerId: map['customer_id'] as int,
      relatedBillId: map['related_bill_id'] as int?,
      dateTime: map['date_time'] as int,
      type: map['type'] as String? ?? 'debit',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      note: map['note'] as String?,
      balanceAfter: (map['balance_after'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'customer_id': customerId,
      'related_bill_id': relatedBillId,
      'date_time': dateTime,
      'type': type,
      'amount': amount,
      'note': note,
      'balance_after': balanceAfter,
    };
  }

  bool get isDebit => type == 'debit';
  bool get isCredit => type == 'credit';
}
