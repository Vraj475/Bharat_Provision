import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/models/expense_account_model.dart';
import '../../shared/models/product_model.dart';
import 'stock_providers.dart';

class AddStockScreen extends ConsumerStatefulWidget {
  const AddStockScreen({super.key, this.prefilledProduct});
  final Product? prefilledProduct;

  @override
  ConsumerState<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends ConsumerState<AddStockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();
  final _buyPriceCtrl = TextEditingController();
  final _supplierCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  Product? _selectedProduct;
  ExpenseAccount? _selectedExpenseAccount;
  DateTime _selectedDate = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.prefilledProduct;
    if (_selectedProduct != null) {
      _buyPriceCtrl.text = _selectedProduct!.buyPrice.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _buyPriceCtrl.dispose();
    _supplierCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _qty => double.tryParse(_qtyCtrl.text) ?? 0;
  double get _buyPrice => double.tryParse(_buyPriceCtrl.text) ?? 0;
  double get _total => _qty * _buyPrice;

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(expenseAccountsProvider);
    final productsAsync = ref.watch(stockDashboardProductsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('સ્ટોક ઉમેરો')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Product selector
            _buildSectionHeader('ઉત્પાદ'),
            productsAsync.when(
              data: (products) => _ProductDropdown(
                products: products,
                selectedProduct: _selectedProduct,
                onChanged: (p) => setState(() {
                  _selectedProduct = p;
                  if (p != null) {
                    _buyPriceCtrl.text = p.buyPrice.toStringAsFixed(2);
                  }
                }),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('ભૂલ: $e'),
            ),
            const SizedBox(height: 16),

            // Quantity received
            _buildSectionHeader('મળેલો જથ્થો'),
            TextFormField(
              controller: _qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'જેટલો સ્ટોક આવ્યો',
                suffixText: _selectedProduct != null
                    ? _unitLabel(_selectedProduct!.unitType)
                    : null,
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final d = double.tryParse(v ?? '');
                if (d == null || d <= 0) return 'યોગ્ય જથ્થો દાખલ કરો';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Buy price per unit
            _buildSectionHeader(
              'ખરીદ ભાવ (₹ / ${_selectedProduct != null ? _unitLabel(_selectedProduct!.unitType) : "એકમ"})',
            ),
            TextFormField(
              controller: _buyPriceCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixText: '₹ ',
                hintText: '0.00',
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final d = double.tryParse(v ?? '');
                if (d == null || d <= 0) return 'યોગ્ય ભાવ દાખલ કરો';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Expense account dropdown
            _buildSectionHeader('ખર્ચ ખાતું (P&L)'),
            accountsAsync.when(
              data: (accounts) {
                // Default to 'ખરીદી' account
                if (_selectedExpenseAccount == null && accounts.isNotEmpty) {
                  final khardi = accounts.firstWhere(
                    (a) => a.accountNameGujarati == 'ખરીદી',
                    orElse: () => accounts.first,
                  );
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _selectedExpenseAccount == null) {
                      setState(() => _selectedExpenseAccount = khardi);
                    }
                  });
                }
                return DropdownButtonFormField<ExpenseAccount>(
                  initialValue: _selectedExpenseAccount,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('ખાતું પસંદ કરો'),
                  items: accounts
                      .map(
                        (a) => DropdownMenuItem(
                          value: a,
                          child: Text(a.accountNameGujarati),
                        ),
                      )
                      .toList(),
                  onChanged: (a) => setState(() => _selectedExpenseAccount = a),
                  validator: (_) =>
                      _selectedExpenseAccount == null ? 'ખાતું પસંદ કરો' : null,
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('ભૂલ: $e'),
            ),
            const SizedBox(height: 16),

            // Total (read-only)
            _buildSectionHeader('કુલ ખરીદ રકમ (ઓટો)'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '₹ ${_total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Supplier name (optional)
            _buildSectionHeader('સપ્લાયરનું નામ (વૈકલ્પિક)'),
            TextField(
              controller: _supplierCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'સ્ત્રોત / સપ્લાયર',
              ),
            ),
            const SizedBox(height: 16),

            // Date picker
            _buildSectionHeader('તારીખ'),
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('dd/MM/yyyy').format(_selectedDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Notes (optional)
            _buildSectionHeader('નોંધ (વૈકલ્પિક)'),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'વધારાની માહિતી...',
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('સ્ટોક સાચવો'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
    ),
  );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ઉત્પાદ પસંદ કરો')));
      return;
    }
    if (_selectedExpenseAccount == null) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(stockRepositoryProvider);
      final result = await repo.addStock(
        productId: _selectedProduct!.id!,
        qtyReceived: _qty,
        buyPrice: _buyPrice,
        expenseAccountId: _selectedExpenseAccount!.id!,
        expenseAccountName: _selectedExpenseAccount!.accountNameGujarati,
        supplierName: _supplierCtrl.text.trim().isEmpty
            ? null
            : _supplierCtrl.text.trim(),
        date: _selectedDate,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'સ્ટોક ઉમેરાયો — નવો જથ્થો: ${result.updatedProduct.stockQty.toStringAsFixed(1)}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        // Invalidate providers so dashboard & history refresh
        ref.invalidate(stockDashboardProductsProvider);
        ref.invalidate(stockSummaryProvider);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ભૂલ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _unitLabel(String unitType) {
    switch (unitType) {
      case 'weight_kg':
        return 'kg';
      case 'weight_gram':
        return 'g';
      case 'litre':
        return 'L';
      default:
        return 'નંગ';
    }
  }
}

// ─── Searchable product dropdown ──────────────────────────────────────────────

class _ProductDropdown extends StatefulWidget {
  const _ProductDropdown({
    required this.products,
    required this.selectedProduct,
    required this.onChanged,
  });
  final List<Product> products;
  final Product? selectedProduct;
  final ValueChanged<Product?> onChanged;

  @override
  State<_ProductDropdown> createState() => _ProductDropdownState();
}

class _ProductDropdownState extends State<_ProductDropdown> {
  final _ctrl = TextEditingController();
  OverlayEntry? _overlay;
  final _key = GlobalKey();
  List<Product> _filtered = [];

  @override
  void initState() {
    super.initState();
    if (widget.selectedProduct != null) {
      _ctrl.text = widget.selectedProduct!.nameGujarati;
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _ctrl.dispose();
    super.dispose();
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _showOverlay(List<Product> items) {
    _removeOverlay();
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;

    _overlay = OverlayEntry(
      builder: (_) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height,
        width: size.width,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (_, i) => ListTile(
                dense: true,
                title: Text(items[i].nameGujarati),
                subtitle: Text(
                  'સ્ટોક: ${items[i].stockQty.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () {
                  _ctrl.text = items[i].nameGujarati;
                  widget.onChanged(items[i]);
                  _removeOverlay();
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: _key,
      controller: _ctrl,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        hintText: 'ઉત્પાદ શોધો...',
        suffixIcon: widget.selectedProduct != null
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _ctrl.clear();
                  widget.onChanged(null);
                  _removeOverlay();
                },
              )
            : const Icon(Icons.search),
      ),
      onChanged: (v) {
        final q = v.toLowerCase();
        _filtered = widget.products.where((p) {
          return p.nameGujarati.toLowerCase().contains(q) ||
              (p.nameEnglish?.toLowerCase().contains(q) ?? false) ||
              p.transliterationKeys.toLowerCase().contains(q);
        }).toList();
        if (_filtered.isNotEmpty && v.isNotEmpty) {
          _showOverlay(_filtered);
        } else {
          _removeOverlay();
        }
      },
      onTap: () {
        if (_ctrl.text.isEmpty) {
          _filtered = widget.products;
          _showOverlay(_filtered);
        }
      },
    );
  }
}
