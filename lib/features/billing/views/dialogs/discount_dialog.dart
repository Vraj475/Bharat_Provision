import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DiscountDialog extends StatefulWidget {
  final double initialDiscount;

  const DiscountDialog({
    super.key,
    required this.initialDiscount,
  });

  static Future<double?> show(BuildContext context, double currentDiscount) {
    return showDialog<double>(
      context: context,
      builder: (ctx) => DiscountDialog(initialDiscount: currentDiscount),
    );
  }

  @override
  State<DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<DiscountDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialDiscount > 0
          ? widget.initialDiscount.toStringAsFixed(2)
          : '',
    );
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = double.tryParse(_controller.text.trim()) ?? 0.0;
    context.pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ડિસ્કાઉન્ટ દાખલ કરો'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          prefixText: '₹ ',
          labelText: 'ડિસ્કાઉન્ટ રકમ',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(null),
          child: const Text('રદ કરો'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('લાગુ કરો (Enter)'),
        ),
      ],
    );
  }
}
