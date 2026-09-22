import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../models/bill_line_item.dart';
import '../controllers/billing_controller.dart';
import '../../../core/utils/currency_format.dart';

enum _DraftEditableField { quantity, price, amount }

class BillLinesPanel extends ConsumerStatefulWidget {
  final Future<bool> Function({required int itemId, required double newQtyGrams, int? excludeLineIndex}) checkStock;

  const BillLinesPanel({
    super.key,
    required this.checkStock,
  });

  @override
  ConsumerState<BillLinesPanel> createState() => _BillLinesPanelState();
}

class _BillLinesPanelState extends ConsumerState<BillLinesPanel> {
  final Map<String, TextEditingController> _lineEditControllers = {};
  final Map<String, FocusNode> _lineEditFocusNodes = {};
  String? _editingLineKey;
  _DraftEditableField? _editingField;
  bool _isCommittingInlineEdit = false;

  @override
  void dispose() {
    for (final controller in _lineEditControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _lineEditFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _registerLineResources(String lineKey, {String? initialText}) {
    _lineEditControllers[lineKey] = TextEditingController(
      text: initialText ?? '',
    );
    _lineEditFocusNodes[lineKey] = FocusNode();
  }

  void _disposeLineResources(String lineKey) {
    _lineEditControllers.remove(lineKey)?.dispose();
    _lineEditFocusNodes.remove(lineKey)?.dispose();
  }

  void _clearInlineEditState() {
    final key = _editingLineKey;
    if (key != null) {
      _lineEditFocusNodes[key]?.unfocus();
    }
    _editingLineKey = null;
    _editingField = null;
  }

  bool _isWeightItem(BillLineItem line) {
    final u = line.item.unitType.trim().toLowerCase();
    return u.contains('કિલો') ||
        u == 'kg' ||
        u.contains('kilo') ||
        u.contains('ગ્રામ') ||
        u == 'g' ||
        u.contains('gram');
  }

  double _lineUnitPrice(BillLineItem line) {
    if (line.qtyGrams <= 0) return line.item.sellPrice;
    if (_isWeightItem(line)) {
      return (line.amount * 1000.0) / line.qtyGrams;
    }
    return line.amount / line.qtyGrams;
  }

  String _kgEditableText(double qtyGrams) {
    return (qtyGrams / 1000.0).toStringAsFixed(3);
  }

  void _startInlineEdit(int index, _DraftEditableField field) {
    if (index < 0 || index >= ref.read(billingControllerProvider).billLines.length) return;

    if (_editingLineKey != null) {
      _commitInlineEdit();
    }

    final line = ref.read(billingControllerProvider).billLines[index];
    final lineKey = line.draftKey;
    if (!_lineEditControllers.containsKey(lineKey) ||
        !_lineEditFocusNodes.containsKey(lineKey)) {
      _registerLineResources(lineKey);
    }
    final lineController = _lineEditControllers[lineKey]!;
    final lineFocusNode = _lineEditFocusNodes[lineKey]!;

    final isWeight = _isWeightItem(line);
    final initialValue = switch (field) {
      _DraftEditableField.quantity =>
        isWeight ? _kgEditableText(line.qtyGrams) : line.qtyGrams.toInt().toString(),
      _DraftEditableField.price => _lineUnitPrice(line).toStringAsFixed(2),
      _DraftEditableField.amount => line.amount.toStringAsFixed(2),
    };

    setState(() {
      _editingLineKey = lineKey;
      _editingField = field;
      lineController.value = TextEditingValue(
        text: initialValue,
        selection: TextSelection.collapsed(offset: initialValue.length),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      lineFocusNode.requestFocus();
      lineController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: lineController.text.length,
      );
    });
  }

  Future<void> _commitInlineEdit() async {
    if (_isCommittingInlineEdit) return;
    _isCommittingInlineEdit = true;

    try {
      final editingLineKey = _editingLineKey;
      final editingField = _editingField;
      if (editingLineKey == null) {
        _clearInlineEditState();
        return;
      }
      final controller = _lineEditControllers[editingLineKey];
      final editingIndex = ref.read(billingControllerProvider).billLines.indexWhere(
        (l) => l.draftKey == editingLineKey,
      );

      if (editingField == null ||
          controller == null ||
          editingIndex < 0 ||
          editingIndex >= ref.read(billingControllerProvider).billLines.length) {
        _clearInlineEditState();
        return;
      }

      final line = ref.read(billingControllerProvider).billLines[editingIndex];
      final raw = controller.text.trim();
      final isWeight = _isWeightItem(line);

      BillLineItem updatedLine = line;
      if (editingField == _DraftEditableField.quantity) {
        if (isWeight) {
          final parsed = double.tryParse(raw);
          if (raw.isEmpty || parsed == null || parsed <= 0) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('વજન શૂન્ય ન હોઈ શકે')));
            setState(_clearInlineEditState);
            return;
          }

          final newQtyGrams = parsed * 1000.0;
          final itemId = line.item.id;
          if (itemId != null) {
            final hasStock = await widget.checkStock(
              itemId: itemId,
              newQtyGrams: newQtyGrams,
              excludeLineIndex: editingIndex,
            );
            if (!mounted) return;
            if (!hasStock) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'સ્ટોક અવેલેબલ નથી કૃપા કરી ખરીદી ની યાદી માં એડ કરો',
                  ),
                ),
              );
              setState(_clearInlineEditState);
              return;
            }
          }

          final existingUnitPrice = _lineUnitPrice(line);
          final newAmount = (newQtyGrams / 1000.0) * existingUnitPrice;
          updatedLine = line.copyWith(qtyGrams: newQtyGrams, amount: newAmount);
        } else {
          // Non-weight items - whole numbers only
          final parsed = int.tryParse(raw);
          if (raw.isEmpty || parsed == null || parsed <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('સંખ્યા શૂન્ય ન હોઈ શકે')),
            );
            setState(_clearInlineEditState);
            return;
          }

          final newQtyGrams = parsed.toDouble();
          final itemId = line.item.id;
          if (itemId != null) {
            final hasStock = await widget.checkStock(
              itemId: itemId,
              newQtyGrams: newQtyGrams,
              excludeLineIndex: editingIndex,
            );
            if (!mounted) return;
            if (!hasStock) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'સ્ટોક અવેલેબલ નથી કૃપા કરી ખરીદી ની યાદી માં એડ કરો',
                  ),
                ),
              );
              setState(_clearInlineEditState);
              return;
            }
          }

          final existingUnitPrice = _lineUnitPrice(line);
          final newAmount = newQtyGrams * existingUnitPrice;
          updatedLine = line.copyWith(qtyGrams: newQtyGrams, amount: newAmount);
        }
      } else if (editingField == _DraftEditableField.price) {
        final parsed = double.tryParse(raw);
        if (raw.isEmpty || parsed == null || parsed <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('કિંમત શૂન્ય ન હોઈ શકે')),
          );
          setState(_clearInlineEditState);
          return;
        }

        final roundedQty = line.qtyGrams.roundToDouble().clamp(1.0, double.infinity);
        final newAmount = isWeight
            ? (line.qtyGrams / 1000.0) * parsed
            : roundedQty * parsed;
        updatedLine = line.copyWith(
          qtyGrams: isWeight ? line.qtyGrams : roundedQty,
          amount: newAmount,
        );
      } else {
        final parsed = double.tryParse(raw);
        if (raw.isEmpty || parsed == null || parsed <= 0) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('રકમ શૂન્ય ન હોઈ શકે')));
          setState(_clearInlineEditState);
          return;
        }

        final unitPrice = _lineUnitPrice(line);
        if (unitPrice <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('કિંમત શૂન્ય ન હોઈ શકે')),
          );
          setState(_clearInlineEditState);
          return;
        }

        final newQtyGrams = isWeight
            ? (parsed / unitPrice) * 1000.0
            : line.qtyGrams.roundToDouble().clamp(1.0, double.infinity);
        updatedLine = line.copyWith(qtyGrams: newQtyGrams, amount: parsed);
      }

      ref.read(billingControllerProvider.notifier).updateLine(editingIndex, updatedLine);
      setState(() {
        _clearInlineEditState();
      });
    } finally {
      _isCommittingInlineEdit = false;
    }
  }

  Future<void> _deleteLineWithUndo(int index) async {
    if (index < 0 || index >= ref.read(billingControllerProvider).billLines.length) return;

    await _commitInlineEdit();
    if (!mounted || index < 0 || index >= ref.read(billingControllerProvider).billLines.length) return;
    final removedLine = ref.read(billingControllerProvider).billLines[index];
    final removedKey = removedLine.draftKey;

    ref.read(billingControllerProvider.notifier).removeLine(index);
    setState(() {
      if (_editingLineKey != null) {
        if (_editingLineKey == removedKey) {
          _clearInlineEditState();
        }
      }
    });
    _disposeLineResources(removedKey);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final snackBarController = messenger.showSnackBar(
      SnackBar(
        content: const Text('આઇટમ કાઢી નાખવી?'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (!mounted) return;
            if (!_lineEditControllers.containsKey(removedKey) ||
                !_lineEditFocusNodes.containsKey(removedKey)) {
              _registerLineResources(removedKey);
            }
            ref.read(billingControllerProvider.notifier).insertLine(index, removedLine);
            if (mounted) {
              setState(() {});
            }
          },
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 4), () {
      snackBarController.close();
    });
  }

  Widget _buildEditableValueChip({
    required bool isEditing,
    TextEditingController? controller,
    FocusNode? focusNode,
    required String value,
    required VoidCallback onTap,
    required ValueChanged<String> onSubmitted,
    required TextInputType keyboardType,
    String? prefixText,
    bool allowDecimal = true,
  }) {
    if (isEditing) {
      return SizedBox(
        width: 106,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              allowDecimal ? RegExp(r'^\d*\.?\d*') : RegExp(r'^\d+'),
            ),
          ],
          onSubmitted: onSubmitted,
          onTapOutside: (_) => _commitInlineEdit(),
          decoration: InputDecoration(
            isDense: true,
            prefixText: prefixText,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 110),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: Colors.grey.shade500,
            color: Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildBillLineTile(BillLineItem line, int index) {
    final lineController = _lineEditControllers[line.draftKey];
    final lineFocusNode = _lineEditFocusNodes[line.draftKey];

    final isEditingRow = _editingLineKey == line.draftKey;
    final isEditingQty =
        isEditingRow && _editingField == _DraftEditableField.quantity;
    final isEditingPrice =
        isEditingRow && _editingField == _DraftEditableField.price;
    final isEditingAmount =
        isEditingRow && _editingField == _DraftEditableField.amount;
    final isWeight = _isWeightItem(line);
    final qtyDisplay = isWeight
        ? '${_kgEditableText(line.qtyGrams)} કિલો'
        : '${line.qtyGrams.toInt()} ${line.item.unitType}';
    final priceDisplay = '₹${_lineUnitPrice(line).toStringAsFixed(2)}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isEditingRow ? AppColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.item.nameGujarati,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildEditableValueChip(
                      isEditing: isEditingQty,
                      controller: lineController,
                      focusNode: lineFocusNode,
                      value: qtyDisplay,
                      onTap: () =>
                          _startInlineEdit(index, _DraftEditableField.quantity),
                      onSubmitted: (_) => _commitInlineEdit(),
                      keyboardType: isWeight
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : TextInputType.number,
                      allowDecimal: isWeight,
                    ),
                    _buildEditableValueChip(
                      isEditing: isEditingPrice,
                      controller: lineController,
                      focusNode: lineFocusNode,
                      value: priceDisplay,
                      onTap: () =>
                          _startInlineEdit(index, _DraftEditableField.price),
                      onSubmitted: (_) => _commitInlineEdit(),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      prefixText: isEditingPrice ? '₹' : null,
                    ),
                    _buildEditableValueChip(
                      isEditing: isEditingAmount,
                      controller: lineController,
                      focusNode: lineFocusNode,
                      value: formatCurrency(line.amount),
                      onTap: () =>
                          _startInlineEdit(index, _DraftEditableField.amount),
                      onSubmitted: (_) => _commitInlineEdit(),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isEditingRow)
            SizedBox(
              width: 36,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                icon: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                ),
                onPressed: () {
                  _commitInlineEdit();
                },
              ),
            ),
          SizedBox(
            width: 36,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () async {
                await _deleteLineWithUndo(index);
              },
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final billLines = ref.watch(billingControllerProvider).billLines;
    
    return ListView.builder(
      itemCount: billLines.length,
      itemBuilder: (ctx, i) {
        final line = billLines[i];
        return _buildBillLineTile(line, i);
      },
    );
  }
}
