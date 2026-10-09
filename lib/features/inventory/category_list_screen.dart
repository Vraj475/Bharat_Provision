import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_strings.dart';
import '../../core/utils/currency_format.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../data/providers.dart';
import '../../domain/models/models.dart';
import '../../routing/app_router.dart';
import '../../core/utils/product_visual_helper.dart';
import 'category_dialogs.dart';
import 'inventory_providers.dart';

class CategoryListScreen extends ConsumerWidget {
  const CategoryListScreen({super.key});

  Widget _buildProductIcon(Product item) {
    return buildRealisticProductBadge(item, size: 40, showStockIndicator: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesWithProductsAsync = ref.watch(categoriesWithProductsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('કેટેગરી અને પ્રોડક્ટ્સ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: AppStrings.addCategory,
            onPressed: () => showCategoryDialog(context, ref),
          ),
        ],
      ),
      body: categoriesWithProductsAsync.when(
        data: (categoriesWithProducts) {
          if (categoriesWithProducts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Icon(
                        Icons.category_outlined,
                        size: 48,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'કોઈ કેટેગરી નથી',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'પ્રોડક્ટ્સને સરળતાથી વર્ગીકૃત કરવા માટે કેટેગરી ઉમેરો',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => showCategoryDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text(AppStrings.addCategory),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            itemCount: categoriesWithProducts.length,
            itemBuilder: (ctx, i) {
              final item = categoriesWithProducts[i];
              final category = item.category;
              final products = item.products;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                ),
                clipBehavior: Clip.antiAlias,
                child: Theme(
                  data: Theme.of(ctx).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Center(
                        child: Text(
                          category.nameGu.isNotEmpty ? category.nameGu.characters.first : 'ક',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      category.nameGu,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        if (category.nameEnglish != null && category.nameEnglish!.isNotEmpty) ...[
                          Text(
                            category.nameEnglish!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('•', style: TextStyle(color: Color(0xFF94A3B8))),
                          const SizedBox(width: 6),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: products.isEmpty ? const Color(0xFFF1F5F9) : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${products.length} પ્રોડક્ટ્સ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: products.isEmpty ? const Color(0xFF64748B) : const Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF3B82F6)),
                          tooltip: 'કેટેગરી સુધારો',
                          onPressed: () => showCategoryDialog(context, ref, categoryToEdit: category),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFEF4444)),
                          tooltip: 'કેટેગરી કાઢી નાખો',
                          onPressed: () => _confirmDeleteCategory(context, ref, category, products.length),
                        ),
                      ],
                    ),
                    children: [
                      const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                      if (products.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 18, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'આ કેટેગરીમાં હજુ કોઈ પ્રોડક્ટ ઉમેરાઈ નથી.',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                ),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('પ્રોડક્ટ ઉમેરો'),
                                onPressed: () => context.push(AppRouter.itemAdd),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: products.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFFF8FAFC),
                          ),
                          itemBuilder: (ctx, pIdx) {
                            final p = products[pIdx];
                            final isLowStock = p.isLowStock || p.stockQty <= 0;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: _buildProductIcon(p),
                              title: Text(
                                p.nameGujarati,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              subtitle: Row(
                                children: [
                                  Text(
                                    formatCurrency(p.sellPrice),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '• સ્ટોક: ${formatQuantity(p.stockQty)} ${p.unitType}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isLowStock ? Colors.red : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isLowStock)
                                    Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        p.stockQty <= 0 ? 'સ્ટોક ખૂટ્યો' : 'ઓછો સ્ટોક',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFDC2626),
                                        ),
                                      ),
                                    ),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 13,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ],
                              ),
                              onTap: () {
                                if (p.id != null) {
                                  context.push(AppRouter.itemEdit, extra: p.id!);
                                }
                              },
                            );
                          },
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          color: const Color(0xFFF8FAFC),
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('આ કેટેગરીમાં પ્રોડક્ટ ઉમેરો'),
                            onPressed: () => context.push(AppRouter.itemAdd),
                          ),
                        ),
                      ],
                    ],
                  ),
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
              SizedBox(height: 12),
              Text('કેટેગરી લોડ થઈ રહી છે...'),
            ],
          ),
        ),
        error: (e, _) => Center(child: Text('${AppStrings.errorGeneric}: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCategoryDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('નવી કેટેગરી'),
      ),
    );
  }

  void _confirmDeleteCategory(
    BuildContext context,
    WidgetRef ref,
    Category category,
    int productCount,
  ) async {
    final message = productCount > 0
        ? 'આ કેટેગરીમાં $productCount પ્રોડક્ટ્સ છે. શું તમે ખરેખર "${category.nameGu}" કેટેગરી કાઢી નાખવા માંગો છો?'
        : 'શું તમે "${category.nameGu}" કેટેગરી કાઢી નાખવા માંગો છો?';

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'કેટેગરી કાઢી નાખો',
      message: message,
    );

    if (confirmed != true || category.id == null) return;

    try {
      final repo = ref.read(itemRepositoryProvider);
      await repo.deleteCategory(category.id!);
      ref.invalidate(categoryListProvider);
      ref.invalidate(cachedProductsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('કેટેગરી "${category.nameGu}" કાઢી નાખી')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ભૂલ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
