import 'package:flutter/material.dart';
import 'pl_report_screen.dart';

/// Backward-compatible wrapper for DailyReportScreen.
/// Delegates directly to the unified PLReportScreen in single-day mode.
class DailyReportScreen extends StatelessWidget {
  const DailyReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PLReportScreen(initialPeriod: 'today');
  }
}
