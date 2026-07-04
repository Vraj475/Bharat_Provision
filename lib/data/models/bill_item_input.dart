class BillItemInput {
  BillItemInput({
    required this.itemId,
    required this.quantity,
    required this.unitPrice,
  });

  final int itemId;
  final double quantity;
  final double unitPrice;
}