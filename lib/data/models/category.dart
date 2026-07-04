class Category {
  final int? id;
  final String nameGu;
  final String? colorCode;

  const Category({this.id, required this.nameGu, this.colorCode});

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      nameGu: (map['name_gu'] ?? map['name_gujarati'] ?? '') as String,
      colorCode: (map['color_code'] ?? map['icon']) as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name_gu': nameGu,
      'color_code': colorCode,
    };
  }

  Category copyWith({int? id, String? nameGu, String? colorCode}) {
    return Category(
      id: id ?? this.id,
      nameGu: nameGu ?? this.nameGu,
      colorCode: colorCode ?? this.colorCode,
    );
  }
}
