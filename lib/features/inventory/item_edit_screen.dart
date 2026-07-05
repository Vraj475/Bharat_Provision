import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_strings.dart';
import '../../data/models/item.dart';
import '../../data/providers.dart';
import 'inventory_providers.dart';
import 'item_edit_form.dart';

class ItemEditScreen extends ConsumerStatefulWidget {
  const ItemEditScreen({super.key, this.itemId});

  final int? itemId;

  @override
  ConsumerState<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends ConsumerState<ItemEditScreen> {
  final _nameController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _lowStockController = TextEditingController();
  final _barcodeController = TextEditingController();

  int? _categoryId;
  String _unit = AppStrings.unitPiece;
  bool _isActive = true;
  bool _loading = true;
  Item? _item;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (widget.itemId == null) {
      setState(() {
        _loading = false;
        _salePriceController.text = '0';
        _purchasePriceController.text = '0';
        _stockController.text = '0';
        _lowStockController.text = '0';
      });
      return;
    }
    final repo = await ref.read(itemRepositoryFutureProvider.future);
    final item = await repo.getById(widget.itemId!);
    if (item != null && mounted) {
      setState(() {
        _item = item;
        _nameController.text = item.nameGu;
        _salePriceController.text = item.salePrice.toString();
        _purchasePriceController.text = item.purchasePrice.toString();
        _stockController.text = item.currentStock.toString();
        _lowStockController.text = item.lowStockThreshold.toString();
        _barcodeController.text = item.barcode ?? '';
        _categoryId = item.categoryId;
        _unit = item.unit;
        _isActive = item.isActive;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _salePriceController.dispose();
    _purchasePriceController.dispose();
    _stockController.dispose();
    _lowStockController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.fieldRequired)));
      return;
    }

    final salePrice = double.tryParse(_salePriceController.text) ?? 0;
    final purchasePrice = double.tryParse(_purchasePriceController.text) ?? 0;
    final stock = double.tryParse(_stockController.text) ?? 0;
    final lowStock = double.tryParse(_lowStockController.text) ?? 0;

    final repo = await ref.read(itemRepositoryFutureProvider.future);

    try {
      if (_item != null) {
        await repo.update(
          _item!.copyWith(
            nameGu: name,
            categoryId: _categoryId,
            barcode: _barcodeController.text.trim().isEmpty
                ? null
                : _barcodeController.text.trim(),
            unit: _unit,
            salePrice: salePrice,
            purchasePrice: purchasePrice,
            currentStock: stock,
            lowStockThreshold: lowStock,
            isActive: _isActive,
          ),
        );
      } else {
        await repo.insert(
          Item(
            nameGu: name,
            categoryId: _categoryId,
            barcode: _barcodeController.text.trim().isEmpty
                ? null
                : _barcodeController.text.trim(),
            unit: _unit,
            salePrice: salePrice,
            purchasePrice: purchasePrice,
            currentStock: stock,
            lowStockThreshold: lowStock,
            isActive: _isActive,
          ),
        );
      }
      ref.invalidate(itemListProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ઉત્પાદ સફળતાપૂર્વક સેવ થયું')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.errorGeneric} $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.itemId != null ? AppStrings.editItem : AppStrings.addItem,
        ),
      ),
      body: ItemEditForm(
        nameController: _nameController,
        salePriceController: _salePriceController,
        purchasePriceController: _purchasePriceController,
        stockController: _stockController,
        lowStockController: _lowStockController,
        barcodeController: _barcodeController,
        categoryId: _categoryId,
        unit: _unit,
        isActive: _isActive,
        categoriesAsync: ref.watch(categoryListProvider),
        onCategoryChanged: (value) => setState(() => _categoryId = value),
        onUnitChanged: (value) => setState(() => _unit = value),
        onActiveChanged: (value) => setState(() => _isActive = value),
        onSave: _save,
      ),
    );
  }
}
