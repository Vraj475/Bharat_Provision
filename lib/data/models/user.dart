class User {
  final int? id;
  final String name;
  final String pin;
  final String role; // 'owner' | 'staff'
  final bool isActive;

  const User({
    this.id,
    required this.name,
    required this.pin,
    required this.role,
    required this.isActive,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      name: (map['name'] ?? map['display_name'] ?? '') as String,
      pin: (map['pin'] ?? map['pin_hash']) as String? ?? '',
      role: map['role'] as String? ?? 'staff',
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'pin': pin,
      'role': role,
      'is_active': isActive ? 1 : 0,
    };
  }

  bool get isOwner => role == 'owner';
}
