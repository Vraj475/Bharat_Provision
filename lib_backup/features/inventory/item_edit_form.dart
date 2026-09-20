import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_strings.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/models/category.dart';

class ItemEditForm extends StatelessWidget {
  const ItemEditForm({
    super.key,
    required this.nameController,
    required this.salePriceController,
    required this.purchasePriceController,
    required this.stockController,
    required this.lowStockController,
    required this.barcodeController,
    required this.categoryId,
    required this.unit,
    required this.isActive,
    required this.categoriesAsync,
    required this.onCategoryChanged,
    required this.onUnitChanged,
    required this.onActiveChanged,
    required this.onSave,
  });

  final TextEditingController nameController;
  final TextEditingController salePriceController;
  final TextEditingController purchasePriceController;
  final TextEditingController stockController;
  final TextEditingController lowStockController;
  final TextEditingController barcodeController;
  final int? categoryId;
  final String unit;
  final bool isActive;
  final AsyncValue<List<Category>> categoriesAsync;
  final ValueChanged<int?> onCategoryChanged;
  final ValueChanged<String> onUnitChanged;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onSave;

  static const List<String> _units = ['નંગ', 'કિલો', 'ગ્રામ', 'લીટર'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: AppStrings.itemName),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: barcodeController,
            decoration: const InputDecoration(labelText: AppStrings.barcode),
          ),
          const SizedBox(height: 16),
          _buildCategoryDropdown(),
          const SizedBox(height: 16),
          _buildUnitDropdown(),
          const SizedBox(height: 16),
          TextField(
            controller: salePriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: AppStrings.sellPrice,
              prefixText: '₹ ',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: purchasePriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: AppStrings.buyPrice,
              prefixText: '₹ ',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: stockController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: AppStrings.currentStock,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: lowStockController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: AppStrings.lowStockThreshold,
            ),
          ),
          SwitchListTile(
            title: const Text(AppStrings.activeToggle),
            value: isActive,
            onChanged: onActiveChanged,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: AppStrings.saveButton,
            icon: Icons.save,
            onPressed: onSave,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<int?>(
      initialValue: categoryId,
      decoration: const InputDecoration(labelText: AppStrings.category),
      items: [
        const DropdownMenuItem(value: null, child: Text('—')),
        ...categoriesAsync.when(
          data: (categories) => categories
              .map(
                (category) => DropdownMenuItem<int?>(
                  value: category.id,
                  child: Text(category.nameGu),
                ),
              )
              .toList(),
          loading: () => [],
          error: (error, stack) => [],
        ),
      ],
      onChanged: onCategoryChanged,
    );
  }

  Widget _buildUnitDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: unit,
      decoration: const InputDecoration(labelText: AppStrings.unit),
      items: _units
          .map((value) => DropdownMenuItem(value: value, child: Text(value)))
          .toList(),
      onChanged: (value) {
        if (value != null) onUnitChanged(value);
      },
    );
  }
}