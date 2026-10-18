import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_format.dart';
import '../../../../data/providers.dart';
import '../../../../data/repositories/purchase_repository.dart';
import '../../../../domain/models/models.dart';
import '../providers/purchase_providers.dart';
import 'dialogs/sell_price_alert_dialog.dart';

class AddPurchaseScreen extends ConsumerStatefulWidget {
  const AddPurchaseScreen({super.key});

  @override
  ConsumerState<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends ConsumerState<AddPurchaseScreen> {
  final _searchCtrl = TextEditingController();
  final _supplierNameCtrl = TextEditingController();
  final _supplierPhoneCtrl = TextEditingController();
  final _paidAmountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<Product> _searchResults = [];
  bool _isSearching = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(purchaseDraftProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _supplierNameCtrl.dispose();
    _supplierPhoneCtrl.dispose();
    _paidAmountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final results = await ref.read(itemRepositoryProvider).search(trimmed);
    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void _addItem(Product product) {
    ref.read(purchaseDraftProvider.notifier).addProduct(product);
    _searchCtrl.clear();
    setState(() => _searchResults = []);
  }

  Future<void> _pickDate() async {
    final current = ref.read(purchaseDraftProvider).purchaseDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      ref.read(purchaseDraftProvider.notifier).setPurchaseDate(picked);
    }
  }

  Future<void> _savePurchase() async {
    final draft = ref.read(purchaseDraftProvider);
    if (draft.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('કૃપા કરીને ઓછામાં ઓછી એક વસ્તુ ઉમેરો.'),
          backgroundColor: AppColors.alert,
        ),
      );
      return;
    }

    // Check for items with cost increases >= 10%
    final itemsWithAlerts = draft.items
        .where((i) => i.hasSignificantIncrease && i.customSellPrice == null)
        .map((i) => SellPriceAlertItem.fromDraft(i))
        .toList();

    Map<int, double?> sellPriceUpdates = {};

    if (itemsWithAlerts.isNotEmpty) {
      final updates = await SellPriceAlertDialog.show(
        context,
        items: itemsWithAlerts,
      );
      if (updates != null) {
        sellPriceUpdates = updates;
      }
    }

    setState(() => _isSaving = true);

    try {
      final purchaseRepo = ref.read(purchaseRepositoryProvider);

      final inputs = draft.items.map((item) {
        final customPrice = sellPriceUpdates.containsKey(item.product.id)
            ? sellPriceUpdates[item.product.id]
            : item.customSellPrice;
        return PurchaseItemInput(
          productId: item.product.id!,
          qty: item.qty,
          unitCost: item.unitCost,
          customSellPrice: customPrice,
        );
      }).toList();

      final paidVal = double.tryParse(_paidAmountCtrl.text.trim()) ??
          (draft.paymentMode == 'khata' ? 0.0 : draft.totalAmount);

      final result = await purchaseRepo.createPurchase(
        purchaseDate: draft.purchaseDate,
        supplierName: _supplierNameCtrl.text.trim(),
        supplierPhone: _supplierPhoneCtrl.text.trim(),
        paymentMode: draft.paymentMode,
        paidAmount: paidVal,
        notes: _notesCtrl.text.trim(),
        items: inputs,
      );

      // Invalidate relevant providers to refresh UI
      ref.invalidate(purchasesListProvider);
      ref.invalidate(purchaseSummaryProvider);
      ref.invalidate(registeredSuppliersProvider);
      ref.invalidate(expenseRepositoryProvider);
      ref.invalidate(stockRepositoryProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ખરીદી #${result.purchaseNo} સફળતાપૂર્વક સાચવવામાં આવી!'),
          backgroundColor: AppColors.success,
        ),
      );

      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ભૂલ: $e'),
          backgroundColor: AppColors.alert,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(purchaseDraftProvider);
    final suppliersAsync = ref.watch(registeredSuppliersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Clean light slate background
      appBar: AppBar(
        title: const Text('નવી ખરીદી નોંધણી (Add Purchase)'),
        actions: [
          TextButton.icon(
            onPressed: () {
              ref.read(purchaseDraftProvider.notifier).reset();
              _supplierNameCtrl.clear();
              _supplierPhoneCtrl.clear();
              _notesCtrl.clear();
              _paidAmountCtrl.clear();
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('રીસેટ'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── TOP HEADER CARD: Vendor, Payment Mode, Date ──
                      _buildTopHeaderCard(draft, suppliersAsync),

                      const SizedBox(height: 14),

                      // ── PRODUCT SEARCH BAR ──
                      _buildProductSearchBar(),

                      // Search results floating container
                      if (_searchResults.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _buildSearchResultsList(),
                      ],

                      const SizedBox(height: 16),

                      // ── ITEMS LIST TITLE ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${draft.items.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'ખરીદેલી વસ્તુઓ (Purchase Items)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          if (draft.items.isNotEmpty)
                            Text(
                              'કુલ પડતર: ${formatCurrency(draft.totalAmount)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // ── INDIVIDUAL SEPARATED PRODUCT CARDS ──
                      if (draft.items.isEmpty)
                        _buildEmptyState()
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: draft.items.length,
                          itemBuilder: (ctx, index) {
                            return _buildSeparatedProductCard(
                              draft.items[index],
                              index,
                            );
                          },
                        ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── BOTTOM SUMMARY & ACTION BAR ──
          _buildBottomActionBar(draft),
        ],
      ),
    );
  }

  /// Top full-width header card for Vendor Name, Payment Mode, Date, and Notes
  Widget _buildTopHeaderCard(
    PurchaseDraftState draft,
    AsyncValue<List<Map<String, String>>> suppliersAsync,
  ) {
    final dateStr =
        '${draft.purchaseDate.day}/${draft.purchaseDate.month}/${draft.purchaseDate.year}';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.store_mall_directory_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'સપ્લાયર અને ચુકવણી વિગત (Supplier & Payment Info)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Top row: Supplier Autocomplete/Dropdown + Payment Mode + Date
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // 1. Supplier / Vendor Selector (with pre-registered dropdown & type-in)
                SizedBox(
                  width: 320,
                  child: suppliersAsync.when(
                    data: (suppliers) {
                      final vendorNames = suppliers.map((s) => s['name']!).toList();
                      return Autocomplete<String>(
                        initialValue: TextEditingValue(text: draft.supplierName),
                        optionsBuilder: (textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return vendorNames;
                          }
                          return vendorNames.where((v) => v
                              .toLowerCase()
                              .contains(textEditingValue.text.toLowerCase()));
                        },
                        onSelected: (selection) {
                          _supplierNameCtrl.text = selection;
                          ref.read(purchaseDraftProvider.notifier).setSupplierName(selection);
                          final match = suppliers.firstWhere(
                            (s) => s['name'] == selection,
                            orElse: () => {'name': selection, 'phone': ''},
                          );
                          if (match['phone']?.isNotEmpty == true) {
                            _supplierPhoneCtrl.text = match['phone']!;
                            ref.read(purchaseDraftProvider.notifier).setSupplierPhone(match['phone']!);
                          }
                        },
                        fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: textController,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: 'વેપારી / સપ્લાયરનું નામ (Vendor Name)',
                              hintText: 'યાદીમાંથી પસંદ કરો અથવા નવું લખો',
                              prefixIcon: const Icon(Icons.person_pin_outlined, size: 20),
                              suffixIcon: vendorNames.isNotEmpty
                                  ? const Icon(Icons.arrow_drop_down, color: Colors.grey)
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            onChanged: (val) {
                              _supplierNameCtrl.text = val;
                              ref.read(purchaseDraftProvider.notifier).setSupplierName(val);
                            },
                          );
                        },
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => TextField(
                      controller: _supplierNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'વેપારીનું નામ (Vendor Name)',
                        prefixIcon: const Icon(Icons.person_pin_outlined, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (val) {
                        ref.read(purchaseDraftProvider.notifier).setSupplierName(val);
                      },
                    ),
                  ),
                ),

                // 2. Payment Mode Selector
                SizedBox(
                  width: 230,
                  child: DropdownButtonFormField<String>(
                    initialValue: draft.paymentMode,
                    decoration: InputDecoration(
                      labelText: 'ચુકવણી (Payment Mode)',
                      prefixIcon: const Icon(Icons.payment, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'cash',
                        child: Text('રોકડ (Cash)'),
                      ),
                      DropdownMenuItem(
                        value: 'khata',
                        child: Text('ખાતું / ઉધાર (Khata)'),
                      ),
                      DropdownMenuItem(
                        value: 'bank',
                        child: Text('બેંક / UPI (Online)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(purchaseDraftProvider.notifier).setPaymentMode(val);
                        if (val == 'cash' || val == 'bank') {
                          _paidAmountCtrl.text = draft.totalAmount.toStringAsFixed(2);
                        } else if (val == 'khata') {
                          _paidAmountCtrl.text = '0.00';
                        }
                      }
                    },
                  ),
                ),

                // 3. Purchase Date Picker
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          dateStr,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),

                // 4. Optional Bill / Invoice Number or Notes
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _notesCtrl,
                    decoration: InputDecoration(
                      labelText: 'બિલ / ચલણ નં. (Invoice No)',
                      hintText: 'વૈકલ્પિક નોંધ',
                      prefixIcon: const Icon(Icons.receipt_outlined, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Full-width search bar for finding products
  Widget _buildProductSearchBar() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'પ્રોડક્ટ ઉમેરો (નામ, બારકોડ અથવા અંગ્રેજીમાં લખો)...',
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: AppColors.primary),
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (_searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchResults = []);
                        },
                      )
                    : null),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
          onChanged: _onSearch,
        ),
      ),
    );
  }

  /// Live search results dropdown list
  Widget _buildSearchResultsList() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, idx) {
          final p = _searchResults[idx];
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              backgroundColor: AppColors.primarySurface,
              child: const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.primary),
            ),
            title: Text(
              p.nameGujarati,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              '${p.nameEnglish ?? ''} • સ્ટોક: ${p.stockQty} ${p.unitType} • હાલનો પડતર: ${formatCurrency(p.buyPrice)}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: ElevatedButton.icon(
              onPressed: () => _addItem(p),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('ખરીદીમાં ઉમેરો'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
              ),
            ),
            onTap: () => _addItem(p),
          );
        },
      ),
    );
  }

  /// Separate, beautifully isolated product item card
  Widget _buildSeparatedProductCard(PurchaseLineDraft item, int index) {
    final notifier = ref.read(purchaseDraftProvider.notifier);
    final hasAlert = item.hasSignificantIncrease;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasAlert ? AppColors.warning : const Color(0xFFCBD5E1),
          width: hasAlert ? 1.6 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row of Item: Item #, Product Title, Stock Badge, Delete Button
            Row(
              children: [
                // Item number badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    '#${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Product Name (Gujarati + English)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.nameGujarati,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (item.product.nameEnglish?.isNotEmpty == true)
                        Text(
                          item.product.nameEnglish!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                    ],
                  ),
                ),

                // Current stock & selling price chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'સ્ટોક: ${item.product.stockQty} ${item.product.unitType} | વેચાણ: ${formatCurrency(item.product.sellPrice)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Delete button in a soft red container
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.alert, size: 20),
                  tooltip: 'કાઢી નાખો',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    padding: const EdgeInsets.all(6),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () => notifier.removeItem(index),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Inputs Row: Qty (with unit), Unit Cost, and Line Total
            Row(
              children: [
                // 1. Quantity Input
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: item.qty.toString(),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'નવો જથ્થો (${item.product.unitType})',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(val) ?? 1.0;
                      notifier.updateItemQty(index, parsed);
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // 2. Unit Cost Input
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: item.unitCost.toStringAsFixed(2),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'ખરીદ ભાવ (દર)',
                      prefixText: '₹ ',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(val) ?? 0.0;
                      notifier.updateItemUnitCost(index, parsed);
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // 3. Line Total Display Box
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'કુલ રકમ:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          formatCurrency(item.totalCost),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Average Cost Breakdown Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: hasAlert ? Colors.amber.shade50 : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasAlert ? Colors.amber.shade300 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasAlert ? Icons.trending_up : Icons.calculate_outlined,
                    size: 17,
                    color: hasAlert ? Colors.orange.shade800 : Colors.indigo.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'સરેરાશ પડતર: (જૂનો સ્ટોક: ${item.product.stockQty} @ ${formatCurrency(item.product.buyPrice)} + નવો: ${item.qty} @ ${formatCurrency(item.unitCost)}) ➔ નવો પડતર: ${formatCurrency(item.newAvgCost)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: hasAlert ? Colors.orange.shade900 : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  if (hasAlert)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.alert,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '+${item.percentageIncrease.toStringAsFixed(1)}% ભાવ વધારો',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Sell Price Alert & Edit Row (if price increased)
            if (hasAlert || item.customSellPrice != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.customSellPrice != null
                            ? 'નવો વેચાણ ભાવ નક્કી કર્યો: ${formatCurrency(item.customSellPrice!)}'
                            : 'પડતર ભાવ વધ્યો છે. હાલનો વેચાણ ભાવ: ${formatCurrency(item.product.sellPrice)} | સૂચિત વેચાણ ભાવ: ${formatCurrency(item.suggestedSellPrice)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final res = await SellPriceAlertDialog.show(
                          context,
                          items: [SellPriceAlertItem.fromDraft(item)],
                        );
                        if (res != null && res.containsKey(item.product.id)) {
                          notifier.updateItemSellPrice(index, res[item.product.id]);
                        }
                      },
                      icon: const Icon(Icons.edit, size: 14),
                      label: Text(item.customSellPrice != null ? 'ફરી બદલો' : 'વેચાણ ભાવ બદલો'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Empty state when no products have been added yet
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'કોઈ વસ્તુ ઉમેરેલ નથી',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'ઉપરના સર્ચ બારમાંથી પ્રોડક્ટ શોધીને ખરીદીમાં ઉમેરો',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  /// Sticky Bottom Summary & Save Bar
  Widget _buildBottomActionBar(PurchaseDraftState draft) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFCBD5E1), width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Row(
            children: [
              // Items count & Total
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'કુલ ${draft.items.length} વસ્તુઓ',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  Text(
                    formatCurrency(draft.totalAmount),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),

              // Paid amount input
              SizedBox(
                width: 170,
                child: TextField(
                  controller: _paidAmountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'ચૂકવેલ રકમ',
                    prefixText: '₹ ',
                    helperText: draft.paymentMode == 'khata' ? 'ખાતામાં બાકી' : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),

              const Spacer(),

              // Save Purchase Button
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _savePurchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline, size: 22),
                label: Text(
                  _isSaving ? 'સાચવી રહ્યા છે...' : 'ખરીદી સાચવો (Save Purchase)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
