class Expense {
  final int? id;
  final int? expenseAccountId;
  final String? accountNameSnapshot;
  final double amount;
  final String? description;
  final String expenseDate;
  final String? createdBy;
  final String createdAt;

  const Expense({
    this.id,
    this.expenseAccountId,
    this.accountNameSnapshot,
    required this.amount,
    this.description,
    required this.expenseDate,
    this.createdBy,
    required this.createdAt,
  });

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      expenseAccountId: map['expense_account_id'] as int?,
      accountNameSnapshot: map['account_name_snapshot'] as String?,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String?,
      expenseDate: map['expense_date'] as String,
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'expense_account_id': expenseAccountId,
      'account_name_snapshot': accountNameSnapshot,
      'amount': amount,
      'description': description,
      'expense_date': expenseDate,
      'created_by': createdBy,
      'created_at': createdAt,
    };
  }
}
