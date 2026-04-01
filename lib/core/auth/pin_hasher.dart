import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

class PinHasher {
  static String sha256(String pin) {
    final bytes = utf8.encode(pin);
    return cryptoSha256(bytes);
  }

  static String cryptoSha256(List<int> bytes) {
    return crypto.sha256.convert(bytes).toString();
  }

  // Alias for sha256 - used for consistent naming
  static String hashPin(String pin) {
    return sha256(pin);
  }
}
