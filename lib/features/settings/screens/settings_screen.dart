// ignore_for_file: dead_code, dead_null_aware_expression

import 'dart:io';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/auth_provider.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/errors/error_handler.dart';
import '../settings_providers.dart';
import 'superadmin_panel_screen.dart';
import 'expense_accounts_manager_screen.dart';
import 'transliteration_dictionary_screen.dart';
import 'pin_verification_screen.dart';
import '../../../data/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);

    // Check access - only Admin and Superadmin
    if (session == null ||
        (session.role != 'admin' && session.role != 'superadmin')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Text('Only Admin and Superadmin can access settings'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('દુકાનની સેટિંગ'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            const Tab(text: 'દુકાન'),
            const Tab(text: 'બિલ'),
            const Tab(text: 'પ્રિન્ટ'),
            const Tab(text: 'રીમાઇન્ડર'),
            const Tab(text: 'સુરક્ષા'),
            const Tab(text: 'ડિસ્પ્લે'),
            const Tab(text: 'ડેટા'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ShopInfoTab(),
          _BillSettingsTab(),
          _PrintSettingsTab(),
          _ReminderSettingsTab(),
          _SecuritySettingsTab(),
          _DisplaySettingsTab(),
          _DataManagementTab(),
        ],
      ),
      floatingActionButton: session.role == 'superadmin'
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SuperadminPanelScreen(),
                  ),
                );
              },
              label: const Text('Superadmin Panel'),
              icon: const Icon(Icons.admin_panel_settings),
            )
          : null,
    );
  }
}

// === Shop Info Tab ===
class _ShopInfoTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsValuesProvider);

    return settings.when(
      data: (data) {
        return _SettingsForm(
          sections: [
            _SettingsSection(
              title: 'દુકાનની માહિતી',
              fields: [
                _TextSettingField(
                  label: 'Shop Name',
                  value: data['shop_name']!,
                  onSave: (value) async {
                    final repo = await ref.read(
                      settingsRepositoryFutureProvider.future,
                    );
                    await repo.set('shop_name', value);
                    ref.invalidate(settingsValuesProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Shop Name Saved')),
                      );
                    }
                  },
                ),
                _TextSettingField(
                  label: 'Address',
                  value: data['shop_address']!,
                  onSave: (value) async {
                    final repo = await ref.read(
                      settingsRepositoryFutureProvider.future,
                    );
                    await repo.set('shop_address', value);
                    ref.invalidate(settingsValuesProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Address Saved')),
                      );
                    }
                  },
                ),
                _TextSettingField(
                  label: 'Phone',
                  value: data['shop_phone']!,
                  onSave: (value) async {
                    final repo = await ref.read(
                      settingsRepositoryFutureProvider.future,
                    );
                    await repo.set('shop_phone', value);
                    ref.invalidate(settingsValuesProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Phone Saved')),
                      );
                    }
                  },
                ),
                _TextSettingField(
                  label: 'GST Number',
                  value: data['gstin']!,
                  onSave: (value) async {
                    final repo = await ref.read(
                      settingsRepositoryFutureProvider.future,
                    );
                    await repo.set('gstin', value);
                    ref.invalidate(settingsValuesProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('GST Number Saved')),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

// === Bill Settings Tab ===
class _BillSettingsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featureToggles = ref.watch(featureToggleProvider);

    return featureToggles.when(
      data: (data) {
        return _SettingsForm(
          sections: [
            _SettingsSection(
              title: 'બિલ સેટિંગ',
              fields: [
                _BoolSettingField(
                  label: 'ગ્રાહકનું નામ બિલ પર',
                  value: data['module_customer_name_on_bill']!,
                  onChanged: (value) async {
                    final repo = await ref.read(
                      settingsRepositoryFutureProvider.future,
                    );
                    await repo.setBool('module_customer_name_on_bill', value);
                    ref.invalidate(featureToggleProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('સેટિંગ સેવ થયું')),
                      );
                    }
                  },
                ),
                _BoolSettingField(
                  label: 'ચૂકવણી પ્રકાર બિલ પર',
                  value: data['module_payment_mode_on_bill']!,
                  onChanged: (value) async {
                    final repo = await ref.read(
                      settingsRepositoryFutureProvider.future,
                    );
                    await repo.setBool('module_payment_mode_on_bill', value);
                    ref.invalidate(featureToggleProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('સેટિંગ સેવ થયું')),
                      );
                    }
                  },
                ),
                _BoolSettingField(
                  label: 'વજન બિલ પર',
                  value: data['show_weight_on_bill']!,
                  onChanged: (value) async {
                    final repo = await ref.read(
                      settingsRepositoryFutureProvider.future,
                    );
                    await repo.setBool('show_weight_on_bill', value);
                    ref.invalidate(featureToggleProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('સેટિંગ સેવ થયું')),
                      );
                    }
                  },
                ),
                _BoolSettingField(
                  label: 'GST ગણતરી',
                  value: data['gst_enabled']!,
                  onChanged: (value) async {
                    final repo = await ref.read(
                      settingsRepositoryFutureProvider.future,
                    );
                    await repo.setBool('gst_enabled', value);
                    ref.invalidate(featureToggleProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('સેટિંગ સેવ થયું')),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

// === Print Settings Tab ===
class _PrintSettingsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featureToggles = ref.watch(featureToggleProvider);

    return featureToggles.when(
      data: (data) {
        return _SettingsForm(
          sections: [
            _SettingsSection(
              title: 'પ્રિન્ટ સેટિંગ',
              fields: [
                _BoolSettingField(
                  label: 'ઉધારે બિલ છાપો',
                  value: data['print_udhaar_receipt']!,
                  onChanged: (value) async {
                    final repo = await ref.read(
                      settingsRepositoryFutureProvider.future,
                    );
                    await repo.setBool('print_udhaar_receipt', value);
                    ref.invalidate(featureToggleProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('સેટિંગ સેવ થયું')),
                      );
                    }
                  },
                ),
                _BoolSettingField(
                  label: 'ચૂકવણી રસીદ છાપો',
                  value: data['print_payment_receipt']!,
                  onChanged: (value) async {
                    final repo = await ref.read(
                      settingsRepositoryFutureProvider.future,
                    );
                    await repo.setBool('print_payment_receipt', value);
                    ref.invalidate(featureToggleProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('સેટિંગ સેવ થયું')),
                      );
                    }
                  },
                ),
                _BoolSettingField(
                  label: 'અંતિમ ચૂકવણી રસીદ',
                  value: data['print_final_receipt']!,
                  onChanged: (value) async {
                    final repo = await ref.read(
                      settingsRepositoryFutureProvider.future,
                    );
                    await repo.setBool('print_final_receipt', value);
                    ref.invalidate(featureToggleProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('સેટિંગ સેવ થયું')),
                      );
                    }
                  },
                ),
              ],
            ),
            _SettingsSection(
              title: 'પ્રિન્ટર કનેક્શન',
              fields: [
                _ActionSettingField(
                  label: 'Bluetooth Printer Connect',
                  onPressed: () async {
                    await _SettingsActions.connectBluetoothPrinter(context);
                  },
                ),
                _ActionSettingField(
                  label: 'Test Print',
                  onPressed: () async {
                    await _SettingsActions.sendTestPrint(context);
                  },
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

// === Reminder Settings Tab ===
class _ReminderSettingsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featureToggles = ref.watch(featureToggleProvider);

    return featureToggles.when(
      data: (data) {
        return _SettingsForm(
          sections: [
            _SettingsSection(
              title: 'રીમાઇન્ડર સેટિંગ',
              fields: [
                _BoolSettingField(
                  label: 'WhatsApp રીમાઇન્ડર',
                  value: data['reminder_whatsapp']!,
                  onChanged: (value) async {
                    final repo = await ref.read(
                      settingsRepositoryFutureProvider.future,
                    );
                    await repo.setBool('reminder_whatsapp', value);
                    ref.invalidate(featureToggleProvider);
                    ref.invalidate(moduleSettingsProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('સેટિંગ સેવ થયું')),
                      );
                    }
                  },
                ),
                _BoolSettingField(
                  label: 'SMS રીમાઇન્ડર',
                  value: data['reminder_sms']!,
                  onChanged: (value) async {
                    final repo = await ref.read(
                      settingsRepositoryFutureProvider.future,
                    );
                    await repo.setBool('reminder_sms', value);
                    ref.invalidate(featureToggleProvider);
                    ref.invalidate(moduleSettingsProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('સેટિંગ સેવ થયું')),
                      );
                    }
                  },
                ),
                _BoolSettingField(
                  label: 'PDF સ્ટેટમેન્ટ',
                  value: data['reminder_pdf']!,
                  onChanged: (value) async {
                    final repo = await ref.read(
                      settingsRepositoryFutureProvider.future,
                    );
                    await repo.setBool('reminder_pdf', value);
                    ref.invalidate(featureToggleProvider);
                    ref.invalidate(moduleSettingsProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('સેટિંગ સેવ થયું')),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

// === Security Settings Tab ===
class _SecuritySettingsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final securitySettings = ref.watch(securitySettingsProvider);

    return securitySettings.when(
      data: (data) {
        return _SettingsForm(
          sections: [
            _SettingsSection(
              title: 'સુરક્ષા',
              fields: [
                _IntSettingField(
                  label: 'Session Timeout (minutes)',
                  value: data['session_timeout_minutes'] as int,
                  onChanged: (value) async {
                    final repo = await ref.read(
                      settingsRepositoryFutureProvider.future,
                    );
                    await repo.set('session_timeout_minutes', value.toString());
                    ref.invalidate(securitySettingsProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('સેટિંગ સેવ થયું')),
                      );
                    }
                  },
                ),
                _BoolSettingField(
                  label: 'Require PIN on Open',
                  value: data['require_pin_on_open'] as bool,
                  onChanged: (value) async {
                    final repo = await ref.read(
                      settingsRepositoryFutureProvider.future,
                    );
                    await repo.setBool('require_pin_on_open', value);
                    ref.invalidate(securitySettingsProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('સેટિંગ સેવ થયું')),
                      );
                    }
                  },
                ),
              ],
            ),
            _SettingsSection(
              title: 'PIN Management',
              fields: [
                _ActionSettingField(
                  label: 'Change My PIN',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            const ChangePinScreen(forRole: 'own'),
                      ),
                    );
                  },
                ),
                _ActionSettingField(
                  label: 'Change Employee PIN',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            const ChangePinScreen(forRole: 'employee'),
                      ),
                    );
                  },
                ),
              ],
            ),
            _SettingsSection(
              title: 'PIN Security',
              fields: [
                _ActionSettingField(
                  label: 'Change PIN',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            const ChangePinScreen(forRole: 'own'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

// === Display Settings Tab ===
class _DisplaySettingsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featureToggles = ref.watch(featureToggleProvider);
    final largeText = ref.watch(largeTextProvider);

    return featureToggles.when(
      data: (data) {
        return _SettingsForm(
          sections: [
            _SettingsSection(
              title: 'ડિસ્પ્લે',
              fields: [
                _BoolSettingField(
                  label: 'મોટો ટેક્સ્ટ (+20%)',
                  value: largeText,
                  onChanged: (value) async {
                    ref.read(largeTextProvider.notifier).state = value;
                    final repo = await ref.read(
                      settingsRepositoryFutureProvider.future,
                    );
                    await repo.setBool('large_text', value);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('સેટિંગ સેવ થયું')),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

// === Data Management Tab ===
class _DataManagementTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsForm(
      sections: [
        _SettingsSection(
          title: 'Managers',
          fields: [
            _ActionSettingField(
              label: 'Expense Accounts',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ExpenseAccountsManagerScreen(),
                  ),
                );
              },
            ),
            _ActionSettingField(
              label: 'Transliteration Dictionary',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        const TransliterationDictionaryScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        _SettingsSection(
          title: 'ડેટા',
          fields: [
            _ActionSettingField(
              label: 'Export as JSON Backup',
              onPressed: () async {
                await _SettingsActions.exportBackup(context);
              },
            ),
            _ActionSettingField(
              label: 'View Database Info',
              onPressed: () async {
                await _SettingsActions.showDatabaseStats(context, ref);
              },
            ),
            _ActionSettingField(
              label: 'Reset Bill Counter',
              onPressed: () async {
                await _SettingsActions.resetBillCounterWithConfirmation(
                  context,
                  ref,
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _SettingsActions {
  static final BlueThermalPrinter _printer = BlueThermalPrinter.instance;

  static Future<void> connectBluetoothPrinter(BuildContext context) async {
    if (Platform.isWindows) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Windows માં USB printer Windows Settings થી કનેક્ટ કરો.',
          ),
        ),
      );
      return;
    }

    if (!Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bluetooth printer support Android માટે ઉપલબ્ધ છે.'),
        ),
      );
      return;
    }

    try {
      final devices = await _printer.getBondedDevices();
      if (!context.mounted) return;
      if (devices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('કોઈ paired Bluetooth printer મળ્યો નહીં.'),
          ),
        );
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) {
          return ListView(
            children: devices
                .map(
                  (d) => ListTile(
                    leading: const Icon(Icons.print),
                    title: Text(d.name ?? 'Unknown Printer'),
                    subtitle: Text(d.address ?? ''),
                    onTap: () async {
                      try {
                        await _printer.connect(d);
                        if (!sheetContext.mounted) return;
                        Navigator.of(sheetContext).pop();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Printer connected: ${d.name ?? d.address}',
                            ),
                          ),
                        );
                      } catch (e, st) {
                        if (!sheetContext.mounted) return;
                        Navigator.of(sheetContext).pop();
                        if (!context.mounted) return;
                        ErrorHandler.handleAndShowSnackbar(
                          context,
                          e,
                          st,
                          contextDescription:
                              'Settings.connectBluetoothPrinter',
                        );
                      }
                    },
                  ),
                )
                .toList(),
          );
        },
      );
    } catch (e, st) {
      if (!context.mounted) return;
      ErrorHandler.handleAndShowSnackbar(
        context,
        e,
        st,
        contextDescription: 'Settings.connectBluetoothPrinter',
      );
    }
  }

  static Future<void> sendTestPrint(BuildContext context) async {
    try {
      final connected = await _printer.isConnected ?? false;
      if (!connected) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PRINT_001: પ્રિન્ટર કનેક્ટ નથી.')),
        );
        return;
      }

      final now = DateTime.now();
      await _printer.printCustom('Kirana Shop', 2, 1);
      await _printer.printCustom(
        DateFormat('dd/MM/yyyy HH:mm').format(now),
        1,
        1,
      );
      await _printer.printCustom('ટેસ્ટ પ્રિન્ટ સફળ', 2, 1);
      await _printer.printNewLine();

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ટેસ્ટ પ્રિન્ટ મોકલાયું')));
    } catch (e, st) {
      if (!context.mounted) return;
      ErrorHandler.handleAndShowSnackbar(
        context,
        e,
        st,
        contextDescription: 'Settings.sendTestPrint',
      );
    }
  }

  static Future<void> exportBackup(BuildContext context) async {
    try {
      final json = await DatabaseHelper.instance.exportToJson();
      final dir = await getApplicationDocumentsDirectory();
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path =
          '${dir.path}${Platform.pathSeparator}KiranaBackup_$stamp.json';
      final file = File(path);
      await file.writeAsString(json);
      await Share.shareXFiles([XFile(path)], text: 'Kirana backup');

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ડેટા નિકાસ થઈ ગયો')));
    } catch (e, st) {
      if (!context.mounted) return;
      ErrorHandler.handleAndShowSnackbar(
        context,
        e,
        st,
        contextDescription: 'Settings.exportBackup',
      );
    }
  }

  static Future<void> showDatabaseStats(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final db = await ref.read(databaseProvider.future);
      final products = await _readCount(db, ['products', 'items']);
      final bills = await _readCount(db, ['bills']);
      final customers = await _readCount(db, ['customers']);
      final stockEntries = await _readCount(db, ['stock_log', 'purchases']);
      final udhaarEntries = await _readCount(db, [
        'udhaar_ledger',
        'khata_entries',
      ]);

      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ડેટાબેસ આંકડા'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ઉત્પાદન: $products'),
              Text('બિલ: $bills'),
              Text('ગ્રાહકો: $customers'),
              Text('સ્ટોક એન્ટ્રી: $stockEntries'),
              Text('ઉધાર એન્ટ્રી: $udhaarEntries'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('બંધ કરો'),
            ),
          ],
        ),
      );
    } catch (e, st) {
      if (!context.mounted) return;
      ErrorHandler.handleAndShowSnackbar(
        context,
        e,
        st,
        contextDescription: 'Settings.showDatabaseStats',
      );
    }
  }

  static Future<int> _readCount(dynamic db, List<String> tables) async {
    for (final table in tables) {
      try {
        final row = await db.rawQuery('SELECT COUNT(*) as c FROM $table');
        return (row.first['c'] as int?) ?? 0;
      } catch (_) {
        // Try fallback table names.
      }
    }
    return 0;
  }

  static Future<void> resetBillCounterWithConfirmation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ખાતરી કરો'),
        content: const Text('શું તમે Bill Counter રીસેટ કરવા માંગો છો?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('રદ કરો'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ખાતરી કરો'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    try {
      final repo = await ref.read(settingsRepositoryFutureProvider.future);
      await repo.set('bill_counter', '1');
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('સેટિંગ સેવ થયું')));
    } catch (e, st) {
      if (!context.mounted) return;
      ErrorHandler.handleAndShowSnackbar(
        context,
        e,
        st,
        contextDescription: 'Settings.resetBillCounter',
      );
    }
  }
}

// === UI Components ===

class _SettingsForm extends StatelessWidget {
  final List<_SettingsSection> sections;

  const _SettingsForm({required this.sections});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: sections[index],
        );
      },
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> fields;

  const _SettingsSection({required this.title, required this.fields});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          child: Column(
            children: [
              for (int i = 0; i < fields.length; i++) ...[
                Padding(padding: const EdgeInsets.all(16), child: fields[i]),
                if (i < fields.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BoolSettingField extends StatelessWidget {
  final String label;
  final bool value;
  final Function(bool) onChanged;

  const _BoolSettingField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _TextSettingField extends StatefulWidget {
  final String label;
  final String value;
  final Function(String) onSave;

  const _TextSettingField({
    required this.label,
    required this.value,
    required this.onSave,
  });

  @override
  State<_TextSettingField> createState() => _TextSettingFieldState();
}

class _TextSettingFieldState extends State<_TextSettingField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
      ),
      onSubmitted: (value) => widget.onSave(value),
    );
  }
}

class _IntSettingField extends StatefulWidget {
  final String label;
  final int value;
  final Function(int) onChanged;

  const _IntSettingField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_IntSettingField> createState() => _IntSettingFieldState();
}

class _IntSettingFieldState extends State<_IntSettingField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      onSubmitted: (value) {
        final intValue = int.tryParse(value);
        if (intValue != null) {
          widget.onChanged(intValue);
        }
      },
    );
  }
}

class _ActionSettingField extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _ActionSettingField({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(onPressed: onPressed, child: Text(label)),
    );
  }
}
