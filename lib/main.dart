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

import 'routing/app_router.dart';
import 'features/settings/screens/splash_screen.dart';

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErrorHandler.handleSilently(
      details.exception,
      details.stack ?? StackTrace.current,
      context: 'FlutterError.onError',
    );
  };

  runZonedGuarded(
    () {
      runApp(const ProviderScope(child: KiranaApp()));
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
      debugPrint('Application Ran Without error and warning');
    });
  }

  Future<void> _loadLargeText() async {
    try {
      final repo = await ref.read(settingsRepositoryFutureProvider.future);
      final v = await repo.getBool('large_text');
      ref.read(largeTextProvider.notifier).state = v;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final largeText = ref.watch(largeTextProvider);

    return MaterialApp(
      navigatorKey: _navigatorKey,
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
      home: const SplashScreen(),
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
