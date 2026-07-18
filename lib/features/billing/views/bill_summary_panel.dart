import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_format.dart';
import '../controllers/billing_controller.dart';
import 'dialogs/discount_dialog.dart';

class BillSummaryPanel extends ConsumerStatefulWidget {
  final VoidCallback onClearBill;

  const BillSummaryPanel({
    super.key,
    required this.onClearBill,
  });

  @override
  ConsumerState<BillSummaryPanel> createState() => _BillSummaryPanelState();
}

class _BillSummaryPanelState extends ConsumerState<BillSummaryPanel> {
  final _grandTotalEditController = TextEditingController();
  final _grandTotalEditFocusNode = FocusNode();

  @override
  void dispose() {
    _grandTotalEditController.dispose();
    _grandTotalEditFocusNode.dispose();
    super.dispose();
  }

  void _startGrandTotalEdit() {
    final state = ref.read(billingControllerProvider);
    _grandTotalEditController.text = state.total.toStringAsFixed(2);
    ref.read(billingControllerProvider.notifier).startGrandTotalEdit();
    _grandTotalEditFocusNode.requestFocus();
  }

  void _commitGrandTotalEdit() {
    final val = double.tryParse(_grandTotalEditController.text);
    if (val != null) {
      ref.read(billingControllerProvider.notifier).commitGrandTotalEdit(val);
    }
  }

  void _setDiscount(BuildContext context) async {
    final state = ref.read(billingControllerProvider);
    final newDiscount = await DiscountDialog.show(context, state.discount);
    if (newDiscount != null) {
      ref.read(billingControllerProvider.notifier).setDiscount(newDiscount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(billingControllerProvider);
    final subtotal = state.subtotal;
    final discount = state.discount;
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
              GestureDetector(
                onTap: () => _setDiscount(context),
                child: const Text(
                  'ડિસ્કાઉન્ટ:',
                  style: TextStyle(decoration: TextDecoration.underline),
                ),
              ),
              Text(
                '-${formatCurrency(discount)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
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
                    InkWell(
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
                  if (isEditingGrandTotal)
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: _commitGrandTotalEdit,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.clear),
            label: const Text('બિલ ક્લીયર કરો'),
            onPressed: state.billLines.isEmpty
                ? null
                : () {
                    ref.read(billingControllerProvider.notifier).clearBill();
                    widget.onClearBill();
                  },
          ),
        ],
      ),
    );
  }
}
