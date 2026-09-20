import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/pin_utils.dart';

/// Secure PIN storage using flutter_secure_storage with SharedPreferences fallback
class PinStorageService {
  static const String defaultPin = '2401';
  static const _secureStorage = FlutterSecureStorage();

  const PinStorageService();

  String _getPinKey(String role) => '${role.toLowerCase()}_pin';

  // Get stored PIN hash for a role (migrates legacy SharedPreferences PINs transparently)
  Future<String> getPinHash(String role) async {
    final key = _getPinKey(role);
    String storedValue = '';

    try {
      storedValue = await _secureStorage.read(key: key) ?? '';
    } catch (_) {
      // Fallback for platform limitations
    }

    if (storedValue.isEmpty) {
      // Check legacy SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final legacyValue = prefs.getString(key) ?? '';
        if (legacyValue.isNotEmpty) {
          storedValue = legacyValue.length == 64
              ? legacyValue
              : PinUtils.hashPin(legacyValue);
          await setPinHash(role, storedValue);
          await prefs.remove(key);
          return storedValue;
        }
      } catch (_) {}
    }

    if (storedValue.isEmpty) {
      final defaultHash = PinUtils.hashPin(defaultPin);
      await setPinHash(role, defaultPin);
      return defaultHash;
    }

    if (storedValue.length != 64) {
      final migratedHash = PinUtils.hashPin(storedValue);
      await setPinHash(role, storedValue);
      return migratedHash;
    }

    return storedValue;
  }

  // Store PIN for a role (hashes PIN before storing)
  Future<void> setPinHash(String role, String pin) async {
    final normalizedPin = pin.trim();
    if (!PinUtils.isValidPin(normalizedPin) && normalizedPin.length != 64) {
      throw ArgumentError('PIN must be exactly ${PinUtils.pinLength} digits.');
    }

    final hash = normalizedPin.length == 64
        ? normalizedPin
        : PinUtils.hashPin(normalizedPin);

    final key = _getPinKey(role);
    try {
      await _secureStorage.write(key: key, value: hash);
    } catch (_) {
      // Fallback to SharedPreferences if secure storage fails
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, hash);
    }
  }

  // Verify PIN for a role
  Future<bool> verifyPin(String role, String pin) async {
    try {
      final enteredPin = pin.trim();
      if (!PinUtils.isValidPin(enteredPin)) {
        return false;
      }

      final storedHash = await getPinHash(role);
      return PinUtils.verifyPin(enteredPin, storedHash);
    } catch (_) {
      return false;
    }
  }

  // Check if PIN exists for a role
  Future<bool> pinExists(String role) async {
    final hash = await getPinHash(role);
    return hash.isNotEmpty;
  }

  // Initialize default PINs if not set
  Future<void> initializeDefaults() async {
    for (final role in ['admin', 'cashier']) {
      final hash = await getPinHash(role);
      if (hash.isEmpty) {
        await setPinHash(role, defaultPin);
      }
    }
  }

  // Delete PIN for a role
  Future<void> deletePin(String role) async {
    final key = _getPinKey(role);
    try {
      await _secureStorage.delete(key: key);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }
}
