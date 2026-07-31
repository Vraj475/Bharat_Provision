import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/customer_model.dart';
import '../../data/models/khata_entry.dart';
import '../../data/providers.dart';

final customerSearchProvider = StateProvider<String>((ref) => '');

// ─── Master Customer Provider - Single Source of Truth for All Customers ─────

class CustomersNotifier extends AsyncNotifier<List<Customer>> {
  @override
  Future<List<Customer>> build() async {
    final repo = ref.watch(customerRepositoryProvider);
    return repo.getAll();
  }

  /// Update customer's outstanding balance and reload providers
  Future<void> updateOutstanding(int customerId, double newOutstanding) async {
    final repo = ref.read(customerRepositoryProvider);
    final customer = await repo.getById(customerId);
    if (customer != null) {
      await repo.update(customer.copyWith());

      // Reload customers after update
      state = await AsyncValue.guard(() => _reloadCustomers());
    }
  }

  /// Reload all customers from database
  Future<List<Customer>> _reloadCustomers() async {
    final repo = ref.read(customerRepositoryProvider);
    return repo.getAll();
  }
}

/// MASTER provider for all customers - single source of truth
/// All screens showing customer data should watch this provider
final customersProvider =
    AsyncNotifierProvider<CustomersNotifier, List<Customer>>(
      () => CustomersNotifier(),
    );

final customerListProvider = FutureProvider<List<Customer>>((ref) async {
  final repo = ref.watch(customerRepositoryProvider);
  final query = ref.watch(customerSearchProvider);
  return repo.search(query);
});

final customerWithBalanceProvider =
    FutureProvider.family<({Customer customer, double balance}), int>((
      ref,
      customerId,
    ) async {
      final customerRepo = ref.watch(
        customerRepositoryProvider,
      );
      final khataRepo = ref.watch(khataRepositoryProvider);
      final customer = await customerRepo.getById(customerId);
      if (customer == null) throw StateError('Customer not found');
      final balance = await khataRepo.getBalance(customerId);
      return (customer: customer, balance: balance);
    });

final customerKhataEntriesProvider =
    FutureProvider.family<List<KhataEntry>, int>((ref, customerId) async {
      final repo = ref.watch(khataRepositoryProvider);
      return repo.getEntries(customerId);
    });
