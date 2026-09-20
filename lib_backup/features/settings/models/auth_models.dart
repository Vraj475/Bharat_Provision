// Authentication models for PIN-based access control

class AuthSession {
  final String role; // 'superadmin', 'admin', 'employee'
  final DateTime loginTime;
  final int sessionTimeoutMinutes;
  final bool requirePinOnOpen;

  AuthSession({
    required this.role,
    required this.loginTime,
    this.sessionTimeoutMinutes = 5,
    this.requirePinOnOpen = false,
  });

  bool get isExpired {
    final elapsed = DateTime.now().difference(loginTime).inMinutes;
    return elapsed > sessionTimeoutMinutes;
  }

  AuthSession copyWith({
    String? role,
    DateTime? loginTime,
    int? sessionTimeoutMinutes,
    bool? requirePinOnOpen,
  }) {
    return AuthSession(
      role: role ?? this.role,
      loginTime: loginTime ?? this.loginTime,
      sessionTimeoutMinutes:
          sessionTimeoutMinutes ?? this.sessionTimeoutMinutes,
      requirePinOnOpen: requirePinOnOpen ?? this.requirePinOnOpen,
    );
  }
}

class PinAttempt {
  final int failureCount;
  final DateTime? lockedUntil;

  PinAttempt({this.failureCount = 0, this.lockedUntil});

  bool get isLocked {
    if (lockedUntil == null) return false;
    return DateTime.now().isBefore(lockedUntil!);
  }

  int get remainingLockSeconds {
    if (!isLocked) return 0;
    return lockedUntil!.difference(DateTime.now()).inSeconds;
  }

  PinAttempt incrementFailure() {
    final newCount = failureCount + 1;
    if (newCount >= 3) {
      // Lock for 30 seconds
      return PinAttempt(
        failureCount: newCount,
        lockedUntil: DateTime.now().add(const Duration(seconds: 30)),
      );
    }
    return PinAttempt(failureCount: newCount);
  }

  PinAttempt reset() {
    return PinAttempt(failureCount: 0);
  }

  PinAttempt copyWith({int? failureCount, DateTime? lockedUntil}) {
    return PinAttempt(
      failureCount: failureCount ?? this.failureCount,
      lockedUntil: lockedUntil ?? this.lockedUntil,
    );
  }
}
