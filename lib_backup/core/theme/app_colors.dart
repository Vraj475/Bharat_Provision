import 'package:flutter/material.dart';

/// Color palette for Kirana Shop: green=good, orange=warning, red=alert
class AppColors {
  AppColors._();

  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color alert = Color(0xFFEF4444); // Red 500
  static const Color divider = Color(0xFFE2E8F0); // Slate 200

  static const Color primary = Color(0xFF4F46E5); // Indigo 600
  static const Color primaryLight = Color(0xFF6366F1); // Indigo 500
  static const Color primaryDark = Color(0xFF3730A3); // Indigo 800
  static const Color primarySurface = Color(0xFFE0E7FF); // Indigo 100

  // Neo-Brutalism specific accents
  static const Color accentYellow = Color(0xFFFFD500); // Bright Yellow
  static const Color accentGreen = Color(0xFF00E676); // Bright Green
  static const Color borderBlack = Color(0xFF000000); // Stark Black

  static const Color surface = Color(0xFFF8FAFC); // Very light slate
  static const Color surfaceVariant = Color(0xFFFFFFFF); // Pure White
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
}
