import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_strings.dart' as strings;
import '../../../../core/utils/currency_format.dart';
import '../../../../core/utils/weight_calculator.dart';
import '../../../../shared/models/product_model.dart';

class ProductAdditionDialog extends StatefulWidget {
  final Product item;
  final Future<bool> Function(int itemId, double newQtyGrams) checkStock;

  final double? initialQtyGrams;

  const ProductAdditionDialog({
    super.key,
    required this.item,
    required this.checkStock,
    this.initialQtyGrams,
  });

  static Future<(double qtyGrams, double amount)?> show(
    BuildContext context, {
    required Product item,
    required Future<bool> Function(int, double) checkStock,
    double? initialQtyGrams,
  }) {
    return showDialog<(double, double)>(
      context: context,
      builder: (ctx) => ProductAdditionDialog(
        item: item,
        checkStock: checkStock,
        initialQtyGrams: initialQtyGrams,
      ),
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
  bool _weightSuggestionAccepted = false;

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
    if (widget.initialQtyGrams != null && widget.initialQtyGrams! > 0) {
      if (_isWeightProduct) {
        final kg = widget.initialQtyGrams! / 1000.0;
        _entryController.text = kg % 1 == 0
            ? kg.toInt().toString()
            : kg.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
      } else {
        _entryController.text = widget.initialQtyGrams!.toInt().toString();
      }
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
        const SnackBar(
          content: Text('પ્રોડક્ટ પસંદ કરો'),
          duration: Duration(seconds: 2),
        ),
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
        final grams = WeightCalculator.parseWeightInputGrams(
          raw,
          suggestionAccepted: _weightSuggestionAccepted,
        );
        if (raw.isEmpty || grams <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('વજન દાખલ કરો'),
              duration: Duration(seconds: 2),
            ),
          );
          FocusScope.of(context).requestFocus(_entryFocusNode);
          return;
        }
        finalAmount = WeightCalculator.calculateAmountFromWeight(
          weightGrams: grams,
          sellPricePerKg: item.sellPrice,
        );
        finalQty = grams;
      }
    } else {
      // Non-weight items (piece/packet/unit) - whole number of items only
      final raw = _entryController.text.trim();
      final parsed = int.tryParse(raw);
      if (raw.isEmpty || parsed == null || parsed <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('નંગ / સંખ્યા દાખલ કરો'),
            duration: Duration(seconds: 2),
          ),
        );
        FocusScope.of(context).requestFocus(_entryFocusNode);
        return;
      }
      finalQty = parsed.toDouble();
      finalAmount = finalQty * item.sellPrice;
    }

    final hasStock = await widget.checkStock(item.id!, finalQty);
    if (!mounted) return;

    if (!hasStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('સ્ટોક અવેલેબલ નથી કૃપા કરી ખરીદી ની યાદી માં એડ કરો'),
          duration: Duration(seconds: 2),
        ),
      );
      FocusScope.of(context).requestFocus(_entryFocusNode);
      return;
    }

    Navigator.of(context).pop<(double, double)>((finalQty, finalAmount));
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
      final parsedQty = int.tryParse(_entryController.text.trim());
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
                    if (event is KeyDownEvent && _entryFocusNode.hasFocus) {
                      if (_isWeightProduct &&
                          event.logicalKey == LogicalKeyboardKey.arrowRight) {
                        final raw = _entryController.text.trim();
                        if (raw == '0.5' || raw == '.5') {
                          _weightSuggestionAccepted = true;
                          _entryController.text = '0.500';
                          _entryController.selection =
                              const TextSelection.collapsed(offset: 5);
                          setState(() {});
                          return KeyEventResult.handled;
                        }
                      }
                      if (event.logicalKey == LogicalKeyboardKey.enter ||
                          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                        _submit();
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: _entryController,
                    focusNode: _entryFocusNode,
                    autofocus: true,
                    keyboardType: _isWeightProduct
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        _isWeightProduct
                            ? RegExp(r'^\d*\.?\d{0,3}')
                            : RegExp(r'^\d+'),
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
                if (_isWeightProduct &&
                    (_entryController.text.trim() == '0.5' ||
                        _entryController.text.trim() == '.5')) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: () {
                        _weightSuggestionAccepted = true;
                        _entryController.text = '0.500';
                        _entryController.selection =
                            const TextSelection.collapsed(offset: 5);
                        setState(() {});
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFF3B82F6), width: 1.2),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '૫૦૦ ગ્રામ (500g)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward,
                                size: 14, color: Color(0xFF1D4ED8)),
                            SizedBox(width: 2),
                            Text(
                              '(→)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
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
          onPressed: () => Navigator.of(context).pop(),
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
