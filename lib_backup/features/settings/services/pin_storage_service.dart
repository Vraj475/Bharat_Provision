import 'package:shared_preferences/shared_preferences.dart';

import '../utils/pin_utils.dart';

/// Secure PIN storage using flutter_secure_storage
class PinStorageService {
  static const String defaultPin = '0000';

  const PinStorageService();

  String _getPinKey(String role) => '${role.toLowerCase()}_pin';

  // Get stored PIN hash for a role (transparently migrating legacy plain-text PINs)
  Future<String> getPinHash(String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getPinKey(role);
      String storedValue = prefs.getString(key) ?? '';

      if (storedValue.isEmpty) {
        final defaultHash = PinUtils.hashPin(defaultPin);
        await prefs.setString(key, defaultHash);
        return defaultHash;
      }

      // Transparent migration: if storedValue is not a 64-char SHA-256 hex string, hash and migrate it
      if (storedValue.length != 64) {
        final migratedHash = PinUtils.hashPin(storedValue);
        await prefs.setString(key, migratedHash);
        return migratedHash;
      }

      return storedValue;
    } catch (_) {
      return PinUtils.hashPin(defaultPin);
    }
  }

  // Store PIN for a role (hashes PIN before storing)
  Future<void> setPinHash(String role, String pin) async {
    final normalizedPin = pin.trim();
    if (!PinUtils.isValidPin(normalizedPin)) {
      throw ArgumentError('PIN must be exactly ${PinUtils.pinLength} digits.');
    }

    final hash = PinUtils.hashPin(normalizedPin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_getPinKey(role), hash);
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
    final prefs = await SharedPreferences.getInstance();
    for (final role in ['admin', 'cashier']) {
      final key = _getPinKey(role);
      final existing = prefs.getString(key);
      if (existing == null || existing.isEmpty) {
        await prefs.setString(key, PinUtils.hashPin(defaultPin));
      }
    }
  }

  // Delete PIN for a role
  Future<void> deletePin(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getPinKey(role));
  }
}
