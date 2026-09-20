class AppUser {
  final int? id;
  final String role; // superadmin | admin | employee
  final String displayName;
  final String pinHash; // SHA-256
  final bool isActive;
  final String? lastLogin;
  final String createdAt;

  const AppUser({
    this.id,
    required this.role,
    required this.displayName,
    required this.pinHash,
    required this.isActive,
    this.lastLogin,
    required this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as int?,
      role: map['role'] as String,
      displayName: map['display_name'] as String,
      pinHash: map['pin_hash'] as String,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      lastLogin: map['last_login'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'role': role,
      'display_name': displayName,
      'pin_hash': pinHash,
      'is_active': isActive ? 1 : 0,
      'last_login': lastLogin,
      'created_at': createdAt,
    };
  }
}
