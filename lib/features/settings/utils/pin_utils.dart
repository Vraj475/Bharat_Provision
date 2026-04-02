import 'package:crypto/crypto.dart';
import 'dart:convert';

/// PIN hashing and verification utility
class PinUtils {
  static const int pinLength = 4;

  // Hash PIN using SHA-256
  static String hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  // Verify PIN against hash
  static bool verifyPin(String pin, String hash) {
    return hashPin(pin) == hash;
  }

  // Validate PIN format (exactly 4 numeric digits).
  static bool isValidPin(String pin) {
    if (pin.isEmpty) return false;
    if (!RegExp(r'^\d+$').hasMatch(pin)) return false;
    return pin.length == pinLength;
  }

  // Generate hash for storing in secure storage
  static String generateSecurePin(String pin) {
    return hashPin(pin);
  }
}
