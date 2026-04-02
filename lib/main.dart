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
import 'features/settings/providers/auth_provider.dart';
import 'features/settings/widgets/auth_gate.dart';
import 'core/widgets/app_scaffold.dart';
import 'features/billing/billing_home_screen.dart';
import 'features/inventory/item_list_screen.dart';
import 'features/khata/customer_list_screen.dart';
import 'features/reports/reports_home_screen.dart';
import 'features/settings/settings_screen.dart';
import 'routing/app_router.dart';
import 'core/auth/role_provider.dart';
import 'features/udhaar/udhaar_dashboard_screen.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLargeText());
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
      home: AuthGate(child: const _MainShell()),
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}

class _MainShell extends ConsumerStatefulWidget {
  const _MainShell();

  @override
  ConsumerState<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<_MainShell>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  static const List<Widget> _baseScreens = [
    BillingHomeScreen(),
    ItemListScreen(),
    CustomerListScreen(),
    ReportsHomeScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App went to background - session timeout will trigger on resume
    } else if (state == AppLifecycleState.resumed) {
      // App came back to foreground
      final session = ref.read(authSessionProvider);
      if (session != null && session.isExpired) {
        // Session expired - logout
        ref.read(authSessionProvider.notifier).logout();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session expired. Please login again.'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentRoleProvider);
    final isAdmin = canAccessUdhaar(role);
    final Widget currentScreen;
    if (_currentIndex == 5 && isAdmin) {
      currentScreen = const UdhaarDashboardScreen();
    } else {
      currentScreen = _baseScreens[_currentIndex.clamp(0, 4)];
    }
    return AppScaffold(
      currentIndex: _currentIndex,
      onDestinationSelected: (i) => setState(() => _currentIndex = i),
      child: currentScreen,
    );
  }
}
