import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_strings.dart' as strings;
import '../../../core/errors/error_handler.dart';
import '../../../core/errors/error_types.dart';
import '../../../routing/app_router.dart';
import '../../../shared/models/product_model.dart';
import '../../../shared/providers/product_provider.dart';
import '../../../shared/widgets/errors/error_dialogue.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (query.trim().isNotEmpty) {
      ref.read(productProvider.notifier).searchProducts(query);
    } else {
      ref.read(productProvider.notifier).loadAllProducts();
    }
  }

  Color _stockColor(Product p) {
    if (p.stockQty < p.minStockQty) {
      return const Color(0xFFE53935); // critical
    }
    final threshold = p.minStockQty * 1.2;
    if (p.stockQty <= threshold) {
      return const Color(0xFFFB8C00); // warning
    }
    return const Color(0xFF43A047); // healthy
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.productsTitle)),
      backgroundColor: const Color(0xFFF1F4F1),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: AppStrings.searchHintProducts,
                hintStyle: const TextStyle(fontSize: 14),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              AppStrings.productShortcutHint,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: state.when(
              data: (products) {
                if (products.isEmpty) {
                  return const Center(
                    child: Text(
                      AppStrings.noProductsFound,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final p = products[index];
                    final color = _stockColor(p);
                    return Card(
                      elevation: 1.5,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: color,
                          child: const Icon(
                            Icons.inventory_2,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          p.nameGujarati,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '₹${p.sellPrice.toStringAsFixed(2)} • ${p.stockQty.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                        onLongPress: () => _showLongPressMenu(context, p),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) {
                final appErr = e is AppError
                    ? e
                    : ErrorHandler.handle(e, st, context: 'ProductListScreen');

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ErrorDialogue.showSnackbar(
                    context,
                    message: appErr.userMessage,
                    code: appErr.code,
                    type: ErrorDialogueType.error,
                  );
                });

                return Center(
                  child: Text(
                    appErr.userMessage,
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 56),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: FloatingActionButton.extended(
          onPressed: () => context.push(AppRouter.productAdd),
          icon: const Icon(Icons.add),
          label: const Text(
            strings.AppStrings.addProductFab,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  void _showLongPressMenu(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text(AppStrings.productActionEdit),
                onTap: () {
                  context.pop();
                  context.push(AppRouter.productEdit, extra: product.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(AppStrings.productActionDelete),
                onTap: () {
                  context.pop();
                  _confirmDelete(context, product);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(AppStrings.deleteProductTitle),
          content: const Text(AppStrings.deleteProductMessage),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: const Text(AppStrings.deleteCancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                context.pop();
                await ref.read(productProvider.notifier).deleteProduct(product);
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(AppStrings.successProductDeleted),
                    ),
                  );
                }
              },
              child: const Text(AppStrings.deleteConfirm),
            ),
          ],
        );
      },
    );
  }
}
