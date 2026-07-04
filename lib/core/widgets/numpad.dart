import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Numpad-only numeric input widget. Use with [NumpadController] or
/// [FocusNode] + [TextEditingController] where keyboard should be disabled.
class NumpadWidget extends StatelessWidget {
  const NumpadWidget({
    super.key,
    required this.controller,
    this.onSubmit,
    this.allowDecimal = true,
    this.maxLength,
    this.label,
  });

  final TextEditingController controller;
  final VoidCallback? onSubmit;
  final bool allowDecimal;
  final int? maxLength;
  final String? label;

  void _append(String char) {
    var text = controller.text;
    if (maxLength != null && text.replaceAll('.', '').length >= maxLength!) {
      return;
    }
    if (char == '.' && (!allowDecimal || text.contains('.'))) return;
    if (char == '0' && text == '0' && !text.contains('.')) return;
    if (char != '.' && text == '0' && !text.contains('.')) {
      text = char;
    } else {
      text = text + char;
    }
    controller.text = text;
    controller.selection = TextSelection.collapsed(offset: text.length);
  }

  void _backspace() {
    final text = controller.text;
    if (text.isEmpty) return;
    controller.text = text.substring(0, text.length - 1);
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
  }

  void _clear() {
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(label!, style: Theme.of(context).textTheme.titleSmall),
          ),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _NumpadGrid(
                onDigit: _append,
                onBackspace: _backspace,
                onClear: _clear,
                allowDecimal: allowDecimal,
              ),
            ),
            if (onSubmit != null)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: SizedBox(
                    height: 200,
                    child: ElevatedButton(
                      onPressed: onSubmit,
                      child: const Icon(Icons.check, size: 32),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _NumpadGrid extends StatelessWidget {
  const _NumpadGrid({
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    required this.allowDecimal,
  });

  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final bool allowDecimal;

  @override
  Widget build(BuildContext context) {
    const double btnHeight = 48;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _NumBtn(label: '7', onTap: () => onDigit('7'), height: btnHeight),
            _NumBtn(label: '8', onTap: () => onDigit('8'), height: btnHeight),
            _NumBtn(label: '9', onTap: () => onDigit('9'), height: btnHeight),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _NumBtn(label: '4', onTap: () => onDigit('4'), height: btnHeight),
            _NumBtn(label: '5', onTap: () => onDigit('5'), height: btnHeight),
            _NumBtn(label: '6', onTap: () => onDigit('6'), height: btnHeight),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _NumBtn(label: '1', onTap: () => onDigit('1'), height: btnHeight),
            _NumBtn(label: '2', onTap: () => onDigit('2'), height: btnHeight),
            _NumBtn(label: '3', onTap: () => onDigit('3'), height: btnHeight),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (allowDecimal)
              _NumBtn(label: '.', onTap: () => onDigit('.'), height: btnHeight)
            else
              const SizedBox(width: 56, height: btnHeight),
            _NumBtn(label: '0', onTap: () => onDigit('0'), height: btnHeight),
            _NumBtn(
              label: '⌫',
              onTap: onBackspace,
              height: btnHeight,
              isAction: true,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(onPressed: onClear, child: const Text('C')),
        ),
      ],
    );
  }
}

class _NumBtn extends StatelessWidget {
  const _NumBtn({
    required this.label,
    required this.onTap,
    required this.height,
    this.isAction = false,
  });

  final String label;
  final VoidCallback onTap;
  final double height;
  final bool isAction;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SizedBox(
          height: height,
          child: Material(
            color: isAction
                ? Theme.of(context).colorScheme.secondaryContainer
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Center(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a [TextField] to disable system keyboard and show [NumpadWidget].
class NumpadTextField extends StatefulWidget {
  const NumpadTextField({
    super.key,
    required this.controller,
    this.decoration,
    this.readOnly = true,
    this.allowDecimal = true,
    this.maxLength,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final InputDecoration? decoration;
  final bool readOnly;
  final bool allowDecimal;
  final int? maxLength;
  final VoidCallback? onSubmitted;

  @override
  State<NumpadTextField> createState() => _NumpadTextFieldState();
}

class _NumpadTextFieldState extends State<NumpadTextField> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardDismisser(
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        readOnly: widget.readOnly,
        keyboardType: TextInputType.none,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
        decoration: widget.decoration,
        onSubmitted: (_) => widget.onSubmitted?.call(),
      ),
    );
  }
}

/// Prevents keyboard from showing when child is focused
class KeyboardDismisser extends StatelessWidget {
  const KeyboardDismisser({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: child,
    );
  }
}
