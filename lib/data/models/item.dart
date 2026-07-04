class Item {
  final int? id;
  final String nameGu;
  final int? categoryId;
  final String? barcode;
  final String unit;
  final double salePrice;
  final double purchasePrice;
  final double currentStock;
  final double lowStockThreshold;
  final bool isActive;

  const Item({
    this.id,
    required this.nameGu,
    this.categoryId,
    this.barcode,
    required this.unit,
    required this.salePrice,
    required this.purchasePrice,
    required this.currentStock,
    required this.lowStockThreshold,
    required this.isActive,
  });

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'] as int?,
      nameGu: (map['name_gu'] ?? map['name_gujarati'] ?? '') as String,
      categoryId: map['category_id'] as int?,
      barcode: map['barcode'] as String?,
      unit: (map['unit'] ?? map['unit_type']) as String? ?? 'નંગ',
      salePrice:
          ((map['sale_price'] ?? map['sell_price']) as num?)?.toDouble() ?? 0,
      purchasePrice:
          ((map['purchase_price'] ?? map['buy_price']) as num?)?.toDouble() ??
          0,
      currentStock:
          ((map['current_stock'] ?? map['stock_qty']) as num?)?.toDouble() ?? 0,
      lowStockThreshold:
          ((map['low_stock_threshold'] ?? map['min_stock_qty']) as num?)
              ?.toDouble() ??
          0,
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name_gu': nameGu,
      'category_id': categoryId,
      'barcode': barcode,
      'unit': unit,
      'sale_price': salePrice,
      'purchase_price': purchasePrice,
      'current_stock': currentStock,
      'low_stock_threshold': lowStockThreshold,
      'is_active': isActive ? 1 : 0,
    };
  }

  Item copyWith({
    int? id,
    String? nameGu,
    int? categoryId,
    String? barcode,
    String? unit,
    double? salePrice,
    double? purchasePrice,
    double? currentStock,
    double? lowStockThreshold,
    bool? isActive,
  }) {
    return Item(
      id: id ?? this.id,
      nameGu: nameGu ?? this.nameGu,
      categoryId: categoryId ?? this.categoryId,
      barcode: barcode ?? this.barcode,
      unit: unit ?? this.unit,
      salePrice: salePrice ?? this.salePrice,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      currentStock: currentStock ?? this.currentStock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      isActive: isActive ?? this.isActive,
    );
  }

  bool get isLowStock => currentStock <= lowStockThreshold;
}
