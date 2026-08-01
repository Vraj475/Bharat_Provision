import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'repositories/bill_repository.dart';
import 'repositories/customer_repository.dart';
import 'repositories/item_repository.dart';
import 'repositories/khata_repository.dart';
import 'repositories/report_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/user_repository.dart';
import '../core/services/backup_service.dart';

final databaseProvider = Provider<Database>((ref) {
  throw UnimplementedError('databaseProvider must be overridden');
});

final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  return ItemRepository(ref.watch(databaseProvider));
});

final billRepositoryProvider = Provider<BillRepository>((ref) {
  return BillRepository(ref.watch(databaseProvider));
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ref.watch(databaseProvider));
});

final khataRepositoryProvider = Provider<KhataRepository>((ref) {
  return KhataRepository(ref.watch(databaseProvider));
});

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository(ref.watch(databaseProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(databaseProvider));
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(databaseProvider));
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(databaseProvider));
});
