import 'package:flutter/material.dart';

/// Centralized responsive breakpoints and helpers.
/// All screen-size decisions should go through this class so we have
/// a single source-of-truth for layout breakpoints.
class ResponsiveHelper {
  ResponsiveHelper._();

  // ---- Breakpoints ----
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;

  /// True on phones (width < 600).
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileBreakpoint;

  /// True on tablets (600 ≤ width < 1024).
  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= mobileBreakpoint && w < tabletBreakpoint;
  }

  /// True on desktop / wide windows (width ≥ 1024).
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletBreakpoint;

  /// True when we should show wide-screen navigation (NavigationRail).
  /// Matches the existing 600px threshold used in AppScaffold.
  static bool isWideScreen(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= mobileBreakpoint;

  // ---- Responsive values ----

  /// Screen-appropriate content padding.
  static double contentPadding(BuildContext context) =>
      isMobile(context) ? 12.0 : 16.0;

  /// Screen-appropriate spacing between cards / sections.
  static double sectionSpacing(BuildContext context) =>
      isMobile(context) ? 12.0 : 16.0;
}
