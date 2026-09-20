class Category {
  final int? id;
  final String nameGujarati;
  final String? nameEnglish;
  final String? icon;
  final bool isActive;
  final String createdAt;

  const Category({
    this.id,
    required this.nameGujarati,
    this.nameEnglish,
    this.icon,
    required this.isActive,
    required this.createdAt,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      nameGujarati: map['name_gujarati'] as String,
      nameEnglish: map['name_english'] as String?,
      icon: map['icon'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name_gujarati': nameGujarati,
      'name_english': nameEnglish,
      'icon': icon,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
    };
  }
}
