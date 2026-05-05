import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Windows keyboard shortcuts handler
/// This class is only active on Windows and should not be used on Android.
class KeyboardShortcutsHandler {
  // Shortcut callbacks
  final VoidCallback? onF1; // Billing
  final VoidCallback? onF2; // Inventory
  final VoidCallback? onF3; // Khata
  final VoidCallback? onF4; // Reports
  final VoidCallback? onF5; // Settings
  final VoidCallback? onF6; // Udhaar
  final VoidCallback? onF7; // Stock
  final VoidCallback? onCtrlP; // Print
  final VoidCallback? onCtrlS; // Save
  final VoidCallback? onCtrlQ; // Quit
  final VoidCallback? onCtrlN; // New Bill
  final VoidCallback? onCtrlZ; // Undo
  final VoidCallback? onEscape; // Cancel/Close

  KeyboardShortcutsHandler({
    this.onF1,
    this.onF2,
    this.onF3,
    this.onF4,
    this.onF5,
    this.onF6,
    this.onF7,
    this.onCtrlP,
    this.onCtrlS,
    this.onCtrlQ,
    this.onCtrlN,
    this.onCtrlZ,
    this.onEscape,
  });

  /// Handle key press events (Windows only)
  bool handleKeyPress(KeyEvent event) {
    // No-op on non-Windows platforms
    if (!Platform.isWindows) return false;
    
    if (event is! KeyDownEvent) return false;

    // Check for F1-F7
    if (event.logicalKey == LogicalKeyboardKey.f1) {
      onF1?.call();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.f2) {
      onF2?.call();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.f3) {
      onF3?.call();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.f4) {
      onF4?.call();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.f5) {
      onF5?.call();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.f6) {
      onF6?.call();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.f7) {
      onF7?.call();
      return true;
    }

    // Check for Ctrl combinations
    if (HardwareKeyboard.instance.isControlPressed) {
      if (event.logicalKey == LogicalKeyboardKey.keyP) {
        onCtrlP?.call();
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyS) {
        onCtrlS?.call();
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyQ) {
        onCtrlQ?.call();
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyN) {
        onCtrlN?.call();
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyZ) {
        onCtrlZ?.call();
        return true;
      }
    }

    // Check for Escape
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      onEscape?.call();
      return true;
    }

    return false;
  }
}

/// Keyboard shortcuts provider (Windows only)
/// Returns a no-op handler on non-Windows platforms
final keyboardShortcutsProvider = Provider<KeyboardShortcutsHandler>((ref) {
  // Return instance only on Windows; other platforms get a no-op instance
  return KeyboardShortcutsHandler();
});

/// Shortcut help dialog data
class KeyboardShortcut {
  final String key;
  final String description;
  final String descriptionGu;

  KeyboardShortcut({
    required this.key,
    required this.description,
    required this.descriptionGu,
  });
}

final keyboardShortcutsListProvider = Provider<List<KeyboardShortcut>>((ref) {
  return [
    KeyboardShortcut(
      key: 'F1',
      description: 'Switch to Billing',
      descriptionGu: 'બિલિંગમાં જાઓ',
    ),
    KeyboardShortcut(
      key: 'F2',
      description: 'Switch to Inventory',
      descriptionGu: 'ઇન્વેન્ટરીમાં જાઓ',
    ),
    KeyboardShortcut(
      key: 'F3',
      description: 'Switch to Khata',
      descriptionGu: 'ખાતું દર્શાવો',
    ),
    KeyboardShortcut(
      key: 'F4',
      description: 'Switch to Reports',
      descriptionGu: 'રિપોર્ટમાં જાઓ',
    ),
    KeyboardShortcut(
      key: 'F5',
      description: 'Switch to Settings',
      descriptionGu: 'સેટિંગમાં જાઓ',
    ),
    KeyboardShortcut(
      key: 'F6',
      description: 'Switch to Udhaar',
      descriptionGu: 'ઉધારમાં જાઓ',
    ),
    KeyboardShortcut(
      key: 'F7',
      description: 'Switch to Stock',
      descriptionGu: 'સ્ટોકમાં જાઓ',
    ),
    KeyboardShortcut(
      key: 'Ctrl + P',
      description: 'Print',
      descriptionGu: 'છાપો',
    ),
    KeyboardShortcut(
      key: 'Ctrl + S',
      description: 'Save',
      descriptionGu: 'સંગ્રહ કરો',
    ),
    KeyboardShortcut(
      key: 'Ctrl + N',
      description: 'New Bill',
      descriptionGu: 'નવો બીલ',
    ),
    KeyboardShortcut(
      key: 'Ctrl + Z',
      description: 'Undo',
      descriptionGu: 'પૂર્વવત્ કરો',
    ),
    KeyboardShortcut(
      key: 'Escape',
      description: 'Cancel/Close',
      descriptionGu: 'રદ કરો/બંધ કરો',
    ),
  ];
});
