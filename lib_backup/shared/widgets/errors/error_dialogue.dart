import 'package:flutter/material.dart';

/// Lightweight snackbars used for minor errors, warnings, and info messages.
class ErrorDialogue {
  /// Show a snackbar styled for errors/warnings/info.
  static void showSnackbar(
    BuildContext context, {
    required String message,
    String? code,
    ErrorDialogueType type = ErrorDialogueType.error,
    VoidCallback? retryCallback,
  }) {
    final theme = Theme.of(context);
    final background = _backgroundColor(type, theme);
    final duration = _duration(type);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: const TextStyle(color: Colors.white)),
            if (code != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  code,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ),
          ],
        ),
        duration: duration,
        backgroundColor: background,
        action: retryCallback != null
            ? SnackBarAction(
                label: 'ફરી પ્રયાસ',
                textColor: Colors.white,
                onPressed: retryCallback,
              )
            : null,
      ),
    );
  }

  static Color _backgroundColor(ErrorDialogueType type, ThemeData theme) {
    switch (type) {
      case ErrorDialogueType.warning:
        return const Color(0xFFF57F00);
      case ErrorDialogueType.info:
        return const Color(0xFF1A237E);
      case ErrorDialogueType.success:
        return Colors.green[700]!;
      case ErrorDialogueType.error:
        return Colors.red[700]!;
    }
  }

  static Duration _duration(ErrorDialogueType type) {
    switch (type) {
      case ErrorDialogueType.error:
        return const Duration(seconds: 4);
      case ErrorDialogueType.warning:
        return const Duration(seconds: 3);
      case ErrorDialogueType.info:
        return const Duration(seconds: 2);
      case ErrorDialogueType.success:
        return const Duration(seconds: 2);
    }
  }
}

enum ErrorDialogueType { error, warning, info, success }
