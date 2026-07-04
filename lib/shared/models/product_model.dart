class Product {
  final int? id;
  final String nameGujarati;
  final String? nameEnglish;
  final String transliterationKeys;
  final int? categoryId;

  /// P02: 'weight_kg' | 'weight_gram' | 'count' | 'litre'
  final String unitType;
  final double buyPrice;
  final double sellPrice;
  final double stockQty;
  final double minStockQty;
  final bool isActive;
  final String? barcode;
  final String? createdAt;
  final String? updatedAt;

  const Product({
    this.id,
    required this.nameGujarati,
    this.nameEnglish,
    required this.transliterationKeys,
    this.categoryId,
    required this.unitType,
    required this.buyPrice,
    required this.sellPrice,
    required this.stockQty,
    required this.minStockQty,
    required this.isActive,
    this.barcode,
    this.createdAt,
    this.updatedAt,
  });

  Product copyWith({
    int? id,
    String? nameGujarati,
    String? nameEnglish,
    String? transliterationKeys,
    int? categoryId,
    String? unitType,
    double? buyPrice,
    double? sellPrice,
    double? stockQty,
    double? minStockQty,
    bool? isActive,
    String? barcode,
    String? createdAt,
    String? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      nameGujarati: nameGujarati ?? this.nameGujarati,
      nameEnglish: nameEnglish ?? this.nameEnglish,
      transliterationKeys: transliterationKeys ?? this.transliterationKeys,
      categoryId: categoryId ?? this.categoryId,
      unitType: unitType ?? this.unitType,
      buyPrice: buyPrice ?? this.buyPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      stockQty: stockQty ?? this.stockQty,
      minStockQty: minStockQty ?? this.minStockQty,
      isActive: isActive ?? this.isActive,
      barcode: barcode ?? this.barcode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      nameGujarati: map['name_gujarati'] as String,
      nameEnglish: map['name_english'] as String?,
      transliterationKeys: map['transliteration_keys'] as String? ?? '',
      categoryId: map['category_id'] as int?,
      unitType: map['unit_type'] as String? ?? '',
      buyPrice: (map['buy_price'] as num?)?.toDouble() ?? 0,
      sellPrice: (map['sell_price'] as num?)?.toDouble() ?? 0,
      stockQty: (map['stock_qty'] as num?)?.toDouble() ?? 0,
      minStockQty: (map['min_stock_qty'] as num?)?.toDouble() ?? 0,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      barcode: map['barcode'] as String?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name_gujarati': nameGujarati,
      'name_english': nameEnglish,
      'transliteration_keys': transliterationKeys,
      'category_id': categoryId,
      'unit_type': unitType,
      'buy_price': buyPrice,
      'sell_price': sellPrice,
      'stock_qty': stockQty,
      'min_stock_qty': minStockQty,
      'is_active': isActive ? 1 : 0,
      'barcode': barcode,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }
}
