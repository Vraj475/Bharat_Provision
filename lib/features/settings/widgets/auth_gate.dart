import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/role_provider.dart';
import '../providers/auth_provider.dart';
import '../settings_providers.dart';
import '../screens/login_screen.dart';

/// AuthGate - Wrapper widget that checks auth status and shows splash/login if needed
class AuthGate extends ConsumerStatefulWidget {
  final Widget child;

  const AuthGate({required this.child, super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate>
    with WidgetsBindingObserver {
  String? _restoredRole;

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
    try {
      // Initialize default PINs if not already set.
      await ref.read(initializePinsProvider.future);

      // Load security settings.
      final settings = await ref.read(securitySettingsProvider.future);
      final requirePinOnOpen =
          settings['require_pin_on_open'] as bool? ?? false;
      final sessionTimeoutMinutes =
          settings['session_timeout_minutes'] as int? ?? 5;

      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('role');

      debugPrint('Role: $role');

      if (!mounted) return;
      setState(() {
        _restoredRole = role;
      });

      if (role != null && !requirePinOnOpen) {
        ref
            .read(authSessionProvider.notifier)
            .setSession(
              role,
              timeoutMinutes: sessionTimeoutMinutes,
              requirePinOnOpen: requirePinOnOpen,
            );
        ref.read(currentRoleProvider.notifier).state = role;
        return;
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication setup failed. Please retry.'),
        ),
      );
      ref.read(authSessionProvider.notifier).logout();
    }
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

    // If app requires PIN on open and no active session, show login
    if (session == null) {
      return LoginScreen(
        onLoginSuccess: _handleLoginSuccess,
        initialRole: _restoredRole,
      );
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
