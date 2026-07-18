import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/utils/weight_calculator.dart';
import '../../../../core/utils/currency_format.dart';
import '../../../../core/constants/app_strings.dart' as strings;
import '../../../../data/models/item.dart';

class ProductAdditionDialog extends StatefulWidget {
  final Item item;
  final Future<bool> Function(int itemId, double newQtyGrams) checkStock;

  const ProductAdditionDialog({
    super.key,
    required this.item,
    required this.checkStock,
  });

  static Future<(double qtyGrams, double amount)?> show(
    BuildContext context, {
    required Item item,
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
  final _weightEntryController = TextEditingController();
  final _weightEntryFocusNode = FocusNode();
  bool _focusScheduled = false;

  @override
  void initState() {
    super.initState();
    _amountPaid = widget.item.salePrice;
  }

  @override
  void dispose() {
    _weightEntryController.dispose();
    _weightEntryFocusNode.dispose();
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

    if (_mode == 'amount') {
      finalQty = WeightCalculator.calculateWeightFromAmount(
        amountPaid: _amountPaid,
        sellPricePerKg: item.salePrice,
      );
      finalAmount = _amountPaid;
    } else {
      final rawKg = _weightEntryController.text.trim();
      final parsedKg = double.tryParse(rawKg);
      if (rawKg.isEmpty || parsedKg == null || parsedKg <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('વજન દાખલ કરો')),
        );
        FocusScope.of(context).requestFocus(_weightEntryFocusNode);
        return;
      }
      final grams = parsedKg * 1000.0;
      finalAmount = WeightCalculator.calculateAmountFromWeight(
        weightGrams: grams,
        sellPricePerKg: item.salePrice,
      );
      finalQty = grams;
    }

    final hasStock = await widget.checkStock(item.id!, finalQty);
    if (!mounted) return;

    if (!hasStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('સ્ટોક અવેલેબલ નથી કૃપા કરી ખરીદી ની યાદી માં એડ કરો'),
        ),
      );
      FocusScope.of(context).requestFocus(_weightEntryFocusNode);
      return;
    }

    Navigator.of(context).pop((finalQty, finalAmount));
  }

  @override
  Widget build(BuildContext context) {
    double? calculatedWeight;
    double? calculatedAmount;

    if (_mode == 'amount') {
      calculatedWeight = WeightCalculator.calculateWeightFromAmount(
        amountPaid: _amountPaid,
        sellPricePerKg: widget.item.salePrice,
      );
    } else {
      final parsedKg = double.tryParse(_weightEntryController.text.trim());
      if (parsedKg != null && parsedKg > 0) {
        calculatedAmount = WeightCalculator.calculateAmountFromWeight(
          weightGrams: parsedKg * 1000.0,
          sellPricePerKg: widget.item.salePrice,
        );
      }
    }

    if (_mode == 'weight' && !_focusScheduled) {
      _focusScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _weightEntryFocusNode.requestFocus();
      });
    }

    return AlertDialog(
      title: Text(widget.item.nameGu),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                        _weightEntryFocusNode.requestFocus();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_mode == 'amount') ...[
                TextField(
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                        _weightEntryFocusNode.hasFocus &&
                        (event.logicalKey == LogicalKeyboardKey.enter ||
                            event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
                      _submit();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: _weightEntryController,
                    focusNode: _weightEntryFocusNode,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'વજન (કિલો)',
                      hintText: 'કિલોમાં દાખલ કરો જેમ કે 1.500',
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
