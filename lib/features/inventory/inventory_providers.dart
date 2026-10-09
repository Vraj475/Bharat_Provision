import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/models.dart';
import '../../data/providers.dart';

final itemListSearchProvider = StateProvider<String>((ref) => '');
final itemListLowStockOnlyProvider = StateProvider<bool>((ref) => false);
final itemListCategoryFilterProvider = StateProvider<int?>((ref) => null);

// Fetches all active products into memory once (or when invalidated)
final cachedProductsProvider = FutureProvider<List<Product>>((ref) async {
  final repo = ref.watch(itemRepositoryProvider);
  return repo.getAll(activeOnly: true);
});

final itemListProvider = FutureProvider<List<Product>>((ref) async {
  final query = ref.watch(itemListSearchProvider).trim().toLowerCase();
  final lowStockOnly = ref.watch(itemListLowStockOnlyProvider);
  final categoryFilter = ref.watch(itemListCategoryFilterProvider);
  
  // Wait for the full catalog to load into memory
  final allProducts = await ref.watch(cachedProductsProvider.future);
  
  // Perform fast in-memory search and filter
  return allProducts.where((p) {
    if (categoryFilter != null && p.categoryId != categoryFilter) return false;
    if (lowStockOnly && p.stockQty > p.minStockQty) return false;
    if (query.isEmpty) return true;
    
    final nameGujarati = p.nameGujarati.toLowerCase();
    final nameEnglish = (p.nameEnglish ?? '').toLowerCase();
    final barcode = (p.barcode ?? '').toLowerCase();
    
    return nameGujarati.contains(query) || 
           nameEnglish.contains(query) || 
           barcode.contains(query);
  }).toList();
});

final categoryListProvider = FutureProvider<List<Category>>((ref) async {
  final repo = ref.watch(itemRepositoryProvider);
  return repo.getCategories();
});

class CategoryWithProducts {
  final Category category;
  final List<Product> products;

  const CategoryWithProducts({
    required this.category,
    required this.products,
  });
}

final categoriesWithProductsProvider = FutureProvider<List<CategoryWithProducts>>((ref) async {
  final categories = await ref.watch(categoryListProvider.future);
  final allProducts = await ref.watch(cachedProductsProvider.future);

  return categories.map((cat) {
    final prods = allProducts.where((p) => p.categoryId == cat.id).toList();
    return CategoryWithProducts(category: cat, products: prods);
  }).toList();
});
