import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/settings_providers.dart';

/// Navigation item model
class NavItem {
  final String label;
  final IconData icon;
  final String moduleKey; // e.g., 'module_udhaar', or empty if always visible

  NavItem({required this.label, required this.icon, this.moduleKey = ''});
}

/// Provider that returns reactive nav items based on enabled modules
final navigationItemsProvider = FutureProvider<List<NavItem>>((ref) async {
  final modules = await ref.watch(moduleSettingsProvider.future);

  final items = [
    NavItem(
      label: 'બિલ',
      icon: Icons.point_of_sale,
      moduleKey: '', // Always visible
    ),
    NavItem(
      label: 'માલ',
      icon: Icons.inventory_2,
      moduleKey: '', // Always visible
    ),
    NavItem(label: 'ખાતું', icon: Icons.people, moduleKey: 'module_khata'),
    NavItem(
      label: 'રિપોર્ટ',
      icon: Icons.assessment,
      moduleKey: 'module_daily_pl',
    ),
    NavItem(
      label: 'સેટિંગ',
      icon: Icons.settings,
      moduleKey: '', // Always visible
    ),
    NavItem(
      label: 'ઉધાર',
      icon: Icons.account_balance_wallet,
      moduleKey: 'module_udhaar',
    ),
  ];

  // Filter items based on enabled modules and hide disabled ones
  return items.where((item) {
    if (item.moduleKey.isEmpty) return true;
    return modules[item.moduleKey] ?? true;
  }).toList();
});

/// Provider to check if a specific module is enabled
final moduleEnabledProvider = FutureProvider.family<bool, String>((
  ref,
  moduleName,
) async {
  final modules = await ref.watch(moduleSettingsProvider.future);
  return modules[moduleName] ?? true;
});
