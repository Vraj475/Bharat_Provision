import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_strings.dart';
import '../../data/models/category.dart';
import '../../data/providers.dart';
import 'inventory_providers.dart';

class CategoryListScreen extends ConsumerWidget {
  const CategoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoryListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.categoriesTitle)),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('કોઈ કેટેગરી નથી'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _showAddCategory(context, ref),
                    child: const Text(AppStrings.addCategory),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (ctx, i) {
              final c = categories[i];
              return ListTile(
                title: Text(c.nameGu),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showEditCategory(context, ref, c),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${AppStrings.errorGeneric} $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategory(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddCategory(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.addCategory),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: AppStrings.categoryName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancelButton),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(AppStrings.saveButton),
          ),
        ],
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;

    try {
      final repo = await ref.read(itemRepositoryFutureProvider.future);
      await repo.insertCategory(Category(nameGu: nameCtrl.text.trim()));
      ref.invalidate(categoryListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('કેટેગરી ઉમેરાયું')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.errorGeneric} $e')),
        );
      }
    }
  }

  void _showEditCategory(
    BuildContext context,
    WidgetRef ref,
    Category c,
  ) async {
    final nameCtrl = TextEditingController(text: c.nameGu);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.categoryName),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: AppStrings.categoryName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancelButton),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(AppStrings.saveButton),
          ),
        ],
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;

    try {
      final repo = await ref.read(itemRepositoryFutureProvider.future);
      await repo.updateCategory(c.copyWith(nameGu: nameCtrl.text.trim()));
      ref.invalidate(categoryListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('કેટેગરી ઉપડેટ થયું')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.errorGeneric} $e')),
        );
      }
    }
  }
}
