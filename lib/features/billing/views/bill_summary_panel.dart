import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_format.dart';
import '../billing_providers.dart';
import '../controllers/billing_controller.dart';

class BillSummaryPanel extends ConsumerStatefulWidget {
  final VoidCallback onClearBill;
  final VoidCallback? onSaveBill;
  final VoidCallback? onPrintBill;
  final VoidCallback? onSaveAndPrintBill;

  const BillSummaryPanel({
    super.key,
    required this.onClearBill,
    this.onSaveBill,
    this.onPrintBill,
    this.onSaveAndPrintBill,
  });

  @override
  ConsumerState<BillSummaryPanel> createState() => BillSummaryPanelState();
}

class BillSummaryPanelState extends ConsumerState<BillSummaryPanel> {
  final _grandTotalEditController = TextEditingController();
  final _grandTotalEditFocusNode = FocusNode();
  final _discountEditController = TextEditingController();
  final _discountEditFocusNode = FocusNode();
  bool _isEditingDiscount = false;

  @override
  void initState() {
    super.initState();
    _discountEditFocusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          setState(() {
            _isEditingDiscount = false;
          });
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          _commitDiscountEdit();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    _grandTotalEditFocusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          ref.read(billingControllerProvider.notifier).cancelGrandTotalEdit();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          _commitGrandTotalEdit();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
  }

  @override
  void dispose() {
    _grandTotalEditController.dispose();
    _grandTotalEditFocusNode.dispose();
    _discountEditController.dispose();
    _discountEditFocusNode.dispose();
    super.dispose();
  }

  /// Shortcut action: edit discount amount in billing (Ctrl + D)
  void startDiscountEdit() {
    _startDiscountEdit();
  }

  /// Shortcut action: edit final total in bill (Ctrl + G)
  void startGrandTotalEdit() {
    _startGrandTotalEdit();
  }

  /// Commits any currently active discount or grand total text edit
  void commitActiveEdits() {
    if (_isEditingDiscount) {
      _commitDiscountEdit();
    }
    if (ref.read(billingControllerProvider).isEditingGrandTotal) {
      _commitGrandTotalEdit();
    }
  }

  void _startGrandTotalEdit() {
    final state = ref.read(billingControllerProvider);
    _grandTotalEditController.text = state.total.toStringAsFixed(2);
    ref.read(billingControllerProvider.notifier).startGrandTotalEdit();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _grandTotalEditFocusNode.requestFocus();
      _grandTotalEditController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _grandTotalEditController.text.length,
      );
    });
  }

  void _commitGrandTotalEdit() {
    final text = _grandTotalEditController.text.trim();
    final val = double.tryParse(text);
    if (val != null) {
      ref.read(billingControllerProvider.notifier).commitGrandTotalEdit(val);
    } else {
      ref.read(billingControllerProvider.notifier).cancelGrandTotalEdit();
    }
  }

  void _startDiscountEdit() {
    final state = ref.read(billingControllerProvider);
    _discountEditController.text = state.discount > 0
        ? state.discount.toStringAsFixed(2)
        : '';
    setState(() {
      _isEditingDiscount = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _discountEditFocusNode.requestFocus();
      _discountEditController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _discountEditController.text.length,
      );
    });
  }

  void _commitDiscountEdit() {
    final text = _discountEditController.text.trim();
    final val = double.tryParse(text) ?? 0.0;
    ref.read(billingControllerProvider.notifier).setDiscount(
          val.clamp(0.0, double.infinity),
        );
    setState(() {
      _isEditingDiscount = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(billingControllerProvider);
    final subtotal = state.subtotal;
    final discount = state.discount;
    final otherCharges = state.otherCharges;
    final total = state.total;
    final isEditingGrandTotal = state.isEditingGrandTotal;
    final isGrandTotalAdjusted = state.isGrandTotalAdjusted;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('કુલ:'),
              Text(
                formatCurrency(subtotal),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ડિસ્કાઉન્ટ:'),
              if (_isEditingDiscount)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 130,
                      child: TextField(
                        controller: _discountEditController,
                        focusNode: _discountEditFocusNode,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        onSubmitted: (_) => _commitDiscountEdit(),
                        onTapOutside: (_) => _commitDiscountEdit(),
                        decoration: const InputDecoration(
                          isDense: true,
                          prefixText: '₹',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      tooltip: 'કન્ફર્મ કરો (Enter)',
                      onPressed: _commitDiscountEdit,
                    ),
                  ],
                )
              else
                Tooltip(
                  message: 'ડિસ્કાઉન્ટ બદલો (Ctrl+D)',
                  child: InkWell(
                    onTap: _startDiscountEdit,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '-${formatCurrency(discount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (otherCharges > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'અન્ય ચાર્જ:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.blueGrey.shade800,
                  ),
                ),
                Text(
                  '+${formatCurrency(otherCharges)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blueGrey.shade900,
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'દેય:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isGrandTotalAdjusted)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        'સુધારેલ કુલ',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (isEditingGrandTotal)
                    SizedBox(
                      width: 130,
                      child: TextField(
                        controller: _grandTotalEditController,
                        focusNode: _grandTotalEditFocusNode,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        onSubmitted: (_) => _commitGrandTotalEdit(),
                        onTapOutside: (_) => _commitGrandTotalEdit(),
                        decoration: const InputDecoration(
                          isDense: true,
                          prefixText: '₹',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                      ),
                    )
                  else
                    Tooltip(
                      message: 'કુલ રકમ બદલો (Ctrl+G)',
                      child: InkWell(
                        onTap: _startGrandTotalEdit,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            formatCurrency(total),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Colors.green.shade700,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (isEditingGrandTotal)
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      tooltip: 'કન્ફર્મ કરો (Enter)',
                      onPressed: _commitGrandTotalEdit,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ── Payment Mode Chips ──
          Consumer(
            builder: (context, ref, _) {
              final activeDraft = ref.watch(billingTabsProvider).activeDraft;
              final currentMode = activeDraft.transactionType;
              return Row(
                children: [
                  const Text(
                    'ચૂકવણી:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  _buildPaymentChip(
                    label: '💵 કેશ (Alt+2)',
                    isSelected: currentMode == 'cash',
                    onTap: () {
                      ref
                          .read(billingTabsProvider.notifier)
                          .setTransactionTypeForActive('cash');
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildPaymentChip(
                    label: '📒 ઉધાર (Alt+1)',
                    isSelected: currentMode == 'khata',
                    onTap: () {
                      ref
                          .read(billingTabsProvider.notifier)
                          .setTransactionTypeForActive('khata');
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildPaymentChip(
                    label: '📱 ઓનલાઇન',
                    isSelected: currentMode == 'online',
                    onTap: () {
                      ref
                          .read(billingTabsProvider.notifier)
                          .setTransactionTypeForActive('online');
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          // ── Action Buttons ──
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text(
                    'સાચવો & પ્રિન્ટ (Ctrl+Enter)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: state.billLines.isEmpty
                      ? null
                      : () {
                          if (widget.onSaveAndPrintBill != null) {
                            widget.onSaveAndPrintBill!();
                          } else if (widget.onPrintBill != null) {
                            widget.onPrintBill!();
                          }
                        },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.save, size: 17),
                  label: const Text('સાચવો (Ctrl+S)', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: state.billLines.isEmpty ? null : widget.onSaveBill,
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red.shade200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: state.billLines.isEmpty
                    ? null
                    : () {
                        ref.read(billingControllerProvider.notifier).clearBill();
                        widget.onClearBill();
                      },
                child: const Text('સાફ (Ctrl+C)', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade800,
          ),
        ),
      ),
    );
  }
}
