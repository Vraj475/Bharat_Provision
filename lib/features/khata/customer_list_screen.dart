import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_format.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../shared/models/customer_model.dart';
import '../../data/providers.dart';
import '../../routing/app_router.dart';
import 'khata_providers.dart';
import 'package:go_router/go_router.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      ref.read(customerSearchProvider.notifier).state = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _balanceColor(double balance) {
    if (balance > 0) return AppColors.alert;
    if (balance < 0) return AppColors.success;
    return AppColors.warning;
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerListProvider);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText:
                    '${AppStrings.customerName} અથવા ${AppStrings.phone} શોધો',
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: customersAsync.when(
              data: (customers) => _CustomerListWithBalances(
                customers: customers,
                balanceColor: _balanceColor,
                onCustomerTap: (c) => Navigator.of(
                  context,
                ).pushNamed(AppRouter.customerKhata, arguments: c.id),
                onDelete: (_, c) => _confirmDelete(c),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('${AppStrings.errorGeneric} $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRouter.customerAdd),
        icon: const Icon(Icons.add),
        label: const Text(AppStrings.addCustomer),
      ),
    );
  }

  Future<void> _confirmDelete(Customer customer) async {
    final ok = await ConfirmDialog.show(
      context,
      title: AppStrings.deleteCustomerTitle,
      message: AppStrings.deleteCustomerMessage,
    );
    if (ok != true || !mounted) return;

    String message;
    try {
      final repo = ref.read(customerRepositoryProvider);
      await repo.delete(customer.id!);
      ref.invalidate(customerListProvider);
      message = 'ગ્રાહક સફળતાપૂર્વક કાઢી નાખ્યું';
    } catch (e) {
      message = '${AppStrings.errorGeneric} $e';
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CustomerListWithBalances extends ConsumerWidget {
  const _CustomerListWithBalances({
    required this.customers,
    required this.balanceColor,
    required this.onCustomerTap,
    required this.onDelete,
  });

  final List<Customer> customers;
  final Color Function(double) balanceColor;
  final void Function(Customer) onCustomerTap;
  final void Function(BuildContext, Customer) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (customers.isEmpty) {
      return Center(child: Text(AppStrings.noCustomersFound));
    }

    return ListView.builder(
      itemCount: customers.length,
      itemBuilder: (ctx, i) {
        final c = customers[i];
        return FutureBuilder<double>(
          future: ref.read(khataRepositoryProvider).getBalance(c.id!),
          builder: (ctx, snap) {
            final balance = snap.data ?? 0.0;
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: balanceColor(balance),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                title: Text(c.nameGujarati),
                subtitle: Text(c.phone ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatCurrency(balance),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: balanceColor(balance),
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'khata') {
                          onCustomerTap(c);
                        } else if (v == 'edit') {
                          Navigator.of(
                            context,
                          ).pushNamed(AppRouter.customerEdit, arguments: c.id);
                        } else if (v == 'delete') {
                          onDelete(context, c);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'khata',
                          child: Row(
                            children: [
                              Icon(Icons.assignment),
                              SizedBox(width: 8),
                              Text('ખાતા જુઓ'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text('બદલો'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('કાઢી નાખો'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                onTap: () => onCustomerTap(c),
              ),
            );
          },
        );
      },
    );
  }
}
