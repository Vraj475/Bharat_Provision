import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/category.dart';
import '../../shared/models/product_model.dart';
import '../../data/providers.dart';

final itemListSearchProvider = StateProvider<String>((ref) => '');
final itemListLowStockOnlyProvider = StateProvider<bool>((ref) => false);

// Fetches all active products into memory once (or when invalidated)
final cachedProductsProvider = FutureProvider<List<Product>>((ref) async {
  final repo = ref.watch(itemRepositoryProvider);
  return repo.getAll(activeOnly: true);
});

final itemListProvider = FutureProvider<List<Product>>((ref) async {
  final query = ref.watch(itemListSearchProvider).trim().toLowerCase();
  final lowStockOnly = ref.watch(itemListLowStockOnlyProvider);
  
  // Wait for the full catalog to load into memory
  final allProducts = await ref.watch(cachedProductsProvider.future);
  
  // Perform fast in-memory search
  return allProducts.where((p) {
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
