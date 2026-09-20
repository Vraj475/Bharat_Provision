import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/repositories/settings_repository.dart';
import 'error_logger.dart';

/// Provides actions that help the user / superadmin send error logs to the developer.
class ErrorReporter {
  final SettingsRepository _settingsRepository;

  ErrorReporter(this._settingsRepository);

  /// Shares the error log file using the platform share sheet.
  Future<void> shareLogAsFile() async {
    await ErrorLogger.shareLog();
  }

  /// Shares the error log via WhatsApp with a pre-filled message.
  ///
  /// If the developer phone number is not configured, this will do nothing.
  Future<void> shareLogViaWhatsApp({required String shopName}) async {
    final devNumber = await _settingsRepository.get('developer_phone');
    if (devNumber.isEmpty) return;

    final packageInfo = await PackageInfo.fromPlatform();
    final version = '${packageInfo.version}+${packageInfo.buildNumber}';
    final today = DateTime.now();
    final logCount = await _countErrorsToday();

    final message = Uri.encodeComponent(
      'Error Report\nShop: $shopName\nVersion: $version\nDate: ${today.toLocal()}\nErrors today: $logCount\n\n[Log file attached]',
    );

    final uri = Uri.parse('https://wa.me/$devNumber?text=$message');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<int> _countErrorsToday() async {
    final content = await ErrorLogger.getLogs();
    if (content.isEmpty) return 0;

    final today = DateTime.now();
    final lines = content.split('\n');
    var count = 0;
    for (final line in lines) {
      if (!line.startsWith('[')) continue;
      final datePart = line.substring(1, 20); // yyyy-MM-ddTHH:mm:ss
      try {
        final dt = DateTime.parse(datePart);
        if (dt.year == today.year &&
            dt.month == today.month &&
            dt.day == today.day) {
          count++;
        }
      } catch (_) {}
    }
    return count;
  }

  /// Returns a summary of errors grouped by error code for the last [days] days.
  Future<Map<String, int>> getErrorSummary({int days = 7}) async {
    final content = await ErrorLogger.getLogs();
    if (content.isEmpty) return {};

    final cutoff = DateTime.now().subtract(Duration(days: days));
    final lines = content.split('\n');
    final Map<String, int> counts = {};

    for (final line in lines) {
      if (!line.startsWith('[')) continue;
      final codeMatch = RegExp(r'CODE: ([A-Z0-9_]+)').firstMatch(line);
      if (codeMatch == null) continue;
      final code = codeMatch.group(1)!;

      // Try to parse date from the same line to filter by date
      final datePart = line.substring(1, 20); // yyyy-MM-ddTHH:mm:ss
      try {
        final dt = DateTime.parse(datePart);
        if (dt.isBefore(cutoff)) continue;
      } catch (_) {
        // ignore
      }

      counts[code] = (counts[code] ?? 0) + 1;
    }

    return counts;
  }
}
