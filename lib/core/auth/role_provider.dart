import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current logged-in user role: 'superadmin' | 'admin' | 'employee'
/// Defaults to 'admin'. Updated during a login flow.
final currentRoleProvider = StateProvider<String>((ref) => 'admin');

/// Role access control providers
// Check if user can access Udhaar module
final canAccessUdhaarProvider = Provider<bool>((ref) {
  final role = ref.watch(currentRoleProvider);
  return role == 'superadmin' || role == 'admin';
});

// Check if user can access P&L reports
final canAccessPLProvider = Provider<bool>((ref) {
  final role = ref.watch(currentRoleProvider);
  return role == 'superadmin' || role == 'admin';
});

// Check if user can access Khata (ledger)
final canAccessKhataProvider = Provider<bool>((ref) {
  final role = ref.watch(currentRoleProvider);
  return role == 'superadmin' || role == 'admin';
});

// Check if user can access Settings
final canAccessSettingsProvider = Provider<bool>((ref) {
  final role = ref.watch(currentRoleProvider);
  return role == 'superadmin' || role == 'admin';
});

// Check if user can access Returns
final canAccessReturnsProvider = Provider<bool>((ref) {
  final role = ref.watch(currentRoleProvider);
  return role == 'superadmin' || role == 'admin';
});

// Check if user can access Expenses
final canAccessExpensesProvider = Provider<bool>((ref) {
  final role = ref.watch(currentRoleProvider);
  return role == 'superadmin' || role == 'admin';
});

// Check if user can access Superadmin panel
final canAccessSuperadminProvider = Provider<bool>((ref) {
  final role = ref.watch(currentRoleProvider);
  return role == 'superadmin';
});

// Check if user can access Employee management
final canAccessEmployeeManagementProvider = Provider<bool>((ref) {
  final role = ref.watch(currentRoleProvider);
  return role == 'superadmin';
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
  final bool isSuperAdmin;

  RoleInfo({
    required this.role,
    required this.displayName,
    required this.displayNameGu,
    required this.pinLength,
    required this.isSuperAdmin,
  });

  factory RoleInfo.fromRole(String role) {
    switch (role) {
      case 'superadmin':
        return RoleInfo(
          role: 'superadmin',
          displayName: 'Superadmin',
          displayNameGu: 'સુપર વ્યવસ્થાપક',
          pinLength: 4,
          isSuperAdmin: true,
        );
      case 'admin':
        return RoleInfo(
          role: 'admin',
          displayName: 'Admin',
          displayNameGu: 'વ્યવસ્થાપક',
          pinLength: 4,
          isSuperAdmin: false,
        );
      case 'employee':
      default:
        return RoleInfo(
          role: 'employee',
          displayName: 'Employee',
          displayNameGu: 'કર્મચારી',
          pinLength: 4,
          isSuperAdmin: false,
        );
    }
  }

  bool canAccess(String moduleName) {
    if (role == 'superadmin') return true;
    if (role == 'admin') {
      return moduleName != 'superadmin_only';
    }
    // Employee has limited access
    return moduleName == 'billing' || moduleName == 'inventory';
  }
}

/// Returns true if the given role may access the Udhaar module.
bool canAccessUdhaar(String role) => role == 'superadmin' || role == 'admin';
