import 'purchase_item_model.dart';

class Purchase {
  final int? id;
  final String purchaseNo;
  final String purchaseDate;
  final String? supplierName;
  final String? supplierPhone;
  final double totalAmount;
  final double paidAmount;
  final String paymentMode;
  final String? notes;
  final String createdAt;
  final List<PurchaseItem>? items;

  const Purchase({
    this.id,
    required this.purchaseNo,
    required this.purchaseDate,
    this.supplierName,
    this.supplierPhone,
    required this.totalAmount,
    this.paidAmount = 0,
    this.paymentMode = 'cash',
    this.notes,
    required this.createdAt,
    this.items,
  });

  factory Purchase.fromMap(Map<String, dynamic> map, [List<PurchaseItem>? items]) {
    return Purchase(
      id: map['id'] as int?,
      purchaseNo: map['purchase_no'] as String,
      purchaseDate: map['purchase_date'] as String,
      supplierName: map['supplier_name'] as String?,
      supplierPhone: map['supplier_phone'] as String?,
      totalAmount: (map['total_amount'] as num).toDouble(),
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0,
      paymentMode: (map['payment_mode'] as String?) ?? 'cash',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
      items: items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'purchase_no': purchaseNo,
      'purchase_date': purchaseDate,
      'supplier_name': supplierName,
      'supplier_phone': supplierPhone,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'payment_mode': paymentMode,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  Purchase copyWith({
    int? id,
    String? purchaseNo,
    String? purchaseDate,
    String? supplierName,
    String? supplierPhone,
    double? totalAmount,
    double? paidAmount,
    String? paymentMode,
    String? notes,
    String? createdAt,
    List<PurchaseItem>? items,
  }) {
    return Purchase(
      id: id ?? this.id,
      purchaseNo: purchaseNo ?? this.purchaseNo,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      supplierName: supplierName ?? this.supplierName,
      supplierPhone: supplierPhone ?? this.supplierPhone,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      paymentMode: paymentMode ?? this.paymentMode,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }
}
