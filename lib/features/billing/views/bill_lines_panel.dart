import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../models/bill_line_item.dart';
import '../controllers/billing_controller.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/utils/weight_calculator.dart';

enum _DraftEditableField { quantity, price, amount }

class _LineFieldResources {
  final TextEditingController qtyController = TextEditingController();
  late final FocusNode qtyFocusNode;
  final TextEditingController priceController = TextEditingController();
  late final FocusNode priceFocusNode;
  final TextEditingController amountController = TextEditingController();
  late final FocusNode amountFocusNode;

  _LineFieldResources({
    required KeyEventResult Function(FocusNode, KeyEvent, _DraftEditableField) onKeyEvent,
  }) {
    qtyFocusNode = FocusNode(debugLabel: 'QtyNode')
      ..onKeyEvent = (node, event) => onKeyEvent(node, event, _DraftEditableField.quantity);
    priceFocusNode = FocusNode(debugLabel: 'PriceNode')
      ..onKeyEvent = (node, event) => onKeyEvent(node, event, _DraftEditableField.price);
    amountFocusNode = FocusNode(debugLabel: 'AmountNode')
      ..onKeyEvent = (node, event) => onKeyEvent(node, event, _DraftEditableField.amount);
  }

  TextEditingController controllerFor(_DraftEditableField field) {
    switch (field) {
      case _DraftEditableField.quantity:
        return qtyController;
      case _DraftEditableField.price:
        return priceController;
      case _DraftEditableField.amount:
        return amountController;
    }
  }

  FocusNode focusNodeFor(_DraftEditableField field) {
    switch (field) {
      case _DraftEditableField.quantity:
        return qtyFocusNode;
      case _DraftEditableField.price:
        return priceFocusNode;
      case _DraftEditableField.amount:
        return amountFocusNode;
    }
  }

  void dispose() {
    qtyController.dispose();
    qtyFocusNode.dispose();
    priceController.dispose();
    priceFocusNode.dispose();
    amountController.dispose();
    amountFocusNode.dispose();
  }
}

class BillLinesPanel extends ConsumerStatefulWidget {
  final Future<bool> Function({required int itemId, required double newQtyGrams, int? excludeLineIndex}) checkStock;
  final VoidCallback? onInlineEditCompleted;

  const BillLinesPanel({
    super.key,
    required this.checkStock,
    this.onInlineEditCompleted,
  });

  @override
  ConsumerState<BillLinesPanel> createState() => BillLinesPanelState();
}

class BillLinesPanelState extends ConsumerState<BillLinesPanel> {
  final Map<String, _LineFieldResources> _lineResources = {};
  String? _editingLineKey;
  _DraftEditableField? _editingField;
  bool _isCommittingInlineEdit = false;
  int? _selectedRowIndex;
  bool _weightSuggestionAccepted = false;

  int? get selectedRowIndex => _selectedRowIndex;

  void selectRow(int index) {
    final lines = ref.read(billingControllerProvider).billLines;
    if (index >= 0 && index < lines.length) {
      setState(() => _selectedRowIndex = index);
    }
  }

  void deselectRow() {
    setState(() => _selectedRowIndex = null);
  }

  void selectNextRow() {
    final lines = ref.read(billingControllerProvider).billLines;
    if (lines.isEmpty) return;
    setState(() {
      if (_selectedRowIndex == null) {
        _selectedRowIndex = 0;
      } else if (_selectedRowIndex! < lines.length - 1) {
        _selectedRowIndex = _selectedRowIndex! + 1;
      } else {
        _selectedRowIndex = 0;
      }
    });
  }

  void selectPreviousRow() {
    final lines = ref.read(billingControllerProvider).billLines;
    if (lines.isEmpty) return;
    setState(() {
      if (_selectedRowIndex == null) {
        _selectedRowIndex = lines.length - 1;
      } else if (_selectedRowIndex! > 0) {
        _selectedRowIndex = _selectedRowIndex! - 1;
      } else {
        _selectedRowIndex = lines.length - 1;
      }
    });
  }

  Future<void> deleteSelectedRow() async {
    final lines = ref.read(billingControllerProvider).billLines;
    if (lines.isEmpty) return;
    final targetIndex = _selectedRowIndex ?? 0;
    if (targetIndex >= 0 && targetIndex < lines.length) {
      await _deleteLineWithUndo(targetIndex);
    }
  }

  Future<void> incrementSelectedRowQty() async {
    final lines = ref.read(billingControllerProvider).billLines;
    if (lines.isEmpty) return;
    final targetIndex = _selectedRowIndex ?? 0;
    if (targetIndex < 0 || targetIndex >= lines.length) return;
    final line = lines[targetIndex];
    final isWeight = _isWeightItem(line);
    final step = isWeight ? 250.0 : 1.0;
    final newQty = line.qtyGrams + step;

    final itemId = line.item.id;
    if (itemId != null) {
      final hasStock = await widget.checkStock(
        itemId: itemId,
        newQtyGrams: newQty,
        excludeLineIndex: targetIndex,
      );
      if (!hasStock) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('સ્ટોક ઉપલબ્ધ નથી')),
        );
        return;
      }
    }

    final unitPrice = _lineUnitPrice(line);
    final newAmount =
        isWeight ? (newQty / 1000.0) * unitPrice : newQty * unitPrice;
    ref.read(billingControllerProvider.notifier).updateLine(
          targetIndex,
          line.copyWith(qtyGrams: newQty, amount: newAmount),
        );
  }

  Future<void> decrementSelectedRowQty() async {
    final lines = ref.read(billingControllerProvider).billLines;
    if (lines.isEmpty) return;
    final targetIndex = _selectedRowIndex ?? 0;
    if (targetIndex < 0 || targetIndex >= lines.length) return;
    final line = lines[targetIndex];
    final isWeight = _isWeightItem(line);
    final step = isWeight ? 250.0 : 1.0;
    final newQty = line.qtyGrams - step;

    if (newQty <= 0) {
      await deleteSelectedRow();
      return;
    }

    final unitPrice = _lineUnitPrice(line);
    final newAmount =
        isWeight ? (newQty / 1000.0) * unitPrice : newQty * unitPrice;
    ref.read(billingControllerProvider.notifier).updateLine(
          targetIndex,
          line.copyWith(qtyGrams: newQty, amount: newAmount),
        );
  }

  /// Focus on editing the weight/quantity of a specific line (e.g. newly added loose item)
  void startEditingLineQuantity(int index) {
    final lines = ref.read(billingControllerProvider).billLines;
    if (index < 0 || index >= lines.length) return;
    _selectedRowIndex = index;
    _startInlineEdit(index, _DraftEditableField.quantity);
  }

  /// Shortcut action: focus on editing the weight of the first product in cart (Ctrl + R)
  void startEditingFirstItemWeight() {
    final lines = ref.read(billingControllerProvider).billLines;
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('કાર્ટ ખાલી છે. પહેલા ઉત્પાદન ઉમેરો.')),
      );
      return;
    }
    _selectedRowIndex = 0;
    _startInlineEdit(0, _DraftEditableField.quantity);
  }

  /// Commits any currently active inline edit in the bill lines table
  Future<bool> commitCurrentEdit() => _commitInlineEdit();

  @override
  void dispose() {
    for (final res in _lineResources.values) {
      res.dispose();
    }
    _lineResources.clear();
    super.dispose();
  }

  _LineFieldResources _getOrCreateLineResources(String lineKey) {
    return _lineResources.putIfAbsent(
      lineKey,
      () => _LineFieldResources(
        onKeyEvent: (node, event, field) => _handleFieldKeyEvent(node, event, field),
      ),
    );
  }

  KeyEventResult _handleFieldKeyEvent(FocusNode node, KeyEvent event, _DraftEditableField field) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (field == _DraftEditableField.amount) {
          _navigateAmountRow(reverse: true);
          return KeyEventResult.handled;
        }
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (field == _DraftEditableField.amount) {
          _navigateAmountRow(reverse: false);
          return KeyEventResult.handled;
        }
      }
      if (event.logicalKey == LogicalKeyboardKey.tab) {
        final isShift = HardwareKeyboard.instance.isShiftPressed;
        _moveToNextInlineEditField(reverse: isShift);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight && field == _DraftEditableField.quantity) {
        final currentKey = _editingLineKey;
        if (currentKey != null) {
          final lines = ref.read(billingControllerProvider).billLines;
          final lineIdx = lines.indexWhere((l) => l.draftKey == currentKey);
          if (lineIdx >= 0) {
            final line = lines[lineIdx];
            if (_isWeightItem(line)) {
              final res = _lineResources[currentKey];
              final raw = res?.qtyController.text.trim();
              if (raw == '0.5' || raw == '.5') {
                _weightSuggestionAccepted = true;
                res?.qtyController.text = '0.500';
                res?.qtyController.selection = const TextSelection.collapsed(offset: 5);
                setState(() {});
                return KeyEventResult.handled;
              }
            }
          }
        }
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _commitInlineEdit(clearStateOnSuccess: true);
        widget.onInlineEditCompleted?.call();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _navigateAmountRow({required bool reverse}) async {
    final currentKey = _editingLineKey;
    if (currentKey == null) return;
    final lines = ref.read(billingControllerProvider).billLines;
    final currentIndex = lines.indexWhere((l) => l.draftKey == currentKey);
    if (currentIndex < 0) return;

    final success = await _commitInlineEdit(clearStateOnSuccess: false);
    if (!success || !mounted) return;

    final updatedLines = ref.read(billingControllerProvider).billLines;
    if (updatedLines.isEmpty) {
      _clearInlineEditState();
      widget.onInlineEditCompleted?.call();
      return;
    }

    int nextIndex = currentIndex + (reverse ? -1 : 1);
    if (nextIndex < 0) {
      nextIndex = 0;
    } else if (nextIndex >= updatedLines.length) {
      nextIndex = updatedLines.length - 1;
    }

    setState(() {
      _selectedRowIndex = nextIndex;
    });
    await _startInlineEdit(nextIndex, _DraftEditableField.amount, commitExisting: false);
  }

  void _disposeLineResources(String lineKey) {
    _lineResources.remove(lineKey)?.dispose();
  }

  void _clearInlineEditState() {
    final key = _editingLineKey;
    final field = _editingField;
    if (key != null && field != null && _lineResources.containsKey(key)) {
      _lineResources[key]!.focusNodeFor(field).unfocus();
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

  Future<void> _startInlineEdit(
    int index,
    _DraftEditableField field, {
    bool commitExisting = true,
  }) async {
    final lines = ref.read(billingControllerProvider).billLines;
    if (index < 0 || index >= lines.length) return;

    if (commitExisting && _editingLineKey != null) {
      final success = await _commitInlineEdit(clearStateOnSuccess: false);
      if (!success || !mounted) return;
    }

    final currentLines = ref.read(billingControllerProvider).billLines;
    if (index >= currentLines.length) return;
    final line = currentLines[index];
    final lineKey = line.draftKey;

    // Unfocus any currently focused field before activating the new one
    final prevKey = _editingLineKey;
    final prevField = _editingField;
    if (prevKey != null && prevField != null && _lineResources.containsKey(prevKey)) {
      _lineResources[prevKey]!.focusNodeFor(prevField).unfocus();
    }

    final res = _getOrCreateLineResources(lineKey);
    final targetController = res.controllerFor(field);
    final targetFocusNode = res.focusNodeFor(field);

    final isWeight = _isWeightItem(line);
    final initialValue = switch (field) {
      _DraftEditableField.quantity =>
        isWeight ? _kgEditableText(line.qtyGrams) : line.qtyGrams.toInt().toString(),
      _DraftEditableField.price => _lineUnitPrice(line).toStringAsFixed(2),
      _DraftEditableField.amount => line.amount.toStringAsFixed(2),
    };

    targetController.value = TextEditingValue(
      text: initialValue,
      selection: TextSelection(
        baseOffset: 0,
        extentOffset: initialValue.length,
      ),
    );

    setState(() {
      _selectedRowIndex = index;
      _editingLineKey = lineKey;
      _editingField = field;
      _weightSuggestionAccepted = false;
    });

    targetFocusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      targetFocusNode.requestFocus();
      targetController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: targetController.text.length,
      );
    });
  }

  Future<bool> _commitInlineEdit({bool clearStateOnSuccess = true}) async {
    if (_isCommittingInlineEdit) return false;
    _isCommittingInlineEdit = true;

    try {
      final editingLineKey = _editingLineKey;
      final editingField = _editingField;
      if (editingLineKey == null || editingField == null) {
        if (clearStateOnSuccess) _clearInlineEditState();
        return true;
      }
      final res = _lineResources[editingLineKey];
      final controller = res?.controllerFor(editingField);
      final editingIndex = ref.read(billingControllerProvider).billLines.indexWhere(
        (l) => l.draftKey == editingLineKey,
      );

      if (controller == null ||
          editingIndex < 0 ||
          editingIndex >= ref.read(billingControllerProvider).billLines.length) {
        if (clearStateOnSuccess) _clearInlineEditState();
        return true;
      }

      final line = ref.read(billingControllerProvider).billLines[editingIndex];
      final raw = controller.text.trim();
      final isWeight = _isWeightItem(line);

      BillLineItem updatedLine = line;
      if (editingField == _DraftEditableField.quantity) {
        if (isWeight) {
          final newQtyGrams = WeightCalculator.parseWeightInputGrams(
            raw,
            suggestionAccepted: _weightSuggestionAccepted,
          );
          if (raw.isEmpty || newQtyGrams <= 0) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('વજન શૂન્ય ન હોઈ શકે')));
            setState(_clearInlineEditState);
            return false;
          }
          final itemId = line.item.id;
          if (itemId != null) {
            final hasStock = await widget.checkStock(
              itemId: itemId,
              newQtyGrams: newQtyGrams,
              excludeLineIndex: editingIndex,
            );
            if (!mounted) return false;
            if (!hasStock) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'સ્ટોક અવેલેબલ નથી કૃપા કરી ખરીદી ની યાદી માં એડ કરો',
                  ),
                ),
              );
              setState(_clearInlineEditState);
              return false;
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
            return false;
          }

          final newQtyGrams = parsed.toDouble();
          final itemId = line.item.id;
          if (itemId != null) {
            final hasStock = await widget.checkStock(
              itemId: itemId,
              newQtyGrams: newQtyGrams,
              excludeLineIndex: editingIndex,
            );
            if (!mounted) return false;
            if (!hasStock) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'સ્ટોક અવેલેબલ નથી કૃપા કરી ખરીદી ની યાદી માં એડ કરો',
                  ),
                ),
              );
              setState(_clearInlineEditState);
              return false;
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
          return false;
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
          return false;
        }

        final unitPrice = _lineUnitPrice(line);
        if (unitPrice <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('કિંમત શૂન્ય ન હોઈ શકે')),
          );
          setState(_clearInlineEditState);
          return false;
        }

        final newQtyGrams = isWeight
            ? (parsed / unitPrice) * 1000.0
            : line.qtyGrams.roundToDouble().clamp(1.0, double.infinity);
        updatedLine = line.copyWith(qtyGrams: newQtyGrams, amount: parsed);
      }

      ref.read(billingControllerProvider.notifier).updateLine(editingIndex, updatedLine);
      if (clearStateOnSuccess) {
        setState(() {
          _clearInlineEditState();
        });
      }
      return true;
    } finally {
      _isCommittingInlineEdit = false;
    }
  }

  /// Move focus sequentially through fields:
  /// (Product 0: Qty -> Price -> Total) -> (Product 1: Qty -> Price -> Total) -> ...
  Future<void> _moveToNextInlineEditField({bool reverse = false}) async {
    final currentLineKey = _editingLineKey;
    final currentField = _editingField;
    if (currentLineKey == null || currentField == null) return;

    final lines = ref.read(billingControllerProvider).billLines;
    final currentIndex = lines.indexWhere((l) => l.draftKey == currentLineKey);
    if (currentIndex < 0) return;

    // Commit current edit without clearing state yet
    final success = await _commitInlineEdit(clearStateOnSuccess: false);
    if (!success || !mounted) return;

    final currentLines = ref.read(billingControllerProvider).billLines;
    if (currentLines.isEmpty) return;
    final safeIndex = currentIndex.clamp(0, currentLines.length - 1);

    int nextIndex = safeIndex;
    _DraftEditableField nextField;

    if (!reverse) {
      switch (currentField) {
        case _DraftEditableField.quantity:
          nextField = _DraftEditableField.price;
          break;
        case _DraftEditableField.price:
          nextField = _DraftEditableField.amount;
          break;
        case _DraftEditableField.amount:
          if (safeIndex + 1 < currentLines.length) {
            nextIndex = safeIndex + 1;
            nextField = _DraftEditableField.quantity;
          } else {
            // Last field of last item reached: complete editing cleanly
            setState(() {
              _clearInlineEditState();
            });
            return;
          }
          break;
      }
    } else {
      switch (currentField) {
        case _DraftEditableField.amount:
          nextField = _DraftEditableField.price;
          break;
        case _DraftEditableField.price:
          nextField = _DraftEditableField.quantity;
          break;
        case _DraftEditableField.quantity:
          if (safeIndex - 1 >= 0) {
            nextIndex = safeIndex - 1;
            nextField = _DraftEditableField.amount;
          } else {
            // Before first item
            setState(() {
              _clearInlineEditState();
            });
            return;
          }
          break;
      }
    }

    await _startInlineEdit(nextIndex, nextField, commitExisting: false);
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
      final newLines = ref.read(billingControllerProvider).billLines;
      if (newLines.isEmpty) {
        _selectedRowIndex = null;
      } else if (_selectedRowIndex != null && _selectedRowIndex! >= newLines.length) {
        _selectedRowIndex = newLines.length - 1;
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
            _getOrCreateLineResources(removedKey);
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
    String? tooltip,
    bool isWeight = false,
  }) {
    if (isEditing) {
      final text = controller?.text.trim() ?? '';
      final showSuggestion = isWeight && (text == '0.5' || text == '.5');

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 106,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              keyboardType: keyboardType,
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (isWeight) {
                  setState(() {});
                }
              },
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
          ),
          if (showSuggestion) ...[
            const SizedBox(height: 3),
            InkWell(
              onTap: () {
                _weightSuggestionAccepted = true;
                controller?.text = '0.500';
                controller?.selection = const TextSelection.collapsed(offset: 5);
                setState(() {});
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF3B82F6), width: 1.2),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '500g',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                    SizedBox(width: 3),
                    Icon(Icons.arrow_forward, size: 12, color: Color(0xFF1D4ED8)),
                    SizedBox(width: 2),
                    Text(
                      '(→)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      );
    }

    final chip = InkWell(
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

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: chip);
    }
    return chip;
  }

  Widget _buildBillLineTile(BillLineItem line, int index) {
    final res = _getOrCreateLineResources(line.draftKey);

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

    final isSelectedRow = _selectedRowIndex == index;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() {
          _selectedRowIndex = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isEditingRow
              ? AppColors.surface
              : (isSelectedRow ? AppColors.primarySurface : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
          border: isSelectedRow
              ? Border.all(color: Theme.of(context).primaryColor, width: 1.5)
              : (isEditingRow
                  ? Border.all(color: AppColors.divider)
                  : Border.all(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            if (isSelectedRow)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.arrow_right,
                  color: Theme.of(context).primaryColor,
                  size: 22,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.item.nameGujarati,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight:
                          isSelectedRow ? FontWeight.w800 : FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildEditableValueChip(
                        isEditing: isEditingQty,
                        controller: res.qtyController,
                        focusNode: res.qtyFocusNode,
                        value: qtyDisplay,
                        tooltip: 'વજન / સંખ્યા બદલો',
                        isWeight: isWeight,
                        onTap: () => _startInlineEdit(
                            index, _DraftEditableField.quantity),
                        onSubmitted: (_) async {
                          final ok = await _commitInlineEdit(clearStateOnSuccess: false);
                          if (ok && mounted) {
                            _startInlineEdit(index, _DraftEditableField.price, commitExisting: false);
                          }
                        },
                        keyboardType: isWeight
                            ? const TextInputType.numberWithOptions(
                                decimal: true)
                            : TextInputType.number,
                        allowDecimal: isWeight,
                      ),
                      _buildEditableValueChip(
                        isEditing: isEditingPrice,
                        controller: res.priceController,
                        focusNode: res.priceFocusNode,
                        value: priceDisplay,
                        tooltip: 'કિંમત બદલો',
                        onTap: () =>
                            _startInlineEdit(index, _DraftEditableField.price),
                        onSubmitted: (_) async {
                          final ok = await _commitInlineEdit(clearStateOnSuccess: false);
                          if (ok && mounted) {
                            _startInlineEdit(index, _DraftEditableField.amount, commitExisting: false);
                          }
                        },
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        prefixText: isEditingPrice ? '₹' : null,
                      ),
                      _buildEditableValueChip(
                        isEditing: isEditingAmount,
                        controller: res.amountController,
                        focusNode: res.amountFocusNode,
                        value: formatCurrency(line.amount),
                        tooltip: 'કુલ રકમ બદલો',
                        onTap: () =>
                            _startInlineEdit(index, _DraftEditableField.amount),
                        onSubmitted: (_) async {
                          final ok = await _commitInlineEdit(clearStateOnSuccess: true);
                          if (ok && mounted) {
                            widget.onInlineEditCompleted?.call();
                          }
                        },
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isSelectedRow && !isEditingRow) ...[
              SizedBox(
                width: 32,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 32, height: 32),
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.blueGrey,
                    size: 20,
                  ),
                  tooltip: 'જથ્થો ઘટાડો (-)',
                  onPressed: () => decrementSelectedRowQty(),
                ),
              ),
              SizedBox(
                width: 32,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 32, height: 32),
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                  tooltip: 'જથ્થો વધારો (+)',
                  onPressed: () => incrementSelectedRowQty(),
                ),
              ),
            ],
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
                  tooltip: 'સાચવો',
                  onPressed: () {
                    _commitInlineEdit();
                  },
                ),
              ),
            SizedBox(
              width: 36,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 36, height: 36),
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                tooltip: 'કાઢી નાખો',
                onPressed: () async {
                  await _deleteLineWithUndo(index);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final billLines = ref.watch(billingControllerProvider).billLines;
    if (_selectedRowIndex != null && _selectedRowIndex! >= billLines.length) {
      _selectedRowIndex = billLines.isEmpty ? null : billLines.length - 1;
    }

    if (billLines.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_cart_outlined,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'બિલ ખાલી છે',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'ડાબી બાજુથી ઉત્પાદન પસંદ કરો',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: billLines.length,
      itemBuilder: (ctx, i) {
        final line = billLines[i];
        return _buildBillLineTile(line, i);
      },
    );
  }
}
