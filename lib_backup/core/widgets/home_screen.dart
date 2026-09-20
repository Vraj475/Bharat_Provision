import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/billing/billing_home_screen.dart';
import '../../features/billing/bill_history_screen.dart';
import '../../features/inventory/item_list_screen.dart';
import '../../features/khata/customer_list_screen.dart';
import '../../features/reports/reports_home_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/providers/auth_provider.dart';
import '../../features/udhaar/udhaar_dashboard_screen.dart';
import '../auth/role_provider.dart';
import 'app_scaffold.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

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
    if (state == AppLifecycleState.resumed) {
      final session = ref.read(authSessionProvider);
      if (session != null && session.isExpired) {
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
    final screens = _screensForRole(isAdmin);
    final currentScreen = screens[_currentIndex.clamp(0, screens.length - 1)];

    return AppScaffold(
      currentIndex: _currentIndex,
      onDestinationSelected: (i) => setState(() => _currentIndex = i),
      child: currentScreen,
    );
  }

  List<Widget> _screensForRole(bool isAdmin) {
    return [
      const BillingHomeScreen(),
      if (isAdmin) const BillHistoryScreen(),
      const ItemListScreen(),
      const CustomerListScreen(),
      const ReportsHomeScreen(),
      const SettingsScreen(),
      if (isAdmin) const UdhaarDashboardScreen(),
    ];
  }
}
