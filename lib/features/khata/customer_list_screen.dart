import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_format.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../shared/models/customer_model.dart';
import '../../data/providers.dart';
import '../../routing/app_router.dart';
import '../../core/utils/debouncer.dart';
import '../../core/widgets/hover_effects.dart';
import '../../core/widgets/dialogs_and_snackbars.dart';
import 'khata_providers.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final _searchController = TextEditingController();
  final _debouncer = Debouncer(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
      _debouncer.run(() {
        ref.read(customerSearchProvider.notifier).state = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Color _balanceColor(double balance) {
    if (balance > 0) return AppColors.alert;
    if (balance < 0) return AppColors.success;
    return const Color(0xFF64748B);
  }

  void _refreshAll() {
    ref.invalidate(customersProvider);
    ref.invalidate(customerListProvider);
    ref.invalidate(bulkCustomerBalancesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerListProvider);
    final balancesAsync = ref.watch(bulkCustomerBalancesProvider);
    final balances = balancesAsync.valueOrNull ?? const <int, double>{};

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRouter.customerAdd),
        icon: const Icon(Icons.person_add),
        label: const Text(AppStrings.addCustomer),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ખાતાવહી અને ગ્રાહકો',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'તમામ ગ્રાહકોનું ખાતું અને બાકી ઉધાર હિસાબ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF475569)),
                    tooltip: 'રિફ્રેશ કરો',
                    onPressed: _refreshAll,
                  ),
                ],
              ),
            ),

            // Summary metrics banner if customers are available
            customersAsync.maybeWhen(
              data: (customers) {
                final totalOutstanding = customers.fold<double>(0.0, (sum, c) {
                  final b = balances[c.id] ?? c.totalOutstanding;
                  return sum + (b > 0 ? b : 0.0);
                });

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'કુલ ગ્રાહકો',
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${customers.length}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: totalOutstanding > 0 ? const Color(0xFFFEF2F2) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: totalOutstanding > 0 ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'કુલ બાકી',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: totalOutstanding > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatCurrency(totalOutstanding),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: totalOutstanding > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: '${AppStrings.customerName} અથવા ${AppStrings.phone} શોધો',
                  hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(customerSearchProvider.notifier).state = '';
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
              ),
            ),

            // Customers list
            Expanded(
              child: customersAsync.when(
                data: (customers) {
                  if (customers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people_outline, size: 54, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 12),
                          Text(
                            AppStrings.noCustomersFound,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => context.push(AppRouter.customerAdd),
                            icon: const Icon(Icons.person_add),
                            label: const Text('નવો ગ્રાહક ઉમેરો'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    itemCount: customers.length,
                    itemBuilder: (ctx, i) {
                      final c = customers[i];
                      final balance = balances[c.id] ?? c.totalOutstanding;
                      final isDue = balance > 0;

                      return HoverableCard(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: isDue ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF),
                            child: Text(
                              c.nameGujarati.isNotEmpty ? c.nameGujarati.characters.first : 'ગ્રા',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDue ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.nameGujarati,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              if (isDue)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'બાકી',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                Icon(Icons.phone, size: 13, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  c.phone != null && c.phone!.isNotEmpty ? c.phone! : 'ફોન નંબર નથી',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                                if (c.address != null && c.address!.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  const Text('•', style: TextStyle(color: Color(0xFF94A3B8))),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      c.address!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    formatCurrency(balance),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: _balanceColor(balance),
                                    ),
                                  ),
                                  Text(
                                    isDue ? 'બાકી' : 'ચુકતે',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _balanceColor(balance),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 6),
                              PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'khata') {
                                    context.push(AppRouter.customerKhata, extra: c.id);
                                  } else if (v == 'edit') {
                                    context.push(AppRouter.customerEdit, extra: c.id);
                                  } else if (v == 'delete') {
                                    _confirmDelete(c);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'khata',
                                    child: Row(
                                      children: [
                                        Icon(Icons.assignment, size: 18, color: Color(0xFF2563EB)),
                                        SizedBox(width: 8),
                                        Text('ખાતા જુઓ'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 18),
                                        SizedBox(width: 8),
                                        Text('ગ્રાહક સુધારો'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('કાઢી નાખો', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () => context.push(AppRouter.customerKhata, extra: c.id),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 10),
                      Text('ગ્રાહકો લોડ થઈ રહ્યા છે...'),
                    ],
                  ),
                ),
                error: (e, _) => Center(child: Text('${AppStrings.errorGeneric} $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Customer customer) async {
    final ok = await ConfirmDialog.show(
      context,
      title: AppStrings.deleteCustomerTitle,
      message: 'શું તમે "${customer.nameGujarati}" ગ્રાહકને કાઢી નાખવા માંગો છો?',
    );
    if (ok != true || !mounted) return;

    String message;
    bool isError = false;
    try {
      final repo = ref.read(customerRepositoryProvider);
      await repo.delete(customer.id!);
      ref.invalidate(customersProvider);
      ref.invalidate(customerListProvider);
      ref.invalidate(bulkCustomerBalancesProvider);
      message = 'ગ્રાહક સફળતાપૂર્વક કાઢી નાખવામાં આવ્યું';
    } catch (e) {
      isError = true;
      message = '${AppStrings.errorGeneric} $e';
    }
    if (!mounted) return;
    if (isError) {
      EnhancedSnackbar.showError(context, message);
    } else {
      EnhancedSnackbar.showSuccess(context, message);
    }
  }
}
