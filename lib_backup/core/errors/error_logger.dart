import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'error_types.dart';

/// Writes errors silently to a local log file for developer diagnostics.
///
/// The user should never see this file unless they explicitly share it via the
/// Superadmin panel or a dedicated "Send logs" action.
class ErrorLogger {
  static const _logFileName = 'kirana_error_log.txt';
  static const _oldLogFileName = 'kirana_error_log_old.txt';
  static const _maxFileSizeKb = 500;
  static const _logSeparator = '\n---\n';

  static Future<File> _getLogFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _logFileName));
  }

  static Future<File> _getOldLogFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _oldLogFileName));
  }

  static Future<void> _rotateIfNeeded(File file) async {
    try {
      if (!await file.exists()) return;
      final bytes = await file.length();
      if (bytes <= _maxFileSizeKb * 1024) return;

      final oldFile = await _getOldLogFile();
      if (await oldFile.exists()) {
        await oldFile.delete();
      }

      await file.rename(oldFile.path);
      await file.create(recursive: true);
    } catch (_) {
      // Swallow any errors; logging must never crash the app.
    }
  }

  static String _formatEntry(AppError error, {String? currentScreen}) {
    final timestamp = error.timestamp.toIso8601String();
    final stackSnippet =
        error.stackTrace?.toString().split('\n').take(5).join('\n') ?? '';
    return '[${timestamp.replaceFirst('T', ' ')}] | CODE: ${error.code} | CATEGORY: ${error.category} | SCREEN: ${currentScreen ?? 'unknown'} | TECHNICAL: ${error.technicalMessage} | STACK: $stackSnippet$_logSeparator';
  }

  /// Write an error entry to the log file.
  ///
  /// This function never throws. All failures are swallowed silently.
  static Future<void> log(AppError error, {String? currentScreen}) async {
    try {
      final file = await _getLogFile();
      await _rotateIfNeeded(file);
      await file.create(recursive: true);
      final entry = _formatEntry(error, currentScreen: currentScreen);
      await file.writeAsString(entry, mode: FileMode.append, flush: true);
    } catch (_) {
      // Swallow errors; logging should never crash the app.
    }
  }

  /// Returns the full contents of the current log file.
  static Future<String> getLogs() async {
    try {
      final file = await _getLogFile();
      if (!await file.exists()) {
        return '';
      }
      return await file.readAsString();
    } catch (_) {
      return '';
    }
  }

  /// Clears the current log file. Intended for use by superadmins.
  static Future<void> clearLogs() async {
    try {
      final file = await _getLogFile();
      if (await file.exists()) {
        await file.writeAsString('');
      }
      final oldFile = await _getOldLogFile();
      if (await oldFile.exists()) {
        await oldFile.delete();
      }
    } catch (_) {
      // Swallow silently.
    }
  }

  /// Shares the current error log file using the platform share sheet.
  ///
  /// If the log file does not exist, this is a no-op.
  static Future<void> shareLog() async {
    try {
      final file = await _getLogFile();
      if (!await file.exists()) return;
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Error log from Kirana app');
    } catch (_) {
      // Swallow; sharing is best-effort.
    }
  }
}
