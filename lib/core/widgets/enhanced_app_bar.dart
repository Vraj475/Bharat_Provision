import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/role_provider.dart';
import '../localization/app_strings.dart';
import '../theme/role_theme.dart';
import '../../features/settings/providers/auth_provider.dart';

/// Enhanced AppBar widget with role-aware styling.
class EnhancedAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool centerTitle;
  final VoidCallback? onLogout;
  final Widget? leading;
  final double elevation;

  const EnhancedAppBar({
    required this.title,
    this.actions,
    this.centerTitle = false,
    this.onLogout,
    this.leading,
    this.elevation = 2,
    super.key,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);
    final backgroundColor = RoleThemeColors.colorForRole(role);

    return AppBar(
      backgroundColor: backgroundColor,
      foregroundColor: Colors.white,
      elevation: elevation,
      centerTitle: centerTitle,
      title: Text(title),
      leading: leading,
      actions: [
        ...(actions ?? []),
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Center(
            child: Tooltip(
              message: RoleThemeColors.displayName(role),
              child: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'profile') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile - Coming soon')),
                    );
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'profile',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(RoleThemeColors.iconForRole(role), size: 18),
                        const SizedBox(width: 12),
                        Text(
                          RoleThemeColors.displayName(role),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
                icon: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  child: Icon(
                    RoleThemeColors.iconForRole(role),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Simple logout button widget that can be used independently
class LogoutButton extends ConsumerWidget {
  final VoidCallback? onLogout;
  final String label;

  const LogoutButton({
    this.onLogout,
    this.label = AppStrings.logout,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton.icon(
      onPressed: () {
        _showLogoutConfirmation(context, ref);
      },
      icon: const Icon(Icons.logout),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red[600],
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.logout),
        content: const Text('શું તમે ચોક્કસ લૉગ આઉટ કરવા માંગો છો?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.deleteCancelButton),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(authSessionProvider.notifier).logout();
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/login', (route) => false);
              if (onLogout != null) {
                onLogout!();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600]),
            child: const Text(AppStrings.logout),
          ),
        ],
      ),
    );
  }
}
