import 'package:flutter/material.dart';
import 'expenses_home_screen.dart';

class ExpenseListScreen extends StatelessWidget {
  final int initialTabIndex;

  const ExpenseListScreen({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    return ExpensesHomeScreen(initialTabIndex: initialTabIndex);
  }
}
