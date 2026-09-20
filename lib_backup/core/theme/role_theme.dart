import 'package:flutter/material.dart';

/// Role-based theme colors for the app
class RoleThemeColors {
  // Role-specific colors
  static const Color superadminColor = Color(0xFF6B46C1); // Purple
  static const Color adminColor = Color(0xFF3B82F6); // Blue
  static const Color employeeColor = Color(0xFF10B981); // Green

  // Get color for a specific role
  static Color colorForRole(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin':
        return superadminColor;
      case 'admin':
        return adminColor;
      case 'employee':
      default:
        return employeeColor;
    }
  }

  // Get a theme for a specific role
  static ThemeData themeForRole(String role, {bool largeText = false}) {
    final primaryColor = colorForRole(role);

    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryColor,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: false,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: primaryColor,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
      ),
      navigationRailTheme: NavigationRailThemeData(
        selectedIconTheme: IconThemeData(color: primaryColor),
        selectedLabelTextStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryColor),
      ),
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: primaryColor.withValues(alpha: 0.7),
        surface: Colors.white,
        error: Colors.red,
      ),
    );
  }

  // Get display name for a role
  static String displayName(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin':
        return 'સુપર વ્યવસ્થાપક';
      case 'admin':
        return 'વ્યવસ્થાપક';
      case 'employee':
      default:
        return 'કર્મચારી';
    }
  }

  // Get icon for a role
  static IconData iconForRole(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin':
        return Icons.admin_panel_settings;
      case 'admin':
        return Icons.person;
      case 'employee':
      default:
        return Icons.people_outline;
    }
  }
}

/// AppBar wrapper that automatically changes color based on current role
class RoleAwareAppBar extends AppBar {
  final String currentRole;

  RoleAwareAppBar({
    super.key,
    required this.currentRole,
    required String titleText,
    super.actions,
    super.leading,
    bool super.centerTitle = false,
    double super.elevation = 2,
    super.bottom,
  }) : super(
         backgroundColor: RoleThemeColors.colorForRole(currentRole),
         foregroundColor: Colors.white,
         title: Text(titleText),
       );
}
