import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/database_helper.dart';
import '../core/services/backup_service.dart';
import 'repositories/bill_repository.dart';
import 'repositories/customer_repository.dart';
import 'repositories/expense_repository.dart';
import 'repositories/item_repository.dart';
import 'repositories/khata_repository.dart';
import 'repositories/report_repository.dart';
import 'repositories/return_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/stock_repository.dart';
import 'repositories/udhaar_repository.dart';

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  return ItemRepository(ref.watch(databaseHelperProvider));
});

final billRepositoryProvider = Provider<BillRepository>((ref) {
  return BillRepository(ref.watch(databaseHelperProvider));
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ref.watch(databaseHelperProvider));
});

final khataRepositoryProvider = Provider<KhataRepository>((ref) {
  return KhataRepository(ref.watch(databaseHelperProvider));
});

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository(ref.watch(databaseHelperProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(databaseHelperProvider));
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(databaseHelperProvider));
});

final stockRepositoryProvider = Provider<StockRepository>((ref) {
  return StockRepository(ref.watch(databaseHelperProvider));
});

final udhaarRepositoryProvider = Provider<UdhaarRepository>((ref) {
  return UdhaarRepository(ref.watch(databaseHelperProvider));
});

final returnRepositoryProvider = Provider<ReturnRepository>((ref) {
  return ReturnRepository(ref.watch(databaseHelperProvider));
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(databaseHelperProvider));
});
