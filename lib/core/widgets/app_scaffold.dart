import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/providers/auth_provider.dart';
import '../../features/settings/screens/role_selection_screen.dart';
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

    final items = _navItems(isAdmin);

    final effectiveIndex = currentIndex.clamp(0, items.length - 1);
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (screenWidth >= 900) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: effectiveIndex,
              onDestinationSelected: onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              minWidth: 104,
              selectedIconTheme: IconThemeData(color: primaryColor),
              selectedLabelTextStyle: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w600,
              ),
              unselectedIconTheme: IconThemeData(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              unselectedLabelTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              leading: Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.appTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      roleLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              trailing: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: IconButton(
                  tooltip: 'Logout',
                  onPressed: () => _logout(context, ref),
                  icon: const Icon(Icons.logout),
                ),
              ),
              destinations: [
                for (final item in items)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.icon),
                    label: Text(item.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      drawer: Drawer(
        child: _DrawerContent(
          roleLabel: roleLabel,
          onLogout: () => _logout(context, ref),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: effectiveIndex,
        onTap: onDestinationSelected,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primaryColor,
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
        items: [
          for (final item in items)
            BottomNavigationBarItem(
              icon: Icon(item.icon),
              activeIcon: Icon(item.icon),
              label: item.label,
            ),
        ],
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
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (route) => false,
    );
  }

  List<_NavItem> _navItems(bool isAdmin) {
    return [
      const _NavItem(AppStrings.navBilling, Icons.point_of_sale),
      if (isAdmin) const _NavItem('બિલ ઇતિહાસ', Icons.receipt_long),
      const _NavItem(AppStrings.navInventory, Icons.inventory_2),
      const _NavItem(AppStrings.navKhata, Icons.people),
      const _NavItem(AppStrings.navReports, Icons.assessment),
      const _NavItem(AppStrings.navSettings, Icons.settings),
      if (isAdmin) const _NavItem('ઉધાર', Icons.account_balance_wallet),
    ];
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _DrawerContent extends StatelessWidget {
  const _DrawerContent({required this.roleLabel, required this.onLogout});

  final String roleLabel;
  final VoidCallback onLogout;

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
            const Spacer(),
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
                Navigator.of(context).pop();
                onLogout();
              },
            ),
          ],
        ),
      ),
    );
  }
}
