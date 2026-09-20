/// Represents the different categories of errors in the app
enum ErrorCategory {
  database,
  printing,
  calculation,
  network,
  authentication,
  validation,
  storage,
  unknown,
}

/// Main error class that encapsulates all error information
class AppError {
  final String code;
  final ErrorCategory category;
  final String technicalMessage;
  final String userMessage;
  final bool isCritical;
  final DateTime timestamp;
  final StackTrace? stackTrace;

  AppError({
    required this.code,
    required this.category,
    required this.technicalMessage,
    required this.userMessage,
    required this.isCritical,
    required this.timestamp,
    this.stackTrace,
  });

  /// Creates a copy of this error with optional field overrides
  AppError copyWith({
    String? code,
    ErrorCategory? category,
    String? technicalMessage,
    String? userMessage,
    bool? isCritical,
    DateTime? timestamp,
    StackTrace? stackTrace,
  }) {
    return AppError(
      code: code ?? this.code,
      category: category ?? this.category,
      technicalMessage: technicalMessage ?? this.technicalMessage,
      userMessage: userMessage ?? this.userMessage,
      isCritical: isCritical ?? this.isCritical,
      timestamp: timestamp ?? this.timestamp,
      stackTrace: stackTrace ?? this.stackTrace,
    );
  }

  @override
  String toString() {
    return 'AppError(code: $code, category: $category, userMessage: $userMessage, isCritical: $isCritical)';
  }
}
