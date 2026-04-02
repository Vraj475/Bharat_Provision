import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../settings_providers.dart';
import '../../../data/providers.dart';
import 'pin_verification_screen.dart';

class SuperadminPanelScreen extends ConsumerStatefulWidget {
  const SuperadminPanelScreen({super.key});

  @override
  ConsumerState<SuperadminPanelScreen> createState() =>
      _SuperadminPanelScreenState();
}

class _SuperadminPanelScreenState extends ConsumerState<SuperadminPanelScreen>
    with SingleTickerProviderStateMixin {
  bool _isPinVerified = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _verifyPin();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _verifyPin() async {
    // Show PIN verification
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => PinVerificationScreen(
          title: 'Superadmin Authentication',
          onVerified: (verified) {},
        ),
      ),
    );

    if (!mounted) return;
    if (verified ?? false) {
      setState(() {
        _isPinVerified = true;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);

    // Check superadmin access
    if (session == null || session.role != 'superadmin') {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Text('Only Superadmin can access this panel'),
        ),
      );
    }

    // If not verified, show message
    if (!_isPinVerified) {
      return Scaffold(
        appBar: AppBar(title: const Text('Superadmin Panel')),
        body: const Center(child: Text('Verifying PIN...')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🟣 Superadmin Panel'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'સુવિધા'),
            Tab(text: 'વપરાશકર્તા'),
            Tab(text: 'દુકાન'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_ModuleManagerTab(), _UserManagerTab(), _ShopConfigTab()],
      ),
    );
  }
}

// === Module Manager Tab ===
class _ModuleManagerTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moduleSettings = ref.watch(moduleSettingsProvider);

    return moduleSettings.when(
      data: (modules) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'સુવિધા ઓન/ઓફ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'These toggles completely remove features from the app UI',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Column(
                children: [
                  _ModuleToggle(
                    label: 'ઉધાર સિસ્ટમ',
                    module: 'module_udhaar',
                    value: modules['module_udhaar'] ?? true,
                  ),
                  const Divider(height: 1),
                  _ModuleToggle(
                    label: 'રિટર્ન સિસ્ટમ',
                    module: 'module_returns',
                    value: modules['module_returns'] ?? true,
                  ),
                  const Divider(height: 1),
                  _ModuleToggle(
                    label: 'બદલી સિસ્ટમ',
                    module: 'module_replace',
                    value: modules['module_replace'] ?? true,
                  ),
                  const Divider(height: 1),
                  _ModuleToggle(
                    label: 'સ્ટોક ચેતવણી',
                    module: 'module_stock_alerts',
                    value: modules['module_stock_alerts'] ?? true,
                  ),
                  const Divider(height: 1),
                  _ModuleToggle(
                    label: 'P&L રિપોર્ટ',
                    module: 'module_daily_pl',
                    value: modules['module_daily_pl'] ?? true,
                  ),
                  const Divider(height: 1),
                  _ModuleToggle(
                    label: 'ખાતું (Khata)',
                    module: 'module_khata',
                    value: modules['module_khata'] ?? true,
                  ),
                  const Divider(height: 1),
                  _ModuleToggle(
                    label: 'ખર્ચ ખાતા',
                    module: 'module_expense_accounts',
                    value: modules['module_expense_accounts'] ?? true,
                  ),
                  const Divider(height: 1),
                  _ModuleToggle(
                    label: '5 બિલ ટેબ',
                    module: 'module_multi_bill_tabs',
                    value: modules['module_multi_bill_tabs'] ?? true,
                  ),
                  const Divider(height: 1),
                  _ModuleToggle(
                    label: 'WhatsApp',
                    module: 'reminder_whatsapp',
                    value: modules['reminder_whatsapp'] ?? false,
                  ),
                  const Divider(height: 1),
                  _ModuleToggle(
                    label: 'SMS',
                    module: 'reminder_sms',
                    value: modules['reminder_sms'] ?? false,
                  ),
                  const Divider(height: 1),
                  _ModuleToggle(
                    label: 'PDF સ્ટેટમેન્ટ',
                    module: 'reminder_pdf',
                    value: modules['reminder_pdf'] ?? false,
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

class _ModuleToggle extends ConsumerWidget {
  final String label;
  final String module;
  final bool value;

  const _ModuleToggle({
    required this.label,
    required this.module,
    required this.value,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label)),
          Switch(
            value: value,
            onChanged: (newValue) async {
              final repo = await ref.read(
                settingsRepositoryFutureProvider.future,
              );
              await repo.setBool(module, newValue);
              ref.invalidate(moduleSettingsProvider);
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('સેટિંગ સેવ થયું')));
            },
          ),
        ],
      ),
    );
  }
}

// === User Manager Tab ===
class _UserManagerTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'વપરાશકર્તા',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              const ChangePinScreen(forRole: 'admin'),
                        ),
                      );
                    },
                    child: const Text('Change Admin PIN'),
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              const ChangePinScreen(forRole: 'employee'),
                        ),
                      );
                    },
                    child: const Text('Change Employee PIN'),
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final db = await ref.read(databaseProvider.future);
                      final columns = await db.rawQuery(
                        'PRAGMA table_info(users)',
                      );
                      final hasLastLogin = columns.any(
                        (c) => (c['name'] as String?) == 'last_login',
                      );

                      final rows = await db.query('users');
                      String formatValue(dynamic raw) {
                        if (!hasLastLogin || raw == null) return 'N/A';
                        if (raw is int) {
                          final dt = DateTime.fromMillisecondsSinceEpoch(raw);
                          return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                        }
                        final text = raw.toString();
                        final parsed = DateTime.tryParse(text);
                        if (parsed == null) return text;
                        return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
                      }

                      String roleLastLogin(String role) {
                        final row = rows.firstWhere(
                          (r) => (r['role'] as String?) == role,
                          orElse: () => <String, Object?>{},
                        );
                        return formatValue(row['last_login']);
                      }

                      if (!context.mounted) return;
                      await showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('છેલ્લો લોગિન સમય'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Superadmin: ${roleLastLogin('superadmin')}',
                              ),
                              Text('Admin: ${roleLastLogin('admin')}'),
                              Text('Employee: ${roleLastLogin('employee')}'),
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
                    },
                    child: const Text('View Last Login Times'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// === Shop Config Tab ===
class _ShopConfigTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ShopConfigTab> createState() => _ShopConfigTabState();
}

class _ShopConfigTabState extends ConsumerState<_ShopConfigTab> {
  late TextEditingController _shopNameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _notesController;
  String _wipeConfirmationText = '';

  @override
  void initState() {
    super.initState();
    _shopNameController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsValues = ref.watch(settingsValuesProvider);

    return settingsValues.when(
      data: (data) {
        _shopNameController.text = data['shop_name'] ?? '';
        _addressController.text = data['shop_address'] ?? '';
        _phoneController.text = data['shop_phone'] ?? '';

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'દુકાન સેટ (Resell Config)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Configure this installation for a new shop',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _shopNameController,
                      decoration: const InputDecoration(
                        labelText: 'Shop Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'License Notes',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final repo = await ref.read(
                            settingsRepositoryFutureProvider.future,
                          );
                          await repo.set(
                            'shop_name',
                            _shopNameController.text.trim(),
                          );
                          await repo.set(
                            'shop_address',
                            _addressController.text.trim(),
                          );
                          await repo.set(
                            'shop_phone',
                            _phoneController.text.trim(),
                          );
                          await repo.set(
                            'license_notes',
                            _notesController.text.trim(),
                          );
                          ref.invalidate(settingsValuesProvider);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('સેટિંગ સેવ થયું')),
                          );
                        },
                        child: const Text('Save Configuration'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Wipe all data section
            const Text(
              'Danger Zone',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Wipe All Data',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This will delete all data. Type "RESET" to confirm.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Type RESET to confirm',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() => _wipeConfirmationText = value.trim());
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () async {
                          if (_wipeConfirmationText != 'RESET') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('પહેલા RESET લખો')),
                            );
                            return;
                          }

                          final resetConfirmed = await _showResetWordDialog();
                          if (!resetConfirmed || !context.mounted) return;

                          final pinOk = await _showSuperadminPinDialog();
                          if (!pinOk || !context.mounted) return;

                          final db = await ref.read(databaseProvider.future);
                          await db.transaction((txn) async {
                            await txn.execute('PRAGMA foreign_keys = OFF');
                            final tables = await txn.rawQuery(
                              "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
                            );
                            for (final t in tables) {
                              final name = t['name'] as String;
                              if (name == 'users' || name == 'settings')
                                continue;
                              await txn.delete(name);
                            }
                            await txn.execute('PRAGMA foreign_keys = ON');
                          });

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ડેટા સાફ થઈ ગયો')),
                          );
                        },
                        child: const Text('Wipe All Data and Reset'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Future<bool> _showResetWordDialog() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ખાતરી કરો'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'RESET લખો',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('રદ કરો'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim() == 'RESET'),
            child: const Text('ખાતરી કરો'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<bool> _showSuperadminPinDialog() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Superadmin PIN દાખલ કરો'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          decoration: const InputDecoration(
            labelText: '4-digit PIN',
            border: OutlineInputBorder(),
          ),
        ),
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

    if (confirmed != true) return false;
    final pinService = ref.read(pinStorageProvider);
    return pinService.verifyPin('superadmin', controller.text.trim());
  }
}
