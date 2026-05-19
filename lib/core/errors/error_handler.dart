import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;

import 'error_logger.dart';
import 'error_messages.dart';
import 'error_types.dart';
import '../../shared/widgets/errors/error_dialog.dart';
import '../../shared/widgets/errors/error_dialogue.dart';

/// Centralized error classification, logging, and user-facing messaging.
///
/// All exceptions in the app should be passed through [handle] (or one of the
/// convenience helpers) to ensure consistent logging and Gujarati UI messages.
class ErrorHandler {
  /// Returns an [AppError] that can be shown to the user.
  static AppError handle(
    dynamic error,
    StackTrace stack, {
    String context = '',
  }) {
    if (error is AppError) {
      // Already classified.
      ErrorLogger.log(error, currentScreen: context);
      return error;
    }

    final code = _classifyCode(error);
    final messageDef = ErrorMessages.of(code);

    final technical = '${messageDef.technical} — ${error.toString()}';

    final appError = AppError(
      code: messageDef.code,
      category: messageDef.category,
      technicalMessage: technical,
      userMessage: messageDef.gujarati,
      isCritical: messageDef.isCritical,
      timestamp: DateTime.now(),
      stackTrace: stack,
    );

    ErrorLogger.log(appError, currentScreen: context);
    return appError;
  }

  /// Classifies an exception into a known error code.
  static String _classifyCode(dynamic error) {
    try {
      if (error is sqlcipher.DatabaseException) {
        final msg = error.toString().toLowerCase();
        if (msg.contains('wrong key') ||
            msg.contains('file is encrypted') ||
            msg.contains('malformed')) {
          return 'DB_004';
        }
        if (msg.contains('integrity')) {
          return 'DB_007';
        }
        if (msg.contains('database is locked') || msg.contains('busy')) {
          return 'DB_001';
        }
        return 'DB_002';
      }

      if (error is FileSystemException) {
        final msg = error.message.toLowerCase();
        if (msg.contains('no space') || msg.contains('disk full')) {
          return 'STORE_003';
        }
        return 'STORE_001';
      }

      if (error is UnsupportedError) {
        return 'CALC_001';
      }

      if (error is ArgumentError) {
        final msg = error.message?.toString().toLowerCase() ?? '';
        if (msg.contains('negative')) {
          return 'CALC_002';
        }
      }

      if (error is StateError) {
        final msg = error.toString().toLowerCase();
        // Database-related StateErrors
        if (msg.contains('database') || msg.contains('sqflite')) {
          return 'DB_004';
        }
        return 'UNK_001';
      }

      if (error is PlatformException) {
        final code = error.code.toLowerCase();
        final message = (error.message ?? '').toLowerCase();
        if (code.contains('bluetooth') || message.contains('bluetooth')) {
          return 'PRINT_005';
        }
        // Check for database-related platform exceptions
        if (code.contains('database') || message.contains('database')) {
          return 'DB_004';
        }
      }

      // Catch-all for unhandled errors.
      return 'UNK_001';
    } catch (_) {
      return 'UNK_001';
    }
  }

  /// Logs the error silently without showing any UI.
  static void handleSilently(
    dynamic error,
    StackTrace stack, {
    String context = '',
  }) {
    handle(error, stack, context: context);
  }

  /// Logs the error and shows a snackbar with the Gujarati user message.
  static void handleAndShowSnackbar(
    BuildContext context,
    dynamic error,
    StackTrace stack, {
    String contextDescription = '',
  }) {
    final appError = handle(error, stack, context: contextDescription);
    ErrorDialogue.showSnackbar(
      context,
      message: appError.userMessage,
      type: ErrorDialogueType.error,
    );
  }

  /// Logs the error and shows a dialog with the Gujarati user message.
  static Future<void> handleAndShowDialog(
    BuildContext context,
    dynamic error,
    StackTrace stack, {
    String contextDescription = '',
  }) async {
    final appError = handle(error, stack, context: contextDescription);
    await ErrorDialog.show(context, appError);
  }
}
