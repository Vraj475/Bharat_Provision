import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/localization/app_strings.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../inventory/inventory_providers.dart';
import '../khata/khata_providers.dart';
import 'settings_providers.dart';
import 'screens/pin_verification_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _shopNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _gstinController = TextEditingController();
  final _billFooterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSettings());
  }

  Future<void> _loadSettings() async {
    final repo = await ref.read(settingsRepositoryFutureProvider.future);
    _shopNameController.text = await repo.get('shop_name');
    _addressController.text = await repo.get('shop_address');
    _phoneController.text = await repo.get('shop_phone');
    _gstinController.text = await repo.get('gstin');
    _billFooterController.text = await repo.get('bill_footer');
    final largeText = await repo.getBool('large_text');
    ref.read(largeTextProvider.notifier).state = largeText;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _gstinController.dispose();
    _billFooterController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final repo = await ref.read(settingsRepositoryFutureProvider.future);
    final shopName = _shopNameController.text.trim();
    await repo.set('shop_name', shopName);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shop_name', shopName);
    await repo.set('shop_address', _addressController.text.trim());
    await repo.set('shop_phone', _phoneController.text.trim());
    await repo.set('gstin', _gstinController.text.trim());
    await repo.set('bill_footer', _billFooterController.text.trim());
    ref.invalidate(shopNameProvider);
    ref.invalidate(settingsValuesProvider);
    if (mounted) {
      setState(() {});
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('સેટિંગ્સ સેવ થયું')));
    }
  }

  Future<void> _exportData() async {
    try {
      final json = await AppDatabase.exportToJson();
      String path;
      if (Platform.isAndroid || Platform.isIOS) {
        final dir = await getApplicationDocumentsDirectory();
        path =
            '${dir.path}/kirana_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      } else {
        final dir = await getApplicationSupportDirectory();
        path =
            '${dir.path}/kirana_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      }
      final file = File(path);
      await file.writeAsString(json);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.exportSuccess}\n$path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.errorGeneric} $e')),
        );
      }
    }
  }

  Future<void> _importData() async {
    final ok = await ConfirmDialog.show(
      context,
      title: AppStrings.importData,
      message: AppStrings.importWarning,
      confirmLabel: 'હા, ઇમ્પોર્ટ કરો',
      isDestructive: false,
    );
    if (ok != true || !mounted) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty || !mounted) return;

      final path = result.files.single.path;
      if (path == null) return;

      final file = File(path);
      final json = await file.readAsString();
      await AppDatabase.importFromJson(json);

      ref.invalidate(itemListProvider);
      ref.invalidate(customerListProvider);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.importSuccess)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.errorGeneric} $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final largeText = ref.watch(largeTextProvider);

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.settingsTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              Text(
                AppStrings.shopProfile,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _shopNameController,
                decoration: const InputDecoration(
                  labelText: AppStrings.shopName,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: AppStrings.shopAddress,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: AppStrings.shopPhone,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _gstinController,
                decoration: const InputDecoration(labelText: AppStrings.gstin),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _billFooterController,
                decoration: const InputDecoration(
                  labelText: AppStrings.billFooter,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: AppStrings.saveButton,
                icon: Icons.save,
                onPressed: _saveProfile,
              ),
              const SizedBox(height: 32),
              Text(
                AppStrings.largeText,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SwitchListTile(
                title: const Text(AppStrings.largeText),
                contentPadding: EdgeInsets.zero,
                value: largeText,
                onChanged: (v) async {
                  ref.read(largeTextProvider.notifier).state = v;
                  final repo = await ref.read(
                    settingsRepositoryFutureProvider.future,
                  );
                  await repo.setBool('large_text', v);
                },
              ),
              const SizedBox(height: 32),
              Text(
                AppStrings.backupRestore,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                label: AppStrings.exportData,
                icon: Icons.upload_file,
                onPressed: _exportData,
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                label: AppStrings.importData,
                icon: Icons.download,
                onPressed: _importData,
              ),
              const SizedBox(height: 20),
              const Text(
                'Security Settings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: const Icon(Icons.lock, color: Colors.green),
                  title: const Text('Change PIN'),
                  subtitle: const Text('Update your login PIN'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChangePinScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
