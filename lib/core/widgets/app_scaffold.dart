import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'logout_redirect_page.dart';
import '../../features/settings/providers/auth_provider.dart';
import '../auth/role_provider.dart';
import '../localization/app_strings.dart';

/// Platform-aware navigation shell: bottom nav on Android, side rail on Windows
/// This scaffold shows a fixed set of tabs for the main app.
class AppScaffold extends ConsumerWidget {
  const AppScaffold({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.child,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final String role = session?.role ?? ref.watch(currentRoleProvider);
    final isAdmin = canAccessUdhaar(role);
    final roleLabel = _roleLabel(role);
    final screenWidth = MediaQuery.sizeOf(context).width;

    final items = [
      const _NavItem(AppStrings.navBilling, Icons.point_of_sale),
      const _NavItem(AppStrings.navInventory, Icons.inventory_2),
      const _NavItem(AppStrings.navKhata, Icons.people),
      const _NavItem(AppStrings.navReports, Icons.assessment),
      const _NavItem(AppStrings.navSettings, Icons.settings),
      if (isAdmin) const _NavItem('ઉધાર', Icons.account_balance_wallet),
    ];

    final effectiveIndex = currentIndex.clamp(0, items.length - 1);

    if (screenWidth >= 900) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: 280,
              child: Drawer(
                elevation: 0,
                child: _SidebarContent(
                  roleLabel: roleLabel,
                  selectedIndex: effectiveIndex,
                  items: items,
                  onDestinationSelected: onDestinationSelected,
                  onLogout: () => _logout(context, ref),
                  isDrawerRoute: false,
                ),
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      drawer: Drawer(
        child: _SidebarContent(
          roleLabel: roleLabel,
          selectedIndex: effectiveIndex,
          items: items,
          onDestinationSelected: onDestinationSelected,
          onLogout: () => _logout(context, ref),
          isDrawerRoute: true,
        ),
      ),
      body: Stack(
        children: [
          child,
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.topLeft,
                child: Builder(
                  builder: (menuContext) => Material(
                    color: Theme.of(menuContext).colorScheme.surface,
                    elevation: 3,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Open menu',
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(menuContext).openDrawer(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _roleLabel(String role) {
    switch (role) {
      case 'superadmin':
        return 'SuperAdmin';
      case 'admin':
        return 'Admin';
      default:
        return 'User';
    }
  }

  static void _logout(BuildContext context, WidgetRef ref) {
    ref.read(authSessionProvider.notifier).logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LogoutRedirectPage()),
      (route) => route.isFirst,
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _SidebarContent extends StatelessWidget {
  const _SidebarContent({
    required this.roleLabel,
    required this.selectedIndex,
    required this.items,
    required this.onDestinationSelected,
    required this.onLogout,
    required this.isDrawerRoute,
  });

  final String roleLabel;
  final int selectedIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onLogout;
  final bool isDrawerRoute;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),
            Text(
              AppStrings.appTitle,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    selected: index == selectedIndex,
                    leading: Icon(item.icon),
                    title: Text(item.label),
                    onTap: () {
                      if (isDrawerRoute) {
                        Navigator.of(context).pop();
                      }
                      onDestinationSelected(index);
                    },
                  );
                },
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                'Logged in as: $roleLabel',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                if (isDrawerRoute) {
                  Navigator.of(context).pop();
                }
                onLogout();
              },
            ),
          ],
        ),
      ),
    );
  }
}
