import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

final largeTextProvider = StateProvider<bool>((ref) => false);

// Shop name provider - auto-fetches from settings
final shopNameProvider = FutureProvider<String>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return await repo.get('shop_name');
});

final settingsValuesProvider = FutureProvider<Map<String, String>>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return {
    'shop_name': await repo.get('shop_name'),
    'shop_address': await repo.get('shop_address'),
    'shop_phone': await repo.get('shop_phone'),
    'gstin': await repo.get('gstin'),
    'bill_footer': await repo.get('bill_footer'),
  };
});

// ===== Module Toggles =====
// These control whether features are visible and accessible in the app

final moduleSettingsProvider = FutureProvider<Map<String, bool>>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return {
    'module_udhaar': await repo.getBool('module_udhaar'),
    'module_returns': await repo.getBool('module_returns'),
    'module_replace': await repo.getBool('module_replace'),
    'module_stock_alerts': await repo.getBool('module_stock_alerts'),
    'module_daily_pl': await repo.getBool('module_daily_pl'),
    'module_khata': await repo.getBool('module_khata'),
    'module_expense_accounts': await repo.getBool('module_expense_accounts'),
    'module_multi_bill_tabs': await repo.getBool('module_multi_bill_tabs'),
    'reminder_whatsapp': await repo.getBool('reminder_whatsapp'),
    'reminder_sms': await repo.getBool('reminder_sms'),
    'reminder_pdf': await repo.getBool('reminder_pdf'),
  };
});

// Check if a specific module is enabled
final isModuleEnabledProvider = FutureProvider.family<bool, String>((
  ref,
  moduleName,
) async {
  final modules = await ref.watch(moduleSettingsProvider.future);
  return modules[moduleName] ?? true;
});

// ===== Feature Toggles (settings visible to users) =====
final featureToggleProvider = FutureProvider<Map<String, bool>>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return {
    'module_customer_name_on_bill': await repo.getBool(
      'module_customer_name_on_bill',
    ),
    'module_payment_mode_on_bill': await repo.getBool(
      'module_payment_mode_on_bill',
    ),
    'show_weight_on_bill': await repo.getBool('show_weight_on_bill'),
    'gst_enabled': await repo.getBool('gst_enabled'),
    'print_udhaar_receipt': await repo.getBool('print_udhaar_receipt'),
    'print_payment_receipt': await repo.getBool('print_payment_receipt'),
    'print_final_receipt': await repo.getBool('print_final_receipt'),
    'large_text': await repo.getBool('large_text'),
  };
});

// Session security settings
final securitySettingsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return {
    'session_timeout_minutes':
        int.tryParse(await repo.get('session_timeout_minutes')) ?? 5,
    'require_pin_on_open': await repo.getBool('require_pin_on_open'),
  };
});
