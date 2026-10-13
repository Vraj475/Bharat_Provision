import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class GrandTotalDialog extends StatefulWidget {
  final double currentTotal;

  const GrandTotalDialog({
    super.key,
    required this.currentTotal,
  });

  static Future<double?> show(BuildContext context, double currentTotal) {
    return showDialog<double>(
      context: context,
      builder: (ctx) => GrandTotalDialog(currentTotal: currentTotal),
    );
  }

  @override
  State<GrandTotalDialog> createState() => _GrandTotalDialogState();
}

class _GrandTotalDialogState extends State<GrandTotalDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentTotal.toStringAsFixed(2),
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
    final parsed = double.tryParse(_controller.text.trim());
    if (parsed != null) {
      context.pop(parsed);
    } else {
      context.pop(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('કુલ રકમ બદલો'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
        decoration: const InputDecoration(
          prefixText: '₹ ',
          labelText: 'અંતિમ કુલ રકમ (Final Total)',
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
