import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_models.dart';
import '../services/pin_storage_service.dart';

// PIN storage service provider
final pinStorageProvider = Provider<PinStorageService>((ref) {
  return const PinStorageService();
});

// Current auth session provider (StateNotifier)
final authSessionProvider =
    StateNotifierProvider<AuthSessionNotifier, AuthSession?>(
      (ref) => AuthSessionNotifier(),
    );

class AuthSessionNotifier extends StateNotifier<AuthSession?> {
  AuthSessionNotifier() : super(null);

  static const String _sessionRoleKey = 'auth_session_role';
  static const String _sessionTimeoutKey = 'auth_session_timeout_minutes';
  static const String _sessionRequirePinOnOpenKey =
      'auth_session_require_pin_on_open';

  void setSession(
    String role, {
    int timeoutMinutes = 5,
    bool requirePinOnOpen = false,
  }) {
    state = AuthSession(
      role: role,
      loginTime: DateTime.now(),
      sessionTimeoutMinutes: timeoutMinutes,
      requirePinOnOpen: requirePinOnOpen,
    );
    unawaited(
      _persistSessionMeta(
        role: role,
        timeoutMinutes: timeoutMinutes,
        requirePinOnOpen: requirePinOnOpen,
      ),
    );
  }

  void updateSessionTimeout(int timeoutMinutes) {
    if (state != null) {
      state = state!.copyWith(sessionTimeoutMinutes: timeoutMinutes);
    }
  }

  void updateRequirePinOnOpen(bool value) {
    if (state != null) {
      state = state!.copyWith(requirePinOnOpen: value);
    }
  }

  void logout() {
    state = null;
    unawaited(_clearPersistedSessionMeta());
  }

  bool get isSessionExpired => state == null || state!.isExpired;

  bool get isSessionActive => !isSessionExpired;

  Future<void> _persistSessionMeta({
    required String role,
    required int timeoutMinutes,
    required bool requirePinOnOpen,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionRoleKey, role);
      await prefs.setInt(_sessionTimeoutKey, timeoutMinutes);
      await prefs.setBool(_sessionRequirePinOnOpenKey, requirePinOnOpen);
    } catch (_) {
      return;
    }
  }

  Future<void> _clearPersistedSessionMeta() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionRoleKey);
      await prefs.remove(_sessionTimeoutKey);
      await prefs.remove(_sessionRequirePinOnOpenKey);
    } catch (_) {
      return;
    }
  }
}

// PIN attempt tracking provider (StateNotifier)
final pinAttemptProvider =
    StateNotifierProvider<PinAttemptNotifier, PinAttempt>(
      (ref) => PinAttemptNotifier(),
    );

class PinAttemptNotifier extends StateNotifier<PinAttempt> {
  PinAttemptNotifier() : super(PinAttempt());

  void incrementFailure() {
    state = state.incrementFailure();
  }

  void reset() {
    state = state.reset();
  }

  bool get isLocked => state.isLocked;

  int get failureCount => state.failureCount;

  int get remainingLockSeconds => state.remainingLockSeconds;
}

// Validate PIN provider
final validatePinProvider = FutureProvider.family<bool, (String, String)>((
  ref,
  params,
) async {
  final pinStorage = ref.watch(pinStorageProvider);
  final (role, pin) = params;
  return await pinStorage.verifyPin(role, pin);
});

// Check if PIN is set for a role
final pinExistsProvider = FutureProvider.family<bool, String>((
  ref,
  role,
) async {
  final pinStorage = ref.watch(pinStorageProvider);
  return await pinStorage.pinExists(role);
});

// Initialize PINs provider
final initializePinsProvider = FutureProvider<void>((ref) async {
  final pinStorage = ref.watch(pinStorageProvider);
  await pinStorage.initializeDefaults();
});

// Set new PIN provider
final setPinProvider = FutureProvider.family<void, (String, String)>((
  ref,
  params,
) async {
  final pinStorage = ref.watch(pinStorageProvider);
  final (role, pin) = params;
  await pinStorage.setPinHash(role, pin);
});

// Session timeout minutes provider
final sessionTimeoutProvider = StateProvider<int>((ref) => 5);

// Require PIN on app open provider
final requirePinOnOpenProvider = StateProvider<bool>((ref) => false);
