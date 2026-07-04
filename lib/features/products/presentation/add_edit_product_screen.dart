import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../shared/models/product_model.dart';
import '../../../shared/providers/product_provider.dart';

class AddEditProductScreen extends ConsumerStatefulWidget {
  final int? productId;

  const AddEditProductScreen({super.key, this.productId});

  @override
  ConsumerState<AddEditProductScreen> createState() =>
      _AddEditProductScreenState();
}

class _AddEditProductScreenState extends ConsumerState<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameGuController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _translitController = TextEditingController();
  final _buyPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController();

  String _unitType = AppStrings.unitKilo;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    // In a full implementation, we would load existing product by ID here.
  }

  @override
  void dispose() {
    _nameGuController.dispose();
    _nameEnController.dispose();
    _translitController.dispose();
    _buyPriceController.dispose();
    _sellPriceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.productId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? AppStrings.editProductTitle : AppStrings.addProductTitle,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameGuController,
                        decoration: const InputDecoration(
                          labelText: AppStrings.productNameGujarati,
                          helperText: AppStrings.productTransliterationHint,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return AppStrings.fieldRequired;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _translitController,
                        decoration: const InputDecoration(
                          labelText: AppStrings.transliterationKeys,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameEnController,
                        decoration: const InputDecoration(
                          labelText: AppStrings.productNameEnglish,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.unitType,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildUnitChip(AppStrings.unitKilo),
                          _buildUnitChip(AppStrings.unitGram),
                          _buildUnitChip(AppStrings.unitPiece),
                          _buildUnitChip(AppStrings.unitLitre),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _buyPriceController,
                        decoration: const InputDecoration(
                          labelText: AppStrings.buyPrice,
                          prefixText: '₹ ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _sellPriceController,
                        decoration: const InputDecoration(
                          labelText: AppStrings.sellPrice,
                          prefixText: '₹ ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _stockController,
                        decoration: const InputDecoration(
                          labelText: AppStrings.currentStock,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _minStockController,
                        decoration: const InputDecoration(
                          labelText: AppStrings.minStockAlertLevel,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: _isActive,
                        title: const Text(AppStrings.activeToggle),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) {
                          setState(() {
                            _isActive = v;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      child: const Text(AppStrings.saveButton),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(AppStrings.cancelButton),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnitChip(String label) {
    final selected = _unitType == label;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _unitType = label;
        });
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final buyPrice = double.tryParse(_buyPriceController.text) ?? 0;
    final sellPrice = double.tryParse(_sellPriceController.text) ?? 0;
    final stock = double.tryParse(_stockController.text) ?? 0;
    final minStock = double.tryParse(_minStockController.text) ?? 0;

    if (sellPrice > 0 && buyPrice > 0 && sellPrice < buyPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.sellPriceLessThanBuyWarning)),
      );
    }

    final now = DateTime.now().toIso8601String();
    final product = Product(
      id: widget.productId,
      nameGujarati: _nameGuController.text.trim(),
      nameEnglish: _nameEnController.text.trim().isEmpty
          ? null
          : _nameEnController.text.trim(),
      transliterationKeys: _translitController.text.trim(),
      categoryId: null,
      unitType: _dbUnitType(_unitType),
      buyPrice: buyPrice,
      sellPrice: sellPrice,
      stockQty: stock,
      minStockQty: minStock,
      isActive: _isActive,
      createdAt: widget.productId == null ? now : null,
      updatedAt: now,
    );

    final notifier = ref.read(productProvider.notifier);
    if (widget.productId == null) {
      await notifier.addProduct(product);
    } else {
      await notifier.updateProduct(product);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.successProductSaved)),
    );
    Navigator.pop(context);
  }

  String _dbUnitType(String uiLabel) {
    if (uiLabel == AppStrings.unitKilo) return 'weight_kg';
    if (uiLabel == AppStrings.unitGram) return 'weight_gram';
    if (uiLabel == AppStrings.unitPiece) return 'count';
    if (uiLabel == AppStrings.unitLitre) return 'litre';
    return 'count';
  }
}
