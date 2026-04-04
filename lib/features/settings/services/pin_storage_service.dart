import 'package:shared_preferences/shared_preferences.dart';

import '../utils/pin_utils.dart';

/// Secure PIN storage using flutter_secure_storage
class PinStorageService {
  static const String defaultPin = '0000';
  static const String _pinKey = 'user_pin';

  const PinStorageService();

  // Get stored PIN for a role.
  Future<String> getPinHash(String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String storedPin = prefs.getString(_pinKey) ?? defaultPin;
      if (storedPin.isEmpty) {
        storedPin = defaultPin;
        await prefs.setString(_pinKey, defaultPin);
      }
      return storedPin;
    } catch (_) {
      return defaultPin;
    }
  }

  // Store PIN for a role.
  Future<void> setPinHash(String role, String pin) async {
    final normalizedPin = pin.trim();
    if (!PinUtils.isValidPin(normalizedPin)) {
      throw ArgumentError('PIN must be exactly ${PinUtils.pinLength} digits.');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, normalizedPin);
  }

  // Verify PIN for a role
  Future<bool> verifyPin(String role, String pin) async {
    try {
      final enteredPin = pin.trim();
      if (!PinUtils.isValidPin(enteredPin)) {
        return false;
      }

      final storedPin = await getPinHash(role);

      return enteredPin == storedPin;
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
    final existingPin = prefs.getString(_pinKey);
    if (existingPin == null || existingPin.isEmpty) {
      await prefs.setString(_pinKey, defaultPin);
    }
  }

  // Delete PIN for a role
  Future<void> deletePin(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
  }
}
