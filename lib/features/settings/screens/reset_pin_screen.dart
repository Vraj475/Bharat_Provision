import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/enhanced_pin_entry.dart';
import '../providers/auth_provider.dart';

class ResetPinScreen extends ConsumerStatefulWidget {
  final String role;
  final VoidCallback onResetComplete;

  const ResetPinScreen({
    required this.role,
    required this.onResetComplete,
    super.key,
  });

  @override
  ConsumerState<ResetPinScreen> createState() => _ResetPinScreenState();
}

class _ResetPinScreenState extends ConsumerState<ResetPinScreen> {
  String _newPin = '';
  String _confirmPin = '';
  bool _isConfirmingPin = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  int get _expectedPinLength {
    switch (widget.role) {
      case 'superadmin':
        return 6;
      default:
        return 4; // 4-6 for others, default to 4
    }
  }

  Future<void> _submitNewPin() async {
    if (_newPin != _confirmPin) {
      setState(() {
        _errorMessage = 'PINs do not match. Please try again.';
        _isConfirmingPin = false;
        _newPin = '';
        _confirmPin = '';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // Save the new PIN
      final pinStorage = ref.read(pinStorageProvider);
      await pinStorage.setPinHash(widget.role, _newPin);

      setState(() {
        _isSubmitting = false;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'PIN reset successfully! Redirecting to login...',
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
          ),
        );

        // Delay and navigate
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            widget.onResetComplete();
          }
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error resetting PIN: $e';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Set New PIN'),
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              !_isConfirmingPin ? 'Create New PIN' : 'Confirm PIN',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              !_isConfirmingPin
                  ? 'Enter a $_expectedPinLength-digit PIN for your account'
                  : 'Re-enter your PIN to confirm',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),

            // PIN Entry Widget
            if (!_isConfirmingPin)
              EnhancedPinEntry(
                pinLength: _expectedPinLength,
                onPinChanged: (pin) {
                  setState(() {
                    _newPin = pin;
                  });
                },
                onSubmit: _newPin.length == _expectedPinLength
                    ? () {
                        setState(() {
                          _isConfirmingPin = true;
                        });
                      }
                    : () {},
                isLoading: _isSubmitting,
                errorMessage: _errorMessage,
              )
            else
              EnhancedPinEntry(
                pinLength: _expectedPinLength,
                onPinChanged: (pin) {
                  setState(() {
                    _confirmPin = pin;
                  });
                },
                onSubmit: _confirmPin.length == _expectedPinLength
                    ? _submitNewPin
                    : () {},
                isLoading: _isSubmitting,
                errorMessage: _errorMessage,
              ),

            const SizedBox(height: 24),

            // Back button if confirming
            if (_isConfirmingPin)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton.icon(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          setState(() {
                            _isConfirmingPin = false;
                            _errorMessage = null;
                          });
                        },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to New PIN'),
                ),
              ),

            const SizedBox(height: 12),

            // PIN Requirements
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PIN Requirements',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildRequirement(
                    'Must be $_expectedPinLength digits',
                    _newPin.length == _expectedPinLength && !_isConfirmingPin,
                  ),
                  const SizedBox(height: 4),
                  _buildRequirement(
                    'Numbers only (0-9)',
                    _newPin.isNotEmpty &&
                        _newPin.length <= _expectedPinLength &&
                        !_isConfirmingPin,
                  ),
                  if (_isConfirmingPin) ...[
                    const SizedBox(height: 4),
                    _buildRequirement(
                      'PINs match',
                      _newPin == _confirmPin && _newPin.isNotEmpty,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirement(String text, bool isMet) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: isMet ? Colors.green.shade600 : Colors.grey.shade400,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: isMet ? Colors.green.shade700 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
