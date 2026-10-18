import 'package:bharat_provision/core/utils/weighted_average.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WeightedAverageCalculator Tests', () {
    test('Calculates standard weighted average correctly with equal quantities', () {
      // 10 units @ 50 + 10 units @ 60 = 20 units @ 55
      final avg = WeightedAverageCalculator.calculateWeightedAverage(
        oldQty: 10,
        oldCost: 50,
        newQty: 10,
        newCost: 60,
      );
      expect(avg, 55.0);
    });

    test('Calculates standard weighted average correctly with unequal quantities', () {
      // 10 units @ 50 + 20 units @ 65 = 30 units @ 60
      final avg = WeightedAverageCalculator.calculateWeightedAverage(
        oldQty: 10,
        oldCost: 50,
        newQty: 20,
        newCost: 65,
      );
      expect(avg, 60.0);
    });

    test('Handles zero old stock: new cost becomes new average', () {
      final avg = WeightedAverageCalculator.calculateWeightedAverage(
        oldQty: 0,
        oldCost: 50,
        newQty: 15,
        newCost: 75,
      );
      expect(avg, 75.0);
    });

    test('Handles negative old stock: new cost becomes new average', () {
      final avg = WeightedAverageCalculator.calculateWeightedAverage(
        oldQty: -3,
        oldCost: 50,
        newQty: 10,
        newCost: 80,
      );
      expect(avg, 80.0);
    });

    test('Handles zero new qty: returns old cost', () {
      final avg = WeightedAverageCalculator.calculateWeightedAverage(
        oldQty: 10,
        oldCost: 50,
        newQty: 0,
        newCost: 80,
      );
      expect(avg, 50.0);
    });

    test('Calculates cost percentage increase correctly', () {
      final pct = WeightedAverageCalculator.calculateCostChangePercentage(
        oldCost: 100,
        newCost: 115,
      );
      expect(pct, closeTo(15.0, 0.001));
    });

    test('Identifies significant cost increase >= 10%', () {
      // 9% increase -> false
      expect(
        WeightedAverageCalculator.hasSignificantCostIncrease(
          oldCost: 100,
          newCost: 109,
        ),
        isFalse,
      );

      // 10% increase -> true
      expect(
        WeightedAverageCalculator.hasSignificantCostIncrease(
          oldCost: 100,
          newCost: 110,
        ),
        isTrue,
      );

      // 15% increase -> true
      expect(
        WeightedAverageCalculator.hasSignificantCostIncrease(
          oldCost: 100,
          newCost: 115,
        ),
        isTrue,
      );
    });

    test('Suggests selling price preserving margin ratio', () {
      // Old cost = 80, Old sell = 100 (1.25x margin)
      // New cost = 100 -> Suggested sell = 125
      final suggested = WeightedAverageCalculator.suggestSellingPrice(
        oldCost: 80,
        oldSell: 100,
        newCost: 100,
      );
      expect(suggested, 125.0);
    });

    test('Suggests 20% margin if old prices were zero', () {
      final suggested = WeightedAverageCalculator.suggestSellingPrice(
        oldCost: 0,
        oldSell: 0,
        newCost: 50,
      );
      expect(suggested, 60.0);
    });
  });
}
