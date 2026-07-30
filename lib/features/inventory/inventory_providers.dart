import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/category.dart';
import '../../shared/models/product_model.dart';
import '../../data/providers.dart';

final itemListSearchProvider = StateProvider<String>((ref) => '');
final itemListLowStockOnlyProvider = StateProvider<bool>((ref) => false);

final itemListProvider = FutureProvider<List<Product>>((ref) async {
  final repo = await ref.watch(itemRepositoryFutureProvider.future);
  final query = ref.watch(itemListSearchProvider);
  final lowStockOnly = ref.watch(itemListLowStockOnlyProvider);
  return repo.search(query, lowStockOnly: lowStockOnly);
});

final categoryListProvider = FutureProvider<List<Category>>((ref) async {
  final repo = await ref.watch(itemRepositoryFutureProvider.future);
  return repo.getCategories();
});
