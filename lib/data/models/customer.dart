class Customer {
  final int? id;
  final String name;
  final String? phone;
  final String? address;
  final String? note;

  const Customer({
    this.id,
    required this.name,
    this.phone,
    this.address,
    this.note,
  });

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      name: (map['name'] ?? map['name_gujarati'] ?? '') as String,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      note: map['note'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'note': note,
    };
  }

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? address,
    String? note,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      note: note ?? this.note,
    );
  }
}
