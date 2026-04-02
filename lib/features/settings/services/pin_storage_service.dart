import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/pin_utils.dart';

/// Secure PIN storage using flutter_secure_storage
class PinStorageService {
  static const String defaultPin = '0000';
  static const String _superadminPinKey = 'pin_superadmin';
  static const String _adminPinKey = 'pin_admin';
  static const String _employeePinKey = 'pin_employee';

  const PinStorageService();

  static const List<String> _supportedRoles = [
    'superadmin',
    'admin',
    'employee',
  ];

  // Get stored PIN hash for a role
  Future<String?> getPinHash(String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_getPinKey(role));
    } catch (e, stack) {
      debugPrint('PinStorageService.getPinHash failed: $e');
      debugPrintStack(stackTrace: stack);
      return null;
    }
  }

  // Store PIN hash for a role
  Future<void> setPinHash(String role, String pin) async {
    if (!PinUtils.isValidPin(pin)) {
      throw ArgumentError('PIN must be exactly ${PinUtils.pinLength} digits.');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_getPinKey(role), pin);
  }

  // Verify PIN for a role
  Future<bool> verifyPin(String role, String pin) async {
    try {
      if (!PinUtils.isValidPin(pin)) {
        return false;
      }

      final storedPin = await getPinHash(role);
      debugPrint('Entered PIN: $pin');
      debugPrint('Stored PIN: $storedPin');

      if (storedPin == null || storedPin.isEmpty) {
        return false;
      }

      return pin == storedPin;
    } catch (e, stack) {
      debugPrint('PinStorageService.verifyPin failed: $e');
      debugPrintStack(stackTrace: stack);
      return false;
    }
  }

  // Check if PIN exists for a role
  Future<bool> pinExists(String role) async {
    final hash = await getPinHash(role);
    return hash != null && hash.isNotEmpty;
  }

  // Initialize default PINs if not set
  Future<void> initializeDefaults() async {
    for (final role in _supportedRoles) {
      if (!await pinExists(role)) {
        await setPinHash(role, defaultPin);
      }
    }
  }

  // Delete PIN for a role
  Future<void> deletePin(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getPinKey(role));
  }

  String _getPinKey(String role) {
    switch (role) {
      case 'superadmin':
        return _superadminPinKey;
      case 'admin':
        return _adminPinKey;
      case 'employee':
        return _employeePinKey;
      default:
        throw ArgumentError('Invalid role: $role');
    }
  }
}
