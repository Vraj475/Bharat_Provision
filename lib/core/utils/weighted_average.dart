/// Utility functions for weighted average cost calculation and pricing logic.
class WeightedAverageCalculator {
  WeightedAverageCalculator._();

  /// Calculates new weighted average cost price.
  /// Formula: `new_avg = (old_qty × old_avg + new_qty × new_cost) ÷ (old_qty + new_qty)`
  ///
  /// Edge cases:
  /// - If [oldQty] <= 0: The new cost becomes [newCost] directly (since there's no positive prior inventory).
  /// - If [newQty] <= 0: Returns [oldCost].
  /// - If both <= 0: Returns [newCost].
  static double calculateWeightedAverage({
    required double oldQty,
    required double oldCost,
    required double newQty,
    required double newCost,
  }) {
    if (newQty <= 0) return oldCost;
    if (oldQty <= 0) return double.parse(newCost.toStringAsFixed(2));

    final totalQty = oldQty + newQty;
    if (totalQty <= 0) return double.parse(newCost.toStringAsFixed(2));

    final totalValue = (oldQty * oldCost) + (newQty * newCost);
    final avgCost = totalValue / totalQty;
    return double.parse(avgCost.toStringAsFixed(2));
  }

  /// Calculates the percentage change from [oldCost] to [newCost].
  /// Returns 0.0 if [oldCost] <= 0.
  static double calculateCostChangePercentage({
    required double oldCost,
    required double newCost,
  }) {
    if (oldCost <= 0) return 0.0;
    final diff = newCost - oldCost;
    return (diff / oldCost) * 100;
  }

  /// Checks if the cost increased by at least [thresholdPercent] (defaults to 10.0%).
  static bool hasSignificantCostIncrease({
    required double oldCost,
    required double newCost,
    double thresholdPercent = 10.0,
  }) {
    if (oldCost <= 0) return false;
    final change = calculateCostChangePercentage(
      oldCost: oldCost,
      newCost: newCost,
    );
    return change >= thresholdPercent;
  }

  /// Suggests a new sell price maintaining the existing profit margin ratio:
  /// `suggested = newCost * (oldSell / oldCost)`
  /// If oldCost or oldSell is 0, defaults to a 20% margin (`newCost * 1.20`).
  static double suggestSellingPrice({
    required double oldCost,
    required double oldSell,
    required double newCost,
  }) {
    if (oldCost > 0 && oldSell > 0) {
      final marginRatio = oldSell / oldCost;
      final suggested = newCost * marginRatio;
      return double.parse(suggested.toStringAsFixed(2));
    }
    // Default 20% markup if previous prices were zero
    return double.parse((newCost * 1.20).toStringAsFixed(2));
  }
}
