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

  /// Parses raw weight input in provision store format.
  /// - '0.50' or '.50' strictly represents 50 grams (0.050 kg).
  /// - '0.5' or '.5' defaults to 50 grams unless the 500g suggestion is explicitly accepted (via Right Arrow key).
  /// - Standard decimal values like '1' (1000g), '1.5' (1500g), '0.500' (500g), '0.25' (250g) parse to kg * 1000.
  static double parseWeightInputGrams(
    String raw, {
    bool suggestionAccepted = false,
  }) {
    final clean = raw.trim();
    if (clean.isEmpty) return 0.0;

    // Grocery store shorthand: 0.50 represents 50 grams
    if (clean == '0.50' || clean == '.50') {
      return 50.0;
    }

    // 0.5 defaults to 50g unless suggestion of 500 was accepted via Right Arrow
    if (clean == '0.5' || clean == '.5') {
      return suggestionAccepted ? 500.0 : 50.0;
    }

    final parsed = double.tryParse(clean);
    if (parsed == null || parsed <= 0) return 0.0;
    return parsed * 1000.0;
  }
}
