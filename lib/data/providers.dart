import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'db/app_database.dart';
import 'repositories/bill_repository.dart';
import 'repositories/customer_repository.dart';
import 'repositories/item_repository.dart';
import 'repositories/khata_repository.dart';
import 'repositories/report_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/user_repository.dart';

final databaseProvider = FutureProvider<Database>((ref) async {
  return AppDatabase.instance;
});

final itemRepositoryFutureProvider = FutureProvider<ItemRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return ItemRepository(db);
});

final billRepositoryFutureProvider = FutureProvider<BillRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return BillRepository(db);
});

final customerRepositoryFutureProvider =
    FutureProvider<CustomerRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return CustomerRepository(db);
});

final khataRepositoryFutureProvider = FutureProvider<KhataRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return KhataRepository(db);
});

final reportRepositoryFutureProvider =
    FutureProvider<ReportRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return ReportRepository(db);
});

final settingsRepositoryFutureProvider =
    FutureProvider<SettingsRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return SettingsRepository(db);
});

final userRepositoryFutureProvider = FutureProvider<UserRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return UserRepository(db);
});
