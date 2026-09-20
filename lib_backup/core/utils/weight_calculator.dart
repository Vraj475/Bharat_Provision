class WeightCalculator {
  /// (amountPaid / sellPricePerKg) * 1000
  static double calculateWeightFromAmount({
    required double amountPaid,
    required double sellPricePerKg,
  }) {
    if (sellPricePerKg <= 0) {
      throw ArgumentError('sellPricePerKg must be greater than 0');
    }
    return (amountPaid / sellPricePerKg) * 1000.0;
  }

  /// (weightGrams / 1000) * sellPricePerKg
  static double calculateAmountFromWeight({
    required double weightGrams,
    required double sellPricePerKg,
  }) {
    return (weightGrams / 1000.0) * sellPricePerKg;
  }

  /// If grams < 1000 => 'XXX ગ્રામ'
  /// If grams >= 1000 => 'X.X કિલો'
  static String formatWeight(double grams) {
    if (grams < 1000.0) {
      return '${grams.toStringAsFixed(0)} ગ્રામ';
    }
    final kilos = grams / 1000.0;
    return '${kilos.toStringAsFixed(1)} કિલો';
  }

  /// (returnedGrams * returnedPrice) / replacementPrice
  static double calculateReplaceWeight({
    required double returnedGrams,
    required double returnedPrice,
    required double replacementPrice,
  }) {
    if (replacementPrice <= 0) {
      throw ArgumentError('replacementPrice must be greater than 0');
    }
    final value = (returnedGrams * returnedPrice) / replacementPrice;
    return value;
  }
}
