import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'role_provider.dart';
import 'unauthorized_screen.dart';

/// A widget that guards a screen based on user role.
/// If the user's role is not in [allowedRoles], shows an unauthorized screen.
class RoleGuard extends ConsumerWidget {
  final Widget child;
  final List<String> allowedRoles;

  const RoleGuard({required this.child, required this.allowedRoles, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);

    if (!allowedRoles.contains(role)) {
      return UnauthorizedScreen(
        attemptedRole: role,
        requiredRoles: allowedRoles,
      );
    }

    return child;
  }
}
