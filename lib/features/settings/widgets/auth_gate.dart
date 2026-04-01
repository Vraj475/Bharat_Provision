import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../settings_providers.dart';
import '../screens/login_screen.dart';
import '../screens/splash_screen.dart';

/// AuthGate - Wrapper widget that checks auth status and shows splash/login if needed
class AuthGate extends ConsumerStatefulWidget {
  final Widget child;

  const AuthGate({required this.child, super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate>
    with WidgetsBindingObserver {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAuth();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _initializeAuth() async {
    // Initialize default PINs if not already set
    await ref.read(initializePinsProvider.future);

    // Load security settings
    final settings = await ref.read(securitySettingsProvider.future);
    final requirePinOnOpen = settings['require_pin_on_open'] as bool? ?? false;

    if (mounted) {
      // If app requires PIN on open, clear session to show login
      if (requirePinOnOpen) {
        ref.read(authSessionProvider.notifier).logout();
      }
    }
  }

  void _navigateFromSplash() {
    setState(() {
      _showSplash = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App went to background
      _checkAndLockSession();
    } else if (state == AppLifecycleState.resumed) {
      // App came back to foreground
      _checkAndLockSession();
    }
  }

  void _checkAndLockSession() async {
    final session = ref.read(authSessionProvider);
    if (session != null && session.isExpired) {
      ref.read(authSessionProvider.notifier).logout();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please login again.')),
        );
      }
    }
  }

  void _handleLoginSuccess(String role) {
    // Auth is already set by login screen; rebuild to show app content.
    // No navigation/pop is needed because AuthGate is the root widget.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);

    // Show splash screen on app startup
    if (_showSplash) {
      return SplashScreen(onNavigateToLogin: _navigateFromSplash);
    }

    // If app requires PIN on open and no active session, show login
    if (session == null) {
      return LoginScreen(onLoginSuccess: _handleLoginSuccess);
    }

    // Session expired
    if (session.isExpired) {
      Future.microtask(() {
        ref.read(authSessionProvider.notifier).logout();
      });
      return Scaffold(body: LoginScreen(onLoginSuccess: _handleLoginSuccess));
    }

    // session is active
    return widget.child;
  }
}
