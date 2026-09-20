/// Indian numbering system: ₹1,23,456.00 (lakhs, crores)
String formatCurrency(double amount) {
  if (amount.isNaN || amount.isInfinite) return '₹0.00';
  final parts = amount.abs().toStringAsFixed(2).split('.');
  final intPart = parts[0];
  final decPart = parts[1];

  String formatted;
  if (intPart.length <= 3) {
    formatted = intPart;
  } else {
    final last3 = intPart.substring(intPart.length - 3);
    final rest = intPart.substring(0, intPart.length - 3);
    final groups = <String>[];
    for (var i = rest.length; i > 0; i -= 2) {
      final start = i > 2 ? i - 2 : 0;
      groups.insert(0, rest.substring(start, i));
    }
    formatted = '${groups.join(',')},$last3';
  }
  return '₹${amount < 0 ? '-' : ''}$formatted.$decPart';
}
