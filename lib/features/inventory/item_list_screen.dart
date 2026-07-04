import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_format.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../data/models/item.dart';
import '../../data/providers.dart';
import '../../routing/app_router.dart';
import 'inventory_providers.dart';

class ItemListScreen extends ConsumerStatefulWidget {
  const ItemListScreen({super.key});

  @override
  ConsumerState<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends ConsumerState<ItemListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      ref.read(itemListSearchProvider.notifier).state = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _stockColor(Item item) {
    if (item.isLowStock) return AppColors.alert;
    if (item.currentStock <= item.lowStockThreshold * 1.2) {
      return AppColors.warning;
    }
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemListProvider);
    final lowStockOnly = ref.watch(itemListLowStockOnlyProvider);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: AppStrings.searchHintItems,
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.category),
                  label: const Text('કેટેગરીઓ'),
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRouter.categories),
                ),
                FilterChip(
                  label: const Text(AppStrings.lowStockFilter),
                  selected: lowStockOnly,
                  onSelected: (v) {
                    ref.read(itemListLowStockOnlyProvider.notifier).state = v;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: itemsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Center(child: Text(AppStrings.noItemsFound));
                }
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _stockColor(item),
                          child: const Icon(
                            Icons.inventory_2,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(item.nameGu),
                        subtitle: Text(
                          '${formatCurrency(item.salePrice)} • ${item.currentStock} ${item.unit}',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') {
                              Navigator.of(context).pushNamed(
                                AppRouter.itemEdit,
                                arguments: item.id,
                              );
                            } else if (v == 'delete') {
                              _confirmDelete(item);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit),
                                  SizedBox(width: 8),
                                  Text(AppStrings.editItem),
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
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(AppRouter.itemEdit, arguments: item.id),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('${AppStrings.errorGeneric} $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pushNamed(AppRouter.itemAdd),
        icon: const Icon(Icons.add),
        label: const Text(AppStrings.addItem),
      ),
    );
  }

  Future<void> _confirmDelete(Item item) async {
    final ok = await ConfirmDialog.show(
      context,
      title: AppStrings.deleteItemTitle,
      message: AppStrings.deleteItemMessage,
    );
    if (ok != true || !mounted) return;

    String message;
    try {
      final repo = await ref.read(itemRepositoryFutureProvider.future);
      await repo.delete(item.id!);
      ref.invalidate(itemListProvider);
      message = 'ઉત્પાદ સફળતાપૂર્વક કાઢી નાખ્યું';
    } catch (e) {
      message = '${AppStrings.errorGeneric} $e';
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
