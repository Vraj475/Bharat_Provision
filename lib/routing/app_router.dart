import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/shortcuts/app_intents.dart';
import '../core/shortcuts/app_shortcuts.dart';
import '../core/widgets/app_scaffold.dart';
import '../core/auth/role_provider.dart';
import '../core/auth/role_guard.dart';
import '../features/billing/billing_home_screen.dart';
import '../features/billing/bill_detail_screen.dart';
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
import '../features/returns/return_replace_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/screens/pin_verification_screen.dart';
import '../features/stock/stock_dashboard_screen.dart';
import '../features/stock/add_stock_screen.dart';
import '../features/stock/stock_history_screen.dart';
import '../features/settings/screens/role_selection_screen.dart';
import '../features/settings/screens/pin_entry_screen.dart';
import '../features/settings/screens/superadmin_panel_screen.dart';
import '../features/settings/screens/expense_accounts_manager_screen.dart';
import '../features/settings/screens/transliteration_dictionary_screen.dart';
import '../shared/models/product_model.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/reports/pl_report_screen.dart';
import '../features/reports/daily_report_screen.dart';
import '../features/expenses/add_expense_screen.dart';
import '../features/expenses/expense_list_screen.dart';
import '../shared/models/expense_model.dart';
import '../shared/models/bill_model.dart';

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
        allowedRoles: ['admin'],
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
        allowedRoles: ['admin'],
        child: _ShellRoute(
          currentRoute: AppRouter.customers,
          child: CustomerListScreen(),
        ),
      ),
    ),
    GoRoute(
      path: AppRouter.khata,
      builder: (context, state) => const RoleGuard(
        allowedRoles: ['admin'],
        child: _ShellRoute(
          currentRoute: AppRouter.khata,
          child: KhataScreen(),
        ),
      ),
    ),
    GoRoute(
      path: AppRouter.reports,
      builder: (context, state) => const RoleGuard(
        allowedRoles: ['admin'],
        child: _ShellRoute(
          currentRoute: AppRouter.reports,
          child: ReportsHomeScreen(),
        ),
      ),
    ),
    GoRoute(
      path: AppRouter.settings,
      builder: (context, state) => const RoleGuard(
        allowedRoles: ['admin'],
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
      builder: (context, state) => const RoleGuard(
        allowedRoles: ['admin'],
        child: CustomerEditScreen(),
      ),
    ),
    GoRoute(
      path: AppRouter.customerEdit,
      builder: (context, state) {
        final id = state.extra is int
            ? state.extra as int
            : int.tryParse(state.extra?.toString() ?? '');
        return RoleGuard(
          allowedRoles: ['admin'],
          child: CustomerEditScreen(customerId: id),
        );
      },
    ),
    GoRoute(
      path: AppRouter.customerKhata,
      builder: (context, state) {
        final id = state.extra is int
            ? state.extra as int
            : int.tryParse(state.extra?.toString() ?? '') ?? 0;
        return RoleGuard(
          allowedRoles: const ['admin', 'superadmin'],
          child: CustomerKhataDetailScreen(customerId: id),
        );
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
      builder: (context, state) {
        final extra = state.extra;
        final Bill? bill = extra is Bill ? extra : null;
        final int? billId = extra is int
            ? extra
            : (extra is Map ? extra['billId'] as int? : null);
        return RoleGuard(
          allowedRoles: const ['admin'],
          child: ReturnReplaceScreen(initialBill: bill, initialBillId: billId),
        );
      },
    ),
    GoRoute(
      path: AppRouter.returnsReplace,
      builder: (context, state) {
        final extra = state.extra;
        final Bill? bill = extra is Bill ? extra : null;
        final int? billId = extra is int
            ? extra
            : (extra is Map ? extra['billId'] as int? : null);
        return RoleGuard(
          allowedRoles: const ['admin'],
          child: ReturnReplaceScreen(initialBill: bill, initialBillId: billId),
        );
      },
    ),
    GoRoute(
      path: AppRouter.returnsHistory,
      builder: (context, state) => const RoleGuard(
        allowedRoles: ['admin'],
        child: ReturnHistoryScreen(),
      ),
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
      builder: (context, state) {
        final expense = state.extra as Expense?;
        return RoleGuard(
          allowedRoles: const ['admin'],
          child: AddExpenseScreen(expense: expense),
        );
      },
    ),
    GoRoute(
      path: AppRouter.expenseList,
      builder: (context, state) => const RoleGuard(
        allowedRoles: ['admin'],
        child: ExpenseListScreen(),
      ),
    ),
    GoRoute(
      path: AppRouter.billDetail,
      builder: (context, state) {
        final id = state.extra is int
            ? state.extra as int
            : int.tryParse(state.extra?.toString() ?? '') ?? 0;
        return BillDetailScreen(billId: id);
      },
    ),
    GoRoute(
      path: AppRouter.changePin,
      builder: (context, state) {
        final forRole = state.extra as String? ?? 'own';
        return ChangePinScreen(forRole: forRole);
      },
    ),
    GoRoute(
      path: AppRouter.pinEntry,
      builder: (context, state) {
        final role = state.extra as String;
        return PinEntryScreen(role: role);
      },
    ),
    GoRoute(
      path: AppRouter.pinVerify,
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        final title = args['title'] as String? ?? 'Verify PIN';
        final onVerified = args['onVerified'] as ValueChanged<bool>?;
        return PinVerificationScreen(
          title: title,
          onVerified: (success) {
            if (onVerified != null) {
              onVerified(success);
            } else if (success) {
              context.pop(true);
            }
          },
        );
      },
    ),
    GoRoute(
      path: AppRouter.roleSelection,
      builder: (context, state) => const RoleSelectionScreen(),
    ),
    GoRoute(
      path: AppRouter.superadminPanel,
      builder: (context, state) => const RoleGuard(
        allowedRoles: ['admin'],
        child: SuperadminPanelScreen(),
      ),
    ),
    GoRoute(
      path: AppRouter.expenseAccounts,
      builder: (context, state) => const RoleGuard(
        allowedRoles: ['admin'],
        child: ExpenseAccountsManagerScreen(),
      ),
    ),
    GoRoute(
      path: AppRouter.transliterationDict,
      builder: (context, state) => const RoleGuard(
        allowedRoles: ['admin'],
        child: TransliterationDictionaryScreen(),
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
  static const String plReport = '/reports/pl';
  static const String dailyReport = '/reports/daily';
  static const String addExpense = '/expenses/add';
  static const String expenseList = '/expenses';
  static const String billDetail = '/bill-detail';
  static const String changePin = '/settings/change-pin';
  static const String roleSelection = '/role-selection';
  static const String pinVerify = '/settings/pin-verify';
  static const String pinEntry = '/pin-entry';
  static const String superadminPanel = '/settings/superadmin';
  static const String expenseAccounts = '/settings/expense-accounts';
  static const String transliterationDict = '/settings/transliteration';

  static List<String> _mainRoutesForRole(String role) {
    final isAdmin = role == 'admin' || role == 'superadmin';
    return [
      billing,
      if (isAdmin) billHistory,
      inventory,
      customers,
      reports,
      settings,
    ];
  }

  static int indexForRoute(String route, {String role = 'admin'}) {
    if (route == dashboard) return 0;
    final i = _mainRoutesForRole(role).indexOf(route);
    return i >= 0 ? i : 0;
  }
}

class _ShellRoute extends ConsumerStatefulWidget {
  const _ShellRoute({required this.currentRoute, required this.child});

  final String currentRoute;
  final Widget child;

  @override
  ConsumerState<_ShellRoute> createState() => _ShellRouteState();
}

class _ShellRouteState extends ConsumerState<_ShellRoute> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleModuleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleModuleKey);
    super.dispose();
  }

  bool _handleModuleKey(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return false;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isMeta = HardwareKeyboard.instance.isMetaPressed;
    if (!isAlt || isCtrl || isMeta) return false;

    final key = event.logicalKey;
    int? targetIndex;
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
      targetIndex = 0;
    } else if (key == LogicalKeyboardKey.digit2 ||
        key == LogicalKeyboardKey.numpad2) {
      targetIndex = 1;
    } else if (key == LogicalKeyboardKey.digit3 ||
        key == LogicalKeyboardKey.numpad3) {
      targetIndex = 2;
    } else if (key == LogicalKeyboardKey.digit4 ||
        key == LogicalKeyboardKey.numpad4) {
      targetIndex = 3;
    } else if (key == LogicalKeyboardKey.digit5 ||
        key == LogicalKeyboardKey.numpad5) {
      targetIndex = 4;
    } else if (key == LogicalKeyboardKey.digit6 ||
        key == LogicalKeyboardKey.numpad6) {
      targetIndex = 5;
    }

    if (targetIndex != null) {
      final role = ref.read(currentRoleProvider);
      final routes = AppRouter._mainRoutesForRole(role);
      if (targetIndex >= 0 && targetIndex < routes.length) {
        GoRouter.of(context).go(routes[targetIndex]);
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentRoleProvider);
    final routes = AppRouter._mainRoutesForRole(role);
    final currentIndex =
        AppRouter.indexForRoute(widget.currentRoute, role: role);

    return Shortcuts(
      shortcuts: AppShortcuts.moduleShortcuts,
      child: Actions(
        actions: {
          NavigateToModuleIntent: CallbackAction<NavigateToModuleIntent>(
            onInvoke: (intent) {
              if (intent.moduleIndex >= 0 &&
                  intent.moduleIndex < routes.length) {
                GoRouter.of(context).go(routes[intent.moduleIndex]);
              }
              return null;
            },
          ),
        },
        child: AppScaffold(
          currentIndex: currentIndex,
          onDestinationSelected: (i) {
            if (i < 0 || i >= routes.length) return;
            GoRouter.of(context).go(routes[i]);
          },
          child: widget.child,
        ),
      ),
    );
  }
}
