import 'package:flutter/material.dart';

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
      text: widget.initialDiscount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = double.tryParse(_controller.text) ?? 0.0;
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ડિસ્કાઉન્ટ દાખલ કરો'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'ડિસ્કાઉન્ટ રકમ (₹)',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('રદ કરો'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('લાગુ કરો'),
        ),
      ],
    );
  }
}
