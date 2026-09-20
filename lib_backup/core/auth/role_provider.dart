import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current logged-in user role: 'admin' | 'cashier'
/// Defaults to 'cashier'. Updated during a login flow.
final currentRoleProvider = StateProvider<String>((ref) => 'cashier');

/// Role access control providers
// Check if user can access Udhaar module
final canAccessUdhaarProvider = Provider<bool>((ref) {
  final role = ref.watch(currentRoleProvider);
  return role == 'admin';
});

// Check if user can access P&L reports
final canAccessPLProvider = Provider<bool>((ref) {
  final role = ref.watch(currentRoleProvider);
  return role == 'admin';
});

// Check if user can access Khata (ledger)
final canAccessKhataProvider = Provider<bool>((ref) {
  final role = ref.watch(currentRoleProvider);
  return role == 'admin';
});

// Check if user can access Settings
final canAccessSettingsProvider = Provider<bool>((ref) {
  final role = ref.watch(currentRoleProvider);
  return role == 'admin';
});

// Check if user can access Returns
final canAccessReturnsProvider = Provider<bool>((ref) {
  final role = ref.watch(currentRoleProvider);
  return role == 'admin';
});

// Check if user can access Expenses
final canAccessExpensesProvider = Provider<bool>((ref) {
  final role = ref.watch(currentRoleProvider);
  return role == 'admin';
});

/// Role info provider
final roleInfoProvider = Provider<RoleInfo>((ref) {
  final role = ref.watch(currentRoleProvider);
  return RoleInfo.fromRole(role);
});

/// Role information class
class RoleInfo {
  final String role;
  final String displayName;
  final String displayNameGu;
  final int pinLength;
  final bool isAdmin;

  RoleInfo({
    required this.role,
    required this.displayName,
    required this.displayNameGu,
    required this.pinLength,
    required this.isAdmin,
  });

  factory RoleInfo.fromRole(String role) {
    switch (role) {
      case 'admin':
        return RoleInfo(
          role: 'admin',
          displayName: 'Admin',
          displayNameGu: 'વ્યવસ્થાપક',
          pinLength: 4,
          isAdmin: true,
        );
      case 'cashier':
      default:
        return RoleInfo(
          role: 'cashier',
          displayName: 'Cashier',
          displayNameGu: 'કેશિયર',
          pinLength: 4,
          isAdmin: false,
        );
    }
  }

  bool canAccess(String moduleName) {
    if (role == 'admin') return true;
    // Cashier has limited access
    return moduleName == 'billing' || moduleName == 'inventory';
  }
}

/// Returns true if the given role may access the Udhaar module.
bool canAccessUdhaar(String role) => role == 'admin';
