import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart' as strings;
import '../../../../core/utils/currency_format.dart';
import '../../../../core/utils/weight_calculator.dart';
import '../../../../shared/models/product_model.dart';

class ProductAdditionDialog extends StatefulWidget {
  final Product item;
  final Future<bool> Function(int itemId, double newQtyGrams) checkStock;

  const ProductAdditionDialog({
    super.key,
    required this.item,
    required this.checkStock,
  });

  static Future<(double qtyGrams, double amount)?> show(
    BuildContext context, {
    required Product item,
    required Future<bool> Function(int, double) checkStock,
  }) {
    return showDialog<(double, double)>(
      context: context,
      builder: (ctx) => ProductAdditionDialog(item: item, checkStock: checkStock),
    );
  }

  @override
  State<ProductAdditionDialog> createState() => _ProductAdditionDialogState();
}

class _ProductAdditionDialogState extends State<ProductAdditionDialog> {
  String _mode = 'weight';
  double _amountPaid = 0.0;
  final _entryController = TextEditingController();
  final _entryFocusNode = FocusNode();
  bool _focusScheduled = false;

  bool get _isWeightProduct {
    final u = widget.item.unitType.trim().toLowerCase();
    return u.contains('કિલો') ||
        u == 'kg' ||
        u.contains('kilo') ||
        u.contains('ગ્રામ') ||
        u == 'g' ||
        u.contains('gram');
  }

  @override
  void initState() {
    super.initState();
    _amountPaid = widget.item.sellPrice;
    if (!_isWeightProduct) {
      _mode = 'quantity';
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _entryFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final item = widget.item;
    if (item.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('પ્રોડક્ટ પસંદ કરો')),
      );
      return;
    }

    double finalAmount;
    double finalQty;

    if (_isWeightProduct) {
      if (_mode == 'amount') {
        finalQty = WeightCalculator.calculateWeightFromAmount(
          amountPaid: _amountPaid,
          sellPricePerKg: item.sellPrice,
        );
        finalAmount = _amountPaid;
      } else {
        final raw = _entryController.text.trim();
        final parsed = double.tryParse(raw);
        if (raw.isEmpty || parsed == null || parsed <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('વજન દાખલ કરો')),
          );
          FocusScope.of(context).requestFocus(_entryFocusNode);
          return;
        }
        final grams = parsed * 1000.0;
        finalAmount = WeightCalculator.calculateAmountFromWeight(
          weightGrams: grams,
          sellPricePerKg: item.sellPrice,
        );
        finalQty = grams;
      }
    } else {
      // Non-weight items (piece/packet/unit) - number of items only
      final raw = _entryController.text.trim();
      final parsed = double.tryParse(raw);
      if (raw.isEmpty || parsed == null || parsed <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('નંગ / સંખ્યા દાખલ કરો')),
        );
        FocusScope.of(context).requestFocus(_entryFocusNode);
        return;
      }
      finalQty = parsed;
      finalAmount = finalQty * item.sellPrice;
    }

    final hasStock = await widget.checkStock(item.id!, finalQty);
    if (!mounted) return;

    if (!hasStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('સ્ટોક અવેલેબલ નથી કૃપા કરી ખરીદી ની યાદી માં એડ કરો'),
        ),
      );
      FocusScope.of(context).requestFocus(_entryFocusNode);
      return;
    }

    context.pop((finalQty, finalAmount));
  }

  @override
  Widget build(BuildContext context) {
    double? calculatedWeight;
    double? calculatedAmount;

    if (_isWeightProduct) {
      if (_mode == 'amount') {
        calculatedWeight = WeightCalculator.calculateWeightFromAmount(
          amountPaid: _amountPaid,
          sellPricePerKg: widget.item.sellPrice,
        );
      } else {
        final parsedKg = double.tryParse(_entryController.text.trim());
        if (parsedKg != null && parsedKg > 0) {
          calculatedAmount = WeightCalculator.calculateAmountFromWeight(
            weightGrams: parsedKg * 1000.0,
            sellPricePerKg: widget.item.sellPrice,
          );
        }
      }
    } else {
      final parsedQty = double.tryParse(_entryController.text.trim());
      if (parsedQty != null && parsedQty > 0) {
        calculatedAmount = parsedQty * widget.item.sellPrice;
      }
    }

    if (_mode != 'amount' && !_focusScheduled) {
      _focusScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _entryFocusNode.requestFocus();
      });
    }

    return AlertDialog(
      title: Text(widget.item.nameGujarati),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isWeightProduct) ...[
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('₹ રૂપિયાથી'),
                      selected: _mode == 'amount',
                      onSelected: (_) => setState(() => _mode = 'amount'),
                    ),
                    ChoiceChip(
                      label: const Text('⚖ વજનથી'),
                      selected: _mode == 'weight',
                      onSelected: (_) {
                        setState(() => _mode = 'weight');
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          _entryFocusNode.requestFocus();
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              if (_isWeightProduct && _mode == 'amount') ...[
                TextField(
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: '₹ રકમ દાખલ કરો',
                  ),
                  onChanged: (v) {
                    final parsed = double.tryParse(v);
                    if (parsed != null) {
                      setState(() => _amountPaid = parsed);
                    }
                  },
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 8),
                if (calculatedWeight != null)
                  Text(
                    'આપો: ${WeightCalculator.formatWeight(calculatedWeight)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 16,
                    ),
                  ),
              ] else ...[
                Focus(
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent &&
                        _entryFocusNode.hasFocus &&
                        (event.logicalKey == LogicalKeyboardKey.enter ||
                            event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
                      _submit();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: _entryController,
                    focusNode: _entryFocusNode,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        _isWeightProduct
                            ? RegExp(r'^\d*\.?\d{0,3}')
                            : RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: _isWeightProduct
                          ? 'વજન (કિલો)'
                          : 'નંગ / સંખ્યા (${widget.item.unitType})',
                      hintText: _isWeightProduct
                          ? 'કિલોમાં દાખલ કરો જેમ કે 1.500'
                          : 'નંગ દાખલ કરો જેમ કે 1, 2, 5',
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(height: 8),
                if (calculatedAmount != null)
                  Text(
                    'રકમ: ${formatCurrency(calculatedAmount)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 16,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: const Text(strings.AppStrings.cancelButton),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text(strings.AppStrings.addButton),
        ),
      ],
    );
  }
}
