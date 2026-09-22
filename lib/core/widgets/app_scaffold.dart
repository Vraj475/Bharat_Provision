import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/providers/auth_provider.dart';
import '../../features/settings/settings_providers.dart';
import 'package:go_router/go_router.dart';
import '../../routing/app_router.dart';
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

  /// Max visible items in the mobile bottom nav bar.
  /// Items beyond this go into a "More" overflow bottom-sheet.
  static const int _mobileMaxVisibleItems = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final String role = session?.role ?? ref.watch(currentRoleProvider);
    final isAdmin = canAccessUdhaar(role);
    final roleLabel = _roleLabel(role);
    
    // Determine layout based on screen width instead of Platform
    final isWideScreen = MediaQuery.sizeOf(context).width >= 600;

    final items = _navItems(isAdmin);

    final effectiveIndex = currentIndex.clamp(0, items.length - 1);
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (isWideScreen) {
      return _buildWideLayout(
        context,
        ref,
        items: items,
        effectiveIndex: effectiveIndex,
        primaryColor: primaryColor,
        roleLabel: roleLabel,
      );
    }

    return _buildMobileLayout(
      context,
      items: items,
      effectiveIndex: effectiveIndex,
      primaryColor: primaryColor,
    );
  }

  // ─────────────────────── Wide / Desktop layout ───────────────────────

  Widget _buildWideLayout(
    BuildContext context,
    WidgetRef ref, {
    required List<_NavItem> items,
    required int effectiveIndex,
    required Color primaryColor,
    required String roleLabel,
  }) {
    // Watch the shop name provider for dynamic title in the rail header.
    final shopNameAsync = ref.watch(shopNameProvider);
    final shopDisplayName = shopNameAsync.when(
      data: (name) => name.isNotEmpty ? name : AppStrings.appTitle,
      loading: () => AppStrings.appTitle,
      error: (_, __) => AppStrings.appTitle,
    );

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
                    shopDisplayName,
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

  // ─────────────────────── Mobile layout ───────────────────────

  Widget _buildMobileLayout(
    BuildContext context, {
    required List<_NavItem> items,
    required int effectiveIndex,
    required Color primaryColor,
  }) {
    // If items fit within the limit, show them all directly.
    if (items.length <= _mobileMaxVisibleItems) {
      return Scaffold(
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
        body: child,
      );
    }

    // Too many items → show first (_mobileMaxVisibleItems - 1) + a "More" button.
    final visibleCount = _mobileMaxVisibleItems - 1; // 3 visible + 1 "More"
    final visibleItems = items.sublist(0, visibleCount);
    final overflowItems = items.sublist(visibleCount);

    // If the current route is one of the overflow items, highlight "More" tab.
    final isOverflowActive = effectiveIndex >= visibleCount;
    final bottomIndex = isOverflowActive ? visibleCount : effectiveIndex;

    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: bottomIndex,
        onTap: (i) {
          if (i < visibleCount) {
            onDestinationSelected(i);
          } else {
            // Show overflow bottom-sheet
            _showMoreSheet(context, overflowItems, visibleCount);
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primaryColor,
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: [
          for (final item in visibleItems)
            BottomNavigationBarItem(
              icon: Icon(item.icon),
              activeIcon: Icon(item.icon),
              label: item.label,
            ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.more_horiz,
              color: isOverflowActive
                  ? primaryColor
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            activeIcon: Icon(Icons.more_horiz, color: primaryColor),
            label: 'વધુ',
          ),
        ],
      ),
      body: child,
    );
  }

  /// Shows a bottom-sheet listing the overflow navigation items.
  void _showMoreSheet(
    BuildContext context,
    List<_NavItem> overflowItems,
    int indexOffset,
  ) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                for (var i = 0; i < overflowItems.length; i++)
                  ListTile(
                    leading: Icon(
                      overflowItems[i].icon,
                      color: (currentIndex == indexOffset + i)
                          ? primaryColor
                          : null,
                    ),
                    title: Text(
                      overflowItems[i].label,
                      style: (currentIndex == indexOffset + i)
                          ? TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            )
                          : null,
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      onDestinationSelected(indexOffset + i);
                    },
                  ),
              ],
            ),
          ),
        );
      },
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
    context.go(AppRouter.roleSelection);
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
