import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/models/models.dart';
import 'inventory_providers.dart';

/// Shows an enhanced, beautiful dialog for adding or editing a category.
Future<Category?> showCategoryDialog(
  BuildContext context,
  WidgetRef ref, {
  Category? categoryToEdit,
}) async {
  final nameGuCtrl = TextEditingController(text: categoryToEdit?.nameGu ?? '');
  final nameEnCtrl = TextEditingController(text: categoryToEdit?.nameEnglish ?? '');
  final formKey = GlobalKey<FormState>();
  final isEditing = categoryToEdit != null;

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Icon(
              Icons.category_rounded,
              color: Color(0xFF2563EB),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isEditing ? 'કેટેગરી સુધારો' : 'નવી કેટેગરી ઉમેરો',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
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
              const SizedBox(height: 6),
              TextFormField(
                controller: nameGuCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'કેટેગરીનું નામ (ગુજરાતી) *',
                  hintText: 'દા.ત. અનાજ, તેલ, મસાલા',
                  prefixIcon: const Icon(Icons.edit_note, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'કૃપા કરીને કેટેગરીનું નામ દાખલ કરો';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: nameEnCtrl,
                decoration: InputDecoration(
                  labelText: 'અંગ્રેજી નામ (વૈકલ્પિક)',
                  hintText: 'e.g. Grains, Oil, Spices',
                  prefixIcon: const Icon(Icons.language, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => ctx.pop(false),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: const Text('રદ કરો'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              ctx.pop(true);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          icon: const Icon(Icons.check, size: 18),
          label: Text(
            isEditing ? 'અપડેટ કરો' : 'સાચવો',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  if (saved != true) return null;

  final guName = nameGuCtrl.text.trim();
  final enName = nameEnCtrl.text.trim().isEmpty ? null : nameEnCtrl.text.trim();

  try {
    final repo = ref.read(itemRepositoryProvider);
    Category resultCategory;

    if (isEditing) {
      resultCategory = categoryToEdit.copyWith(
        nameGujarati: guName,
        nameEnglish: enName,
      );
      await repo.updateCategory(resultCategory);
    } else {
      final newCat = Category(
        nameGujarati: guName,
        nameEnglish: enName,
        createdAt: DateTime.now().toIso8601String(),
      );
      final newId = await repo.insertCategory(newCat);
      resultCategory = newCat.copyWith(id: newId);
    }

    ref.invalidate(categoryListProvider);
    ref.invalidate(cachedProductsProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'કેટેગરી "$guName" અપડેટ કરવામાં આવી'
                : 'નવી કેટેગરી "$guName" ઉમેરાઈ ગઈ',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    return resultCategory;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ભૂલ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return null;
  }
}
