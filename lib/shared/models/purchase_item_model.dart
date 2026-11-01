class PurchaseItem {
  final int? id;
  final int? purchaseId;
  final int productId;
  final double qty;
  final double unitCost;
  final double totalCost;
  final double oldStockQty;
  final double oldCostPrice;
  final double newCostPrice;
  final double oldSellPrice;
  final double newSellPrice;

  // Joined display fields (optional)
  final String? productNameGujarati;
  final String? productNameEnglish;
  final String? unit;

  const PurchaseItem({
    this.id,
    this.purchaseId,
    required this.productId,
    required this.qty,
    required this.unitCost,
    required this.totalCost,
    required this.oldStockQty,
    required this.oldCostPrice,
    required this.newCostPrice,
    required this.oldSellPrice,
    required this.newSellPrice,
    this.productNameGujarati,
    this.productNameEnglish,
    this.unit,
  });

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      id: map['id'] as int?,
      purchaseId: map['purchase_id'] as int?,
      productId: (map['product_id'] as int?) ?? 0,
      qty: (map['qty'] as num?)?.toDouble() ?? 0.0,
      unitCost: (map['unit_cost'] as num?)?.toDouble() ?? 0.0,
      totalCost: (map['total_cost'] as num?)?.toDouble() ?? 0.0,
      oldStockQty: (map['old_stock_qty'] as num?)?.toDouble() ?? 0.0,
      oldCostPrice: (map['old_cost_price'] as num?)?.toDouble() ?? 0.0,
      newCostPrice: (map['new_cost_price'] as num?)?.toDouble() ?? 0.0,
      oldSellPrice: (map['old_sell_price'] as num?)?.toDouble() ?? 0.0,
      newSellPrice: (map['new_sell_price'] as num?)?.toDouble() ?? 0.0,
      productNameGujarati: map['name_gujarati'] as String?,
      productNameEnglish: map['name_english'] as String?,
      unit: map['unit'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (purchaseId != null) 'purchase_id': purchaseId,
      'product_id': productId,
      'qty': qty,
      'unit_cost': unitCost,
      'total_cost': totalCost,
      'old_stock_qty': oldStockQty,
      'old_cost_price': oldCostPrice,
      'new_cost_price': newCostPrice,
      'old_sell_price': oldSellPrice,
      'new_sell_price': newSellPrice,
    };
  }

  PurchaseItem copyWith({
    int? id,
    int? purchaseId,
    int? productId,
    double? qty,
    double? unitCost,
    double? totalCost,
    double? oldStockQty,
    double? oldCostPrice,
    double? newCostPrice,
    double? oldSellPrice,
    double? newSellPrice,
    String? productNameGujarati,
    String? productNameEnglish,
    String? unit,
  }) {
    return PurchaseItem(
      id: id ?? this.id,
      purchaseId: purchaseId ?? this.purchaseId,
      productId: productId ?? this.productId,
      qty: qty ?? this.qty,
      unitCost: unitCost ?? this.unitCost,
      totalCost: totalCost ?? this.totalCost,
      oldStockQty: oldStockQty ?? this.oldStockQty,
      oldCostPrice: oldCostPrice ?? this.oldCostPrice,
      newCostPrice: newCostPrice ?? this.newCostPrice,
      oldSellPrice: oldSellPrice ?? this.oldSellPrice,
      newSellPrice: newSellPrice ?? this.newSellPrice,
      productNameGujarati: productNameGujarati ?? this.productNameGujarati,
      productNameEnglish: productNameEnglish ?? this.productNameEnglish,
      unit: unit ?? this.unit,
    );
  }
}
