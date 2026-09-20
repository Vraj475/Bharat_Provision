import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/role_provider.dart';
import '../../../core/theme/role_theme.dart';

/// PIN numpad widget - displays number buttons for PIN entry with haptic feedback
class PinNumpad extends ConsumerStatefulWidget {
  final Function(String) onPinChanged;
  final int maxLength;
  final bool showDots;
  final bool isShaking;
  final String? role; // Override role color

  const PinNumpad({
    required this.onPinChanged,
    this.maxLength = 6,
    this.showDots = true,
    this.isShaking = false,
    this.role,
    super.key,
  });

  @override
  ConsumerState<PinNumpad> createState() => _PinNumpadState();
}

class _PinNumpadState extends ConsumerState<PinNumpad>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  String _pin = '';
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _focusNode.requestFocus();
  }

  @override
  void didUpdateWidget(PinNumpad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isShaking && !oldWidget.isShaking) {
      _animateShake();
    }
  }

  void _animateShake() {
    _shakeController.forward(from: 0);
  }

  void _addDigit(String digit) {
    if (_pin.length < widget.maxLength) {
      // Haptic feedback on press
      HapticFeedback.mediumImpact();

      _pin += digit;
      widget.onPinChanged(_pin);

      // Auto-submit if max length reached
      if (_pin.length == widget.maxLength) {
        // Small delay for feedback
        Future.delayed(const Duration(milliseconds: 100), () {
          HapticFeedback.heavyImpact();
        });
      }
    } else {
      // Haptic feedback for rejected input
      HapticFeedback.lightImpact();
    }
  }

  void _removeDigit() {
    if (_pin.isNotEmpty) {
      HapticFeedback.lightImpact();
      _pin = _pin.substring(0, _pin.length - 1);
      widget.onPinChanged(_pin);
    }
  }

  void _clear() {
    if (_pin.isNotEmpty) {
      HapticFeedback.lightImpact();
      _pin = '';
      widget.onPinChanged(_pin);
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.backspace) {
        _removeDigit();
      } else if (key == LogicalKeyboardKey.delete) {
        _clear();
      } else if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.space) {
        // Space/Enter could be used for submission in PIN entry context
        return;
      } else {
        final keyLabel = key.keyLabel;
        if (keyLabel.length == 1) {
          final digit = int.tryParse(keyLabel);
          if (digit != null) {
            _addDigit(keyLabel);
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.role ?? ref.watch(currentRoleProvider);
    final buttonColor = RoleThemeColors.colorForRole(role ?? 'employee');

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: AnimatedBuilder(
        animation: _shakeController,
        builder: (context, child) {
          final offset = Offset(_shakeOffset(_shakeController.value), 0);
          return Transform.translate(offset: offset, child: child);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              // PIN display (dots)
              if (widget.showDots)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.maxLength, (index) {
                      return Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey[400]!,
                            width: 2,
                          ),
                          color: index < _pin.length
                              ? buttonColor
                              : Colors.transparent,
                        ),
                      );
                    }),
                  ),
                ),
              // Number grid
              Column(
                children: [
                  // Row 1: 1 2 3
                  _buildNumpadRow(['1', '2', '3'], buttonColor),
                  const SizedBox(height: 12),
                  // Row 2: 4 5 6
                  _buildNumpadRow(['4', '5', '6'], buttonColor),
                  const SizedBox(height: 12),
                  // Row 3: 7 8 9
                  _buildNumpadRow(['7', '8', '9'], buttonColor),
                  const SizedBox(height: 12),
                  // Row 4: 0 + backspace/clear
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SizedBox(width: 72),
                      _buildNumpadButton(
                        '0',
                        () => _addDigit('0'),
                        buttonColor,
                      ),
                      _buildActionButton(
                        icon: Icons.backspace,
                        label: 'Delete',
                        onPressed: _removeDigit,
                        color: Colors.red[600]!,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Clear button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.grey[300],
                      ),
                      onPressed: _clear,
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumpadRow(List<String> digits, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits
          .map(
            (digit) => _buildNumpadButton(digit, () => _addDigit(digit), color),
          )
          .toList(),
    );
  }

  Widget _buildNumpadButton(String digit, VoidCallback onPressed, Color color) {
    return SizedBox(
      width: 72,
      height: 72,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: const CircleBorder(),
          elevation: 4,
          padding: EdgeInsets.zero,
        ),
        onPressed: onPressed,
        child: Text(
          digit,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return SizedBox(
      width: 72,
      height: 72,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: const CircleBorder(),
          elevation: 4,
          padding: EdgeInsets.zero,
        ),
        onPressed: onPressed,
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}

// Helper function for shake animation
double _shakeOffset(double value) => math.sin(value * 4 * math.pi) * 10;
