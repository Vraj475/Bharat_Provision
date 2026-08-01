import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/errors/error_handler.dart';
import 'core/localization/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'data/providers.dart';
import 'features/settings/settings_providers.dart';

import 'core/database/database_helper.dart';
import 'routing/app_router.dart';
import 'package:flutter/foundation.dart';


void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      if (Platform.isWindows || Platform.isLinux) {
        sqfliteFfiInit();
      }

      // Initialize the database synchronously for providers
      final db = await DatabaseHelper.instance.database;

      FlutterError.onError = (details) {
        final String message = details.exceptionAsString();
        if (message.contains('keysPressed') && message.contains('RawKeyDownEvent')) {
          // Known Flutter Windows bug: Alt key modifier flags not set
          // Track: https://github.com/flutter/flutter/issues/75675
          return; // suppress silently
        }
        FlutterError.presentError(details);
        ErrorHandler.handleSilently(
          details.exception,
          details.stack ?? StackTrace.current,
          context: 'FlutterError.onError',
        );
      };

      runApp(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: const KiranaApp(),
        ),
      );
    },
    (error, stack) {
      ErrorHandler.handleSilently(error, stack, context: 'ZoneGuarded');
    },
  );
}

class KiranaApp extends ConsumerStatefulWidget {
  const KiranaApp({super.key});

  @override
  ConsumerState<KiranaApp> createState() => _KiranaAppState();
}

class _KiranaAppState extends ConsumerState<KiranaApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLargeText();
      if (kDebugMode) {
        debugPrint('Application Ran Without error and warning');
      }
    });
  }

  Future<void> _loadLargeText() async {
    try {
      final repo = ref.read(settingsRepositoryProvider);
      final v = await repo.getBool('large_text');
      ref.read(largeTextProvider.notifier).state = v;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Error in _loadLargeText: $e\n$stackTrace');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final largeText = ref.watch(largeTextProvider);

    return MaterialApp.router(
      title: AppStrings.appTitle,
      theme: AppTheme.lightTheme(largeText: largeText),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: largeText
                ? const TextScaler.linear(1.2)
                : TextScaler.noScaling,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: appRouter,
    );
  }
}
