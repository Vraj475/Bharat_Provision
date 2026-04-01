import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Enhanced PIN Entry Widget with support for:
/// - On-screen numeric keypad (0-9, backspace, confirm)
/// - Hardware keyboard: number row (0-9)
/// - Hardware keyboard: numpad (0-9, +, -, *, /)
class EnhancedPinEntry extends StatefulWidget {
  final int pinLength;
  final ValueChanged<String> onPinChanged;
  final VoidCallback onSubmit;
  final bool isLoading;
  final String? errorMessage;

  const EnhancedPinEntry({
    required this.onPinChanged,
    required this.onSubmit,
    this.pinLength = 4,
    this.isLoading = false,
    this.errorMessage,
    super.key,
  });

  @override
  State<EnhancedPinEntry> createState() => _EnhancedPinEntryState();
}

class _EnhancedPinEntryState extends State<EnhancedPinEntry> {
  String _pin = '';
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    // Request focus to enable keyboard input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Handle keyboard events for both regular keyboard and numpad
  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final key = event.logicalKey;

      // Check for number keys (0-9) from main keyboard
      final numpadKeys = {
        LogicalKeyboardKey.digit0: '0',
        LogicalKeyboardKey.digit1: '1',
        LogicalKeyboardKey.digit2: '2',
        LogicalKeyboardKey.digit3: '3',
        LogicalKeyboardKey.digit4: '4',
        LogicalKeyboardKey.digit5: '5',
        LogicalKeyboardKey.digit6: '6',
        LogicalKeyboardKey.digit7: '7',
        LogicalKeyboardKey.digit8: '8',
        LogicalKeyboardKey.digit9: '9',
        // Numpad keys
        LogicalKeyboardKey.numpad0: '0',
        LogicalKeyboardKey.numpad1: '1',
        LogicalKeyboardKey.numpad2: '2',
        LogicalKeyboardKey.numpad3: '3',
        LogicalKeyboardKey.numpad4: '4',
        LogicalKeyboardKey.numpad5: '5',
        LogicalKeyboardKey.numpad6: '6',
        LogicalKeyboardKey.numpad7: '7',
        LogicalKeyboardKey.numpad8: '8',
        LogicalKeyboardKey.numpad9: '9',
      };

      if (numpadKeys.containsKey(key)) {
        _addDigit(numpadKeys[key]!);
      } else if (key == LogicalKeyboardKey.backspace) {
        _removeLastDigit();
      } else if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        if (_pin.length == widget.pinLength) {
          widget.onSubmit();
        }
      }
    }
  }

  void _addDigit(String digit) {
    if (_pin.length < widget.pinLength) {
      setState(() {
        _pin += digit;
      });
      widget.onPinChanged(_pin);
    }
  }

  void _removeLastDigit() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
      widget.onPinChanged(_pin);
    }
  }

  void _clear() {
    setState(() {
      _pin = '';
    });
    widget.onPinChanged(_pin);
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: _handleKeyEvent,
      child: Column(
        children: [
          // PIN Display with dots
          SizedBox(
            height: 80,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.pinLength, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: index < _pin.length
                                  ? Colors.blue.shade600
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                            color: index < _pin.length
                                ? Colors.blue.shade50
                                : Colors.transparent,
                          ),
                          child: Center(
                            child: index < _pin.length
                                ? Icon(
                                    Icons.circle,
                                    size: 20,
                                    color: Colors.blue.shade600,
                                  )
                                : const SizedBox(),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Error Message
          if (widget.errorMessage != null && widget.errorMessage!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),

          const SizedBox(height: 20),

          // Numeric Keypad
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Row 1: 1 2 3
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildKeypadButton('1'),
                    _buildKeypadButton('2'),
                    _buildKeypadButton('3'),
                  ],
                ),
                const SizedBox(height: 12),

                // Row 2: 4 5 6
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildKeypadButton('4'),
                    _buildKeypadButton('5'),
                    _buildKeypadButton('6'),
                  ],
                ),
                const SizedBox(height: 12),

                // Row 3: 7 8 9
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildKeypadButton('7'),
                    _buildKeypadButton('8'),
                    _buildKeypadButton('9'),
                  ],
                ),
                const SizedBox(height: 12),

                // Row 4: 0, Backspace, Clear
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SizedBox(width: 70, height: 70, child: SizedBox.shrink()),
                    _buildKeypadButton('0'),
                    SizedBox(
                      width: 70,
                      height: 70,
                      child: _buildActionButton(
                        icon: Icons.backspace,
                        onPressed: widget.isLoading ? null : _removeLastDigit,
                        label: 'Back',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Action buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 60,
                        child: ElevatedButton.icon(
                          onPressed: widget.isLoading ? null : _clear,
                          icon: const Icon(Icons.clear_all),
                          label: const Text('Clear'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade600,
                            disabledBackgroundColor: Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 60,
                        child: ElevatedButton.icon(
                          onPressed:
                              (_pin.length == widget.pinLength &&
                                  !widget.isLoading)
                              ? widget.onSubmit
                              : null,
                          icon: widget.isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: const Text('Submit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            disabledBackgroundColor: Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Keyboard hint
          Text(
            'Use keyboard number keys or on-screen keypad',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadButton(String label) {
    return SizedBox(
      width: 70,
      height: 70,
      child: ElevatedButton(
        onPressed: widget.isLoading ? null : () => _addDigit(label),
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.blue.shade100,
          disabledBackgroundColor: Colors.grey.shade300,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: widget.isLoading
                ? Colors.grey.shade500
                : Colors.blue.shade900,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback? onPressed,
    String? label,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.red.shade100,
        disabledBackgroundColor: Colors.grey.shade300,
      ),
      child: Icon(
        icon,
        size: 28,
        color: onPressed == null ? Colors.grey.shade500 : Colors.red.shade900,
      ),
    );
  }
}
