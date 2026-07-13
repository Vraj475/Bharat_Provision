import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/app_scaffold.dart';
import '../core/auth/role_provider.dart';
import '../core/auth/role_guard.dart';
import '../features/billing/billing_home_screen.dart';
import '../features/billing/bill_history_screen.dart';
import '../features/inventory/category_list_screen.dart';
import '../features/inventory/item_list_screen.dart';
import '../features/inventory/item_edit_screen.dart';
import '../features/khata/customer_list_screen.dart';
import '../features/khata/customer_khata_detail_screen.dart';
import '../features/khata/customer_edit_screen.dart';
import '../features/khata/khata_screen.dart';
import '../features/reports/reports_home_screen.dart';
import '../features/returns/return_history_screen.dart';
import '../features/returns/return_screen.dart';
import '../features/returns/replace_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/stock/stock_dashboard_screen.dart';
import '../features/stock/add_stock_screen.dart';
import '../features/stock/stock_history_screen.dart';
import '../shared/models/product_model.dart';
import '../features/udhaar/udhaar_dashboard_screen.dart';
import '../features/udhaar/customer_ledger_screen.dart';
import '../features/udhaar/collect_payment_screen.dart';
import '../features/udhaar/final_total_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/reports/pl_report_screen.dart';
import '../features/reports/daily_report_screen.dart';
import '../features/expenses/add_expense_screen.dart';
import '../features/expenses/expense_list_screen.dart';

class AppRouter {
  AppRouter._();

  static const String billing = '/billing';
  static const String billHistory = '/bill-history';
  static const String dashboard = '/';
  static const String inventory = '/inventory';
  static const String customers = '/customers';
  static const String khata = '/khata';
  static const String reports = '/reports';
  static const String settings = '/settings';
  static const String itemAdd = '/inventory/add';
  static const String itemEdit = '/inventory/edit';
  static const String categories = '/inventory/categories';
  static const String customerAdd = '/khata/add';
  static const String customerEdit = '/khata/edit';
  static const String customerKhata = '/khata/detail';
  static const String stockDashboard = '/stock';
  static const String stockAdd = '/stock/add';
  static const String stockHistory = '/stock/history';
  static const String returnsNew = '/returns/new';
  static const String returnsReplace = '/returns/replace';
  static const String returnsHistory = '/returns/history';
  static const String udhaarDashboard = '/udhaar';
  static const String udhaarCustomer = '/udhaar/customer';
  static const String udhaarCollect = '/udhaar/collect';
  static const String udhaarFinal = '/udhaar/final';
  static const String plReport = '/reports/pl';
  static const String dailyReport = '/reports/daily';
  static const String addExpense = '/expenses/add';
  static const String expenseList = '/expenses';

  static List<String> _mainRoutesForRole(String role) {
    final isAdmin = canAccessUdhaar(role);
    return [
      billing,
      if (isAdmin) billHistory,
      inventory,
      customers,
      reports,
      settings,
      if (isAdmin) udhaarDashboard,
    ];
  }

  static int indexForRoute(String route, {String role = 'admin'}) {
    final i = _mainRoutesForRole(role).indexOf(route);
    return i >= 0 ? i : 0;
  }

  static Route<dynamic> onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case dashboard:
        return _buildShell(dashboard, const DashboardScreen());
      case billing:
        return _buildShell(billing, const BillingHomeScreen());
      case billHistory:
        return _buildShellGuarded(
          billHistory,
          const BillHistoryScreen(),
          allowedRoles: const ['admin', 'superadmin'],
        );
      case inventory:
        return _buildShell(inventory, const ItemListScreen());
      case customers:
        return _buildShellGuarded(
          customers,
          const CustomerListScreen(),
          allowedRoles: const ['admin', 'superadmin'],
        );
      case khata:
        return _buildShellGuarded(
          customers,
          const KhataScreen(),
          allowedRoles: const ['admin', 'superadmin'],
        );
      case reports:
        return _buildShellGuarded(
          reports,
          const ReportsHomeScreen(),
          allowedRoles: const ['admin', 'superadmin'],
        );
      case settings:
        return _buildShellGuarded(
          settings,
          const SettingsScreen(),
          allowedRoles: const ['admin', 'superadmin'],
        );
      case categories:
        return _build(const CategoryListScreen());
      case itemAdd:
        return _build(const ItemEditScreen());
      case itemEdit:
        final id = routeSettings.arguments as int?;
        return _build(ItemEditScreen(itemId: id));
      case customerAdd:
        return _build(const CustomerEditScreen());
      case customerEdit:
        final id = routeSettings.arguments as int?;
        return _build(CustomerEditScreen(customerId: id));
      case customerKhata:
        final id = routeSettings.arguments as int;
        return _build(CustomerKhataDetailScreen(customerId: id));
      case stockDashboard:
        return _buildShell(inventory, const StockDashboardScreen());
      case stockAdd:
        final product = routeSettings.arguments as Product?;
        return _build(AddStockScreen(prefilledProduct: product));
      case stockHistory:
        final args = routeSettings.arguments as Map<String, dynamic>?;
        final productId = args?['productId'] as int?;
        final productName = args?['productName'] as String?;
        if (productId != null && productName != null) {
          return _build(
            StockHistoryScreen(productId: productId, productName: productName),
          );
        }
        return _build(
          Scaffold(
            body: Center(child: Text('Not found: ${routeSettings.name}')),
          ),
        );
      case returnsNew:
        return _buildGuarded(
          const ReturnScreen(),
          allowedRoles: const ['admin', 'superadmin'],
        );
      case returnsReplace:
        return _buildGuarded(
          const ReplaceScreen(),
          allowedRoles: const ['admin', 'superadmin'],
        );
      case returnsHistory:
        return _buildGuarded(
          const ReturnHistoryScreen(),
          allowedRoles: const ['admin', 'superadmin'],
        );
      case udhaarDashboard:
        return _buildShellGuarded(
          udhaarDashboard,
          const UdhaarDashboardScreen(),
          allowedRoles: const ['admin', 'superadmin'],
        );
      case udhaarCustomer:
        final customerId = routeSettings.arguments as int;
        return _buildGuarded(
          CustomerLedgerScreen(customerId: customerId),
          allowedRoles: const ['admin', 'superadmin'],
        );
      case udhaarCollect:
        final customerId = routeSettings.arguments as int;
        return _buildGuarded(
          CollectPaymentScreen(customerId: customerId),
          allowedRoles: const ['admin', 'superadmin'],
        );
      case udhaarFinal:
        final customerId = routeSettings.arguments as int;
        return _buildGuarded(
          FinalTotalScreen(customerId: customerId),
          allowedRoles: const ['admin', 'superadmin'],
        );
      case plReport:
        return _buildGuarded(
          const PLReportScreen(),
          allowedRoles: const ['admin', 'superadmin'],
        );
      case dailyReport:
        return _buildGuarded(
          const DailyReportScreen(),
          allowedRoles: const ['admin', 'superadmin'],
        );
      case addExpense:
        return _buildGuarded(
          const AddExpenseScreen(),
          allowedRoles: const ['admin', 'superadmin'],
        );
      case expenseList:
        return _buildGuarded(
          const ExpenseListScreen(),
          allowedRoles: const ['admin', 'superadmin'],
        );
      default:
        return _build(
          Scaffold(
            body: Center(child: Text('Not found: ${routeSettings.name}')),
          ),
        );
    }
  }

  static MaterialPageRoute<dynamic> _buildShell(
    String currentRoute,
    Widget child,
  ) {
    return MaterialPageRoute(
      builder: (context) =>
          _ShellRoute(currentRoute: currentRoute, child: child),
    );
  }

  static MaterialPageRoute<dynamic> _buildShellGuarded(
    String currentRoute,
    Widget child, {
    required List<String> allowedRoles,
  }) {
    return MaterialPageRoute(
      builder: (context) => RoleGuard(
        allowedRoles: allowedRoles,
        child: _ShellRoute(currentRoute: currentRoute, child: child),
      ),
    );
  }

  static MaterialPageRoute<dynamic> _build(Widget page) {
    return MaterialPageRoute(builder: (_) => page);
  }

  static MaterialPageRoute<dynamic> _buildGuarded(
    Widget page, {
    required List<String> allowedRoles,
  }) {
    return MaterialPageRoute(
      builder: (context) => RoleGuard(allowedRoles: allowedRoles, child: page),
    );
  }
}

class _ShellRoute extends ConsumerWidget {
  const _ShellRoute({required this.currentRoute, required this.child});

  final String currentRoute;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);
    final routes = AppRouter._mainRoutesForRole(role);
    final currentIndex = AppRouter.indexForRoute(currentRoute, role: role);

    return AppScaffold(
      currentIndex: currentIndex,
      onDestinationSelected: (i) {
        if (i < 0 || i >= routes.length) return;
        Navigator.of(context).pushReplacementNamed(routes[i]);
      },
      child: child,
    );
  }
}
