import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_strings.dart';
import '../../core/utils/currency_format.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/utils/debouncer.dart';
import '../../shared/models/product_model.dart';
import '../../data/providers.dart';
import '../../routing/app_router.dart';
import '../../core/widgets/hover_effects.dart';
import 'inventory_providers.dart';
import '../billing/billing_providers.dart';
import '../../core/utils/product_visual_helper.dart';

class ItemListScreen extends ConsumerStatefulWidget {
  const ItemListScreen({super.key});

  @override
  ConsumerState<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends ConsumerState<ItemListScreen> {
  final _searchController = TextEditingController();
  final _debouncer = Debouncer(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _debouncer.run(() {
        ref.read(itemListSearchProvider.notifier).state = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildProductIcon(Product item) {
    return buildRealisticProductBadge(item, size: 44, showStockIndicator: true);
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemListProvider);
    final lowStockOnly = ref.watch(itemListLowStockOnlyProvider);
    final selectedCategory = ref.watch(itemListCategoryFilterProvider);
    final categoriesAsync = ref.watch(categoryListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRouter.itemAdd),
        icon: const Icon(Icons.add),
        label: const Text('નવું ઉત્પાદન'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header section to give proper breathing room from the top
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ઇન્વેન્ટરી અને માલસામાન',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'તમામ પ્રોડક્ટ્સ અને સ્ટોક વ્યવસ્થાપન',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.category_outlined, size: 18),
                    label: const Text('કેટેગરીઓ'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => context.push(AppRouter.categories),
                  ),
                ],
              ),
            ),

            // Search product field comfortably moved down from top
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: AppStrings.searchHintItems,
                  hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(itemListSearchProvider.notifier).state = '';
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

            // Category filter chips and low stock filter
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // All Products Chip
                  FilterChip(
                    label: const Text('બધા'),
                    selected: selectedCategory == null && !lowStockOnly,
                    onSelected: (_) {
                      ref.read(itemListCategoryFilterProvider.notifier).state = null;
                      ref.read(itemListLowStockOnlyProvider.notifier).state = false;
                    },
                    selectedColor: const Color(0xFFDBEAFE),
                    checkmarkColor: const Color(0xFF1D4ED8),
                  ),
                  const SizedBox(width: 8),

                  // Low Stock Filter Chip
                  FilterChip(
                    label: const Text(AppStrings.lowStockFilter),
                    selected: lowStockOnly,
                    onSelected: (v) {
                      ref.read(itemListLowStockOnlyProvider.notifier).state = v;
                    },
                    selectedColor: const Color(0xFFFEE2E2),
                    checkmarkColor: const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 8),

                  // Dynamic Category Filter Chips
                  ...categoriesAsync.maybeWhen(
                    data: (categories) => categories.map((cat) {
                      final isSelected = selectedCategory == cat.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(cat.nameGu),
                          selected: isSelected,
                          onSelected: (selected) {
                            ref.read(itemListCategoryFilterProvider.notifier).state =
                                selected ? cat.id : null;
                          },
                          selectedColor: const Color(0xFFEFF6FF),
                          checkmarkColor: const Color(0xFF2563EB),
                        ),
                      );
                    }),
                    orElse: () => [],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Products list
            Expanded(
              child: itemsAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.shopping_bag_outlined,
                            size: 52,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            AppStrings.noItemsFound,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => context.push(AppRouter.itemAdd),
                            icon: const Icon(Icons.add),
                            label: const Text('નવું ઉત્પાદન ઉમેરો'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    itemCount: items.length,
                    itemBuilder: (ctx, i) {
                      final item = items[i];
                      final isLow = item.isLowStock || item.stockQty <= 0;

                      return HoverableCard(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: _buildProductIcon(item),
                          title: Text(
                            item.nameGujarati,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(
                              children: [
                                Text(
                                  formatCurrency(item.sellPrice),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '• સ્ટોક: ${formatQuantity(item.stockQty)} ${item.unitType}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isLow ? const Color(0xFFDC2626) : const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isLow)
                                Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.stockQty <= 0 ? 'સ્ટોક નથી' : 'ઓછો સ્ટોક',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                              PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'edit') {
                                    context.push(
                                      AppRouter.itemEdit,
                                      extra: item.id,
                                    );
                                  } else if (v == 'stock') {
                                    _showStockUpdateDialog(context, item);
                                  } else if (v == 'delete') {
                                    _confirmDelete(item);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
                                        SizedBox(width: 8),
                                        Text(AppStrings.editItem),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'stock',
                                    child: Row(
                                      children: [
                                        Icon(Icons.add_box_outlined, size: 18, color: Color(0xFF16A34A)),
                                        SizedBox(width: 8),
                                        Text('સ્ટોક ઉમેરો'),
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
                          onTap: () => _showStockUpdateDialog(context, item),
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
                      Text('માલસામાન લોડ થઈ રહ્યો છે...'),
                    ],
                  ),
                ),
                error: (e, _) => Center(child: Text('${AppStrings.errorGeneric}: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Product item) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'ઉત્પાદન કાઢી નાખો',
      message: 'શું તમે ખરેખર "${item.nameGujarati}" કાઢી નાખવા માંગો છો?',
    );

    if (confirmed == true && item.id != null) {
      final repo = ref.read(itemRepositoryProvider);
      await repo.delete(item.id!);
      ref.invalidate(cachedProductsProvider);
      ref.invalidate(itemListProvider);
      ref.invalidate(categoryListProvider);
      ref.invalidate(categoriesWithProductsProvider);
      ref.invalidate(billingItemsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ઉત્પાદન સફળતાપૂર્વક કાઢી નાખવામાં આવ્યું')),
        );
      }
    }
  }

  Future<void> _showStockUpdateDialog(BuildContext context, Product item) async {
    final qtyController = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    double addQty = 0.0;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final unit = item.unitType.toLowerCase();
            final isGram = unit.contains('ગ્રામ') || unit == 'g' || unit == 'gm';

            final quickChips = isGram
                ? [100.0, 250.0, 500.0, 1000.0, 2000.0, 5000.0]
                : [1.0, 2.0, 5.0, 10.0, 25.0, 50.0];

            final currentStock = item.stockQty;
            final newTotalStock = currentStock + addQty;
            final isLow = item.isLowStock || item.stockQty <= 0;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Row(
                children: [
                  buildRealisticProductBadge(item, size: 48, showStockIndicator: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.nameGujarati,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ભાવ: ${formatCurrency(item.sellPrice)} / ${item.unitType}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Current stock highlight card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'હાલનો સ્ટોક (Current Stock)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${formatQuantity(item.stockQty)} ${item.unitType}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: isLow ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isLow ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item.stockQty <= 0
                                    ? 'સ્ટોક નથી'
                                    : (item.isLowStock ? 'ઓછો સ્ટોક' : 'પૂરતો સ્ટોક'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isLow ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Input for how much stock to add
                      const Text(
                        'ઉમેરવાનો સ્ટોક (Stock to Add):',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: qtyController,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'દા.ત. 10',
                          suffixText: item.unitType,
                          suffixStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                          prefixIcon: const Icon(Icons.add_circle, color: Color(0xFF2563EB)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (val) {
                          setDialogState(() {
                            addQty = double.tryParse(val.trim()) ?? 0.0;
                          });
                        },
                        validator: (val) {
                          final parsed = double.tryParse(val?.trim() ?? '');
                          if (parsed == null || parsed <= 0) {
                            return 'કૃપા કરીને માન્ય જથ્થો દાખલ કરો (> 0)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),

                      // Quick addition chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: quickChips.map((chipQty) {
                          final label = '+${chipQty % 1 == 0 ? chipQty.toInt() : chipQty}';
                          return ActionChip(
                            label: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                            backgroundColor: const Color(0xFFEFF6FF),
                            side: const BorderSide(color: Color(0xFFBFDBFE)),
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              setDialogState(() {
                                final currentInput = double.tryParse(qtyController.text.trim()) ?? 0.0;
                                final updated = currentInput + chipQty;
                                qtyController.text = updated % 1 == 0 ? updated.toInt().toString() : updated.toString();
                                addQty = updated;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Live preview of new stock
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: addQty > 0 ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: addQty > 0 ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              addQty > 0 ? Icons.trending_up : Icons.info_outline,
                              size: 22,
                              color: addQty > 0 ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    addQty > 0
                                        ? 'નવો કુલ સ્ટોક થશે:'
                                        : 'સ્ટોક ઉમેર્યા પછીની ગણતરી:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: addQty > 0 ? const Color(0xFF15803D) : const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    addQty > 0
                                        ? '${formatQuantity(currentStock)} + ${formatQuantity(addQty)} = ${formatQuantity(newTotalStock)} ${item.unitType}'
                                        : '${formatQuantity(currentStock)} ${item.unitType}',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: addQty > 0 ? const Color(0xFF15803D) : const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Optional Note
                      TextFormField(
                        controller: noteController,
                        decoration: InputDecoration(
                          labelText: 'નોંધ (વૈકલ્પિક)',
                          hintText: 'નવી ખરીદી / જથ્થો આવ્યો',
                          prefixIcon: const Icon(Icons.note_alt_outlined, size: 20),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('રદ કરો'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('સ્ટોક ઉમેરો'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    if (formKey.currentState?.validate() != true) return;
                    final qtyToAdd = double.tryParse(qtyController.text.trim());
                    if (qtyToAdd == null || qtyToAdd <= 0 || item.id == null) return;

                    final repo = ref.read(itemRepositoryProvider);
                    await repo.increaseStock(
                      item.id!,
                      qtyToAdd,
                      note: noteController.text.trim().isNotEmpty
                          ? noteController.text.trim()
                          : 'હસ્તચાલિત સ્ટોક ઉમેરો ($qtyToAdd ${item.unitType})',
                    );

                    ref.invalidate(cachedProductsProvider);
                    ref.invalidate(itemListProvider);
                    ref.invalidate(categoryListProvider);
                    ref.invalidate(categoriesWithProductsProvider);
                    ref.invalidate(billingItemsProvider);

                    if (dialogCtx.mounted) {
                      Navigator.of(dialogCtx).pop();
                    }

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${item.nameGujarati} માં $qtyToAdd ${item.unitType} સ્ટોક સફળતાપૂર્વક ઉમેરાયો! નવો સ્ટોક: ${formatQuantity(item.stockQty + qtyToAdd)} ${item.unitType}',
                          ),
                          backgroundColor: const Color(0xFF16A34A),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
