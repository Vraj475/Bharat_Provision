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
    this.isActive = true,
    required this.createdAt,
  });

  String get nameGu => nameGujarati;
  String? get colorCode => icon;

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      nameGujarati: (map['name_gujarati'] ?? map['name_gu'] ?? '') as String,
      nameEnglish: map['name_english'] as String?,
      icon: (map['icon'] ?? map['color_code']) as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
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

  Category copyWith({
    int? id,
    String? nameGujarati,
    String? nameEnglish,
    String? icon,
    bool? isActive,
    String? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      nameGujarati: nameGujarati ?? this.nameGujarati,
      nameEnglish: nameEnglish ?? this.nameEnglish,
      icon: icon ?? this.icon,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
