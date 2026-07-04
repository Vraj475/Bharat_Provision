class Customer {
  final int? id;
  final String nameGujarati;
  final String? nameEnglish;
  final String? phone;
  final String? address;
  final String accountType; // regular | walkin
  final double creditLimit;
  final double totalOutstanding;
  final bool isActive;
  final String createdAt;

  const Customer({
    this.id,
    required this.nameGujarati,
    this.nameEnglish,
    this.phone,
    this.address,
    required this.accountType,
    required this.creditLimit,
    required this.totalOutstanding,
    required this.isActive,
    required this.createdAt,
  });

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      nameGujarati: map['name_gujarati'] as String,
      nameEnglish: map['name_english'] as String?,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      accountType: (map['account_type'] as String?) ?? 'regular',
      creditLimit: (map['credit_limit'] as num?)?.toDouble() ?? 2000,
      totalOutstanding: (map['total_outstanding'] as num?)?.toDouble() ?? 0,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name_gujarati': nameGujarati,
      'name_english': nameEnglish,
      'phone': phone,
      'address': address,
      'account_type': accountType,
      'credit_limit': creditLimit,
      'total_outstanding': totalOutstanding,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
    };
  }
}
