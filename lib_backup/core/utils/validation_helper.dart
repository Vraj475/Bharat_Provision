import '../localization/app_strings.dart';

class ValidationHelper {
  /// Check if a product is available in required quantity
  static ValidationResult validateStockAvailability(
    double currentStock,
    double requiredQuantity,
  ) {
    if (currentStock < requiredQuantity) {
      return ValidationResult(
        isValid: false,
        errorMessage: AppStrings.insufficientStock,
        data: {'available': currentStock, 'required': requiredQuantity},
      );
    }

    if (currentStock == 0) {
      return ValidationResult(
        isValid: false,
        errorMessage: AppStrings.outOfStock,
      );
    }

    return ValidationResult(isValid: true);
  }

  /// Validate sell price is not zero
  static ValidationResult validateSellPrice(double sellPrice) {
    if (sellPrice <= 0) {
      return ValidationResult(
        isValid: false,
        errorMessage: AppStrings.zeroSellPrice,
      );
    }
    return ValidationResult(isValid: true);
  }

  /// Validate bill amount
  static ValidationResult validateBillAmount(double amount) {
    if (amount < 0) {
      return ValidationResult(
        isValid: false,
        errorMessage: AppStrings.invalidBillAmount,
      );
    }
    if (amount == 0) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'બીલ રકમ શૂન્ય હોઈ શકતી નથી.',
      );
    }
    return ValidationResult(isValid: true);
  }

  /// Validate return quantity doesn't exceed original purchase
  static ValidationResult validateReturnQuantity(
    double originalQuantity,
    double returnQuantity,
  ) {
    if (returnQuantity > originalQuantity) {
      return ValidationResult(
        isValid: false,
        errorMessage: AppStrings.returnQtyExceeded,
        data: {'original': originalQuantity, 'requestedReturn': returnQuantity},
      );
    }

    if (returnQuantity <= 0) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'રીટર્ન માત્રા શૂન્ય કરતા વધુ હોવી જોઈએ.',
      );
    }

    return ValidationResult(isValid: true);
  }

  /// Validate customer credit limit
  static ValidationResult validateCreditLimit(
    double creditLimit,
    double currentBalance,
    double newAmount,
  ) {
    final projectedBalance = currentBalance + newAmount;

    if (projectedBalance > creditLimit) {
      final overage = projectedBalance - creditLimit;
      return ValidationResult(
        isValid: false,
        errorMessage: AppStrings.creditLimitExceeded,
        warningMessage: 'આ ક્રેણ ₹$overage દ્વારા મર્યાદા પાર કરશે.',
        data: {
          'creditLimit': creditLimit,
          'currentBalance': currentBalance,
          'projectedBalance': projectedBalance,
          'overage': overage,
        },
      );
    }

    return ValidationResult(isValid: true);
  }

  /// Walk-in duplicate check
  static ValidationResult checkWalkInDuplicate(
    String name,
    List<String> existingNames,
  ) {
    if (existingNames.contains(name)) {
      return ValidationResult(
        isValid: false,
        warningMessage: AppStrings.walkInDuplicateMessage,
        errorMessage: AppStrings.walkInDuplicate,
        data: {'duplicateName': name},
      );
    }
    return ValidationResult(isValid: true);
  }

  /// Validate numeric input
  static ValidationResult validateNumericInput(String value, String fieldName) {
    if (value.isEmpty) {
      return ValidationResult(
        isValid: false,
        errorMessage: '$fieldName આવશ્યક છે.',
      );
    }

    final num = double.tryParse(value);
    if (num == null) {
      return ValidationResult(
        isValid: false,
        errorMessage: '$fieldName માન્ય સંખ્યા હોવી જોઈએ.',
      );
    }

    return ValidationResult(isValid: true);
  }

  /// Validate text input
  static ValidationResult validateTextInput(
    String value,
    String fieldName, {
    int minLength = 1,
    int maxLength = 255,
  }) {
    if (value.isEmpty) {
      return ValidationResult(
        isValid: false,
        errorMessage: '$fieldName આવશ્યક છે.',
      );
    }

    if (value.length < minLength) {
      return ValidationResult(
        isValid: false,
        errorMessage: '$fieldName ઓછામાં ઓછા $minLength અક્ષર હોવા જોઈએ.',
      );
    }

    if (value.length > maxLength) {
      return ValidationResult(
        isValid: false,
        errorMessage: '$fieldName વધુમાં વધુ $maxLength અક્ષર હોઈ શકે.',
      );
    }

    return ValidationResult(isValid: true);
  }
}

/// Validation result class
class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? warningMessage;
  final Map<String, dynamic> data;

  ValidationResult({
    required this.isValid,
    this.errorMessage,
    this.warningMessage,
    this.data = const {},
  });

  bool get hasWarning => warningMessage != null && warningMessage!.isNotEmpty;
}
