class ExpenseAccount {
  final int? id;
  final String accountNameGujarati;
  final String? accountNameEnglish;
  final String accountType; // fixed | variable
  final double typicalAmount;
  final bool isActive;
  final String createdAt;

  const ExpenseAccount({
    this.id,
    required this.accountNameGujarati,
    this.accountNameEnglish,
    required this.accountType,
    required this.typicalAmount,
    required this.isActive,
    required this.createdAt,
  });

  factory ExpenseAccount.fromMap(Map<String, dynamic> map) {
    return ExpenseAccount(
      id: map['id'] as int?,
      accountNameGujarati: map['account_name_gujarati'] as String,
      accountNameEnglish: map['account_name_english'] as String?,
      accountType: (map['account_type'] as String?) ?? 'variable',
      typicalAmount: (map['typical_amount'] as num?)?.toDouble() ?? 0,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'account_name_gujarati': accountNameGujarati,
      'account_name_english': accountNameEnglish,
      'account_type': accountType,
      'typical_amount': typicalAmount,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
    };
  }
}
