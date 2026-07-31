import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../features/settings/screens/splash_screen.dart';
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

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRouter.dashboard,
      builder: (context, state) => const _ShellRoute(
        currentRoute: AppRouter.dashboard,
        child: DashboardScreen(),
      ),
    ),
    GoRoute(
      path: AppRouter.billing,
      builder: (context, state) => const _ShellRoute(
        currentRoute: AppRouter.billing,
        child: BillingHomeScreen(),
      ),
    ),
    GoRoute(
      path: AppRouter.billHistory,
      builder: (context, state) => const RoleGuard(
        allowedRoles: ['admin', 'superadmin'],
        child: _ShellRoute(
          currentRoute: AppRouter.billHistory,
          child: BillHistoryScreen(),
        ),
      ),
    ),
    GoRoute(
      path: AppRouter.inventory,
      builder: (context, state) => const _ShellRoute(
        currentRoute: AppRouter.inventory,
        child: ItemListScreen(),
      ),
    ),
    GoRoute(
      path: AppRouter.customers,
      builder: (context, state) => const RoleGuard(
        allowedRoles: ['admin', 'superadmin'],
        child: _ShellRoute(
          currentRoute: AppRouter.customers,
          child: CustomerListScreen(),
        ),
      ),
    ),
    GoRoute(
      path: AppRouter.khata,
      builder: (context, state) => const RoleGuard(
        allowedRoles: ['admin', 'superadmin'],
        child: _ShellRoute(
          currentRoute: AppRouter.customers,
          child: KhataScreen(),
        ),
      ),
    ),
    GoRoute(
      path: AppRouter.reports,
      builder: (context, state) => const RoleGuard(
        allowedRoles: ['admin', 'superadmin'],
        child: _ShellRoute(
          currentRoute: AppRouter.reports,
          child: ReportsHomeScreen(),
        ),
      ),
    ),
    GoRoute(
      path: AppRouter.settings,
      builder: (context, state) => const RoleGuard(
        allowedRoles: ['admin', 'superadmin'],
        child: _ShellRoute(
          currentRoute: AppRouter.settings,
          child: SettingsScreen(),
        ),
      ),
    ),
    GoRoute(
      path: AppRouter.categories,
      builder: (context, state) => const CategoryListScreen(),
    ),
    GoRoute(
      path: AppRouter.itemAdd,
      builder: (context, state) => const ItemEditScreen(),
    ),
    GoRoute(
      path: AppRouter.itemEdit,
      builder: (context, state) {
        final id = state.extra as int?;
        return ItemEditScreen(itemId: id);
      },
    ),
    GoRoute(
      path: AppRouter.customerAdd,
      builder: (context, state) => const CustomerEditScreen(),
    ),
    GoRoute(
      path: AppRouter.customerEdit,
      builder: (context, state) {
        final id = state.extra as int?;
        return CustomerEditScreen(customerId: id);
      },
    ),
    GoRoute(
      path: AppRouter.customerKhata,
      builder: (context, state) {
        final id = state.extra as int;
        return CustomerKhataDetailScreen(customerId: id);
      },
    ),
    GoRoute(
      path: AppRouter.stockDashboard,
      builder: (context, state) => const _ShellRoute(
        currentRoute: AppRouter.inventory,
        child: StockDashboardScreen(),
      ),
    ),
    GoRoute(
      path: AppRouter.stockAdd,
      builder: (context, state) {
        final product = state.extra as Product?;
        return AddStockScreen(prefilledProduct: product);
      },
    ),
    GoRoute(
      path: AppRouter.stockHistory,
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>?;
        final productId = args?['productId'] as int?;
        final productName = args?['productName'] as String?;
        if (productId != null && productName != null) {
          return StockHistoryScreen(productId: productId, productName: productName);
        }
        return Scaffold(
          body: Center(child: Text('Not found: ${state.matchedLocation}')),
        );
      },
    ),
    GoRoute(
      path: AppRouter.returnsNew,
      builder: (context, state) => const RoleGuard(
        allowedRoles: ['admin', 'superadmin'],
        child: ReturnScreen(),
      ),
    ),
    GoRoute(
      path: AppRouter.returnsReplace,
      builder: (context, state) => const RoleGuard(
        allowedRoles: ['admin', 'superadmin'],
        child: ReplaceScreen(),
      ),
    ),
    GoRoute(
      path: AppRouter.returnsHistory,
      builder: (context, state) => const RoleGuard(
        allowedRoles: ['admin', 'superadmin'],
        child: ReturnHistoryScreen(),
      ),
    ),
    GoRoute(
      path: AppRouter.udhaarDashboard,
      builder: (context, state) => const RoleGuard(
        allowedRoles: ['admin', 'superadmin'],
        child: _ShellRoute(
          currentRoute: AppRouter.udhaarDashboard,
          child: UdhaarDashboardScreen(),
        ),
      ),
    ),
    GoRoute(
      path: AppRouter.udhaarCustomer,
      builder: (context, state) {
        final customerId = state.extra as int;
        return RoleGuard(
          allowedRoles: const ['admin', 'superadmin'],
          child: CustomerLedgerScreen(customerId: customerId),
        );
      },
    ),
    GoRoute(
      path: AppRouter.udhaarCollect,
      builder: (context, state) {
        final customerId = state.extra as int;
        return RoleGuard(
          allowedRoles: const ['admin', 'superadmin'],
          child: CollectPaymentScreen(customerId: customerId),
        );
      },
    ),
    GoRoute(
      path: AppRouter.udhaarFinal,
      builder: (context, state) {
        final customerId = state.extra as int;
        return RoleGuard(
          allowedRoles: const ['admin', 'superadmin'],
          child: FinalTotalScreen(customerId: customerId),
        );
      },
    ),
    GoRoute(
      path: AppRouter.plReport,
      builder: (context, state) => const RoleGuard(
        allowedRoles: ['admin', 'superadmin'],
        child: PLReportScreen(),
      ),
    ),
    GoRoute(
      path: AppRouter.dailyReport,
      builder: (context, state) => const RoleGuard(
        allowedRoles: ['admin', 'superadmin'],
        child: DailyReportScreen(),
      ),
    ),
    GoRoute(
      path: AppRouter.addExpense,
      builder: (context, state) => const RoleGuard(
        allowedRoles: ['admin', 'superadmin'],
        child: AddExpenseScreen(),
      ),
    ),
    GoRoute(
      path: AppRouter.expenseList,
      builder: (context, state) => const RoleGuard(
        allowedRoles: ['admin', 'superadmin'],
        child: ExpenseListScreen(),
      ),
    ),
  ],
);

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
        GoRouter.of(context).go(routes[i]);
      },
      child: child,
    );
  }
}
