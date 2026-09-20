import 'package:flutter/material.dart';

/// A persistent banner that appears at the top of the screen for ongoing issues.
///
/// This is intended for things like "Printer disconnected" or "Backup failed"
/// where the user should see the alert until the condition is resolved.
class ErrorBanner {
  static void show(
    BuildContext context, {
    required String message,
    String? bannerId,
    VoidCallback? onDismiss,
  }) {
    final banner = MaterialBanner(
      padding: const EdgeInsets.all(16),
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: const Color(0xFFF57F00),
      leading: const Icon(Icons.warning, color: Colors.white),
      actions: [
        if (onDismiss != null)
          TextButton(
            onPressed: () {
              onDismiss();
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            },
            child: const Text('Dismiss', style: TextStyle(color: Colors.white)),
          ),
      ],
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(banner);
  }

  static void dismiss(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
  }
}
