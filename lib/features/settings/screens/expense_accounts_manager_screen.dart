import 'package:flutter/material.dart';

import '../../expenses/views/expense_accounts_view.dart';

/// Screen for managing expense accounts.
/// Connected directly to the SQLite database with insertion, deletion, and editing.
class ExpenseAccountsManagerScreen extends StatelessWidget {
  const ExpenseAccountsManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ExpenseAccountsView(showAppBar: true);
  }
}
