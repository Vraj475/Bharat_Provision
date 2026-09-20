class ReminderLogEntry {
  final int? id;
  final int customerId;
  final String? reminderType; // whatsapp | sms | pdf
  final String sentDate;
  final double balanceAtTime;

  const ReminderLogEntry({
    this.id,
    required this.customerId,
    this.reminderType,
    required this.sentDate,
    required this.balanceAtTime,
  });

  factory ReminderLogEntry.fromMap(Map<String, dynamic> map) {
    return ReminderLogEntry(
      id: map['id'] as int?,
      customerId: map['customer_id'] as int,
      reminderType: map['reminder_type'] as String?,
      sentDate: map['sent_date'] as String,
      balanceAtTime: (map['balance_at_time'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'customer_id': customerId,
      'reminder_type': reminderType,
      'sent_date': sentDate,
      'balance_at_time': balanceAtTime,
    };
  }
}
