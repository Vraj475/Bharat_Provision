import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

import '../utils/pin_utils.dart';

/// Secure PIN storage using flutter_secure_storage
class PinStorageService {
  static const String defaultPin = '1234';
  static const String _superadminPinKey = 'pin_superadmin';
  static const String _adminPinKey = 'pin_admin';
  static const String _employeePinKey = 'pin_employee';

  final FlutterSecureStorage _storage;

  const PinStorageService(this._storage);

  static const List<String> _supportedRoles = [
    'superadmin',
    'admin',
    'employee',
  ];

  // Get stored PIN hash for a role
  Future<String?> getPinHash(String role) async {
    try {
      final key = _getPinKey(role);
      return await _storage.read(key: key);
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

    final key = _getPinKey(role);
    final hash = PinUtils.hashPin(pin);
    await _storage.write(key: key, value: hash);
  }

  // Verify PIN for a role
  Future<bool> verifyPin(String role, String pin) async {
    try {
      if (!PinUtils.isValidPin(pin)) {
        return false;
      }

      final storedHash = await getPinHash(role);
      if (storedHash == null) return false;
      return PinUtils.verifyPin(pin, storedHash);
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
    final key = _getPinKey(role);
    await _storage.delete(key: key);
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
