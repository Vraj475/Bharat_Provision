import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../utils/pin_utils.dart';

/// PIN verification screen used for sensitive operations.
class PinVerificationScreen extends ConsumerStatefulWidget {
  final String title;
  final ValueChanged<bool> onVerified;
  final String? targetRole;

  const PinVerificationScreen({
    required this.title,
    required this.onVerified,
    this.targetRole,
    super.key,
  });

  @override
  ConsumerState<PinVerificationScreen> createState() =>
      _PinVerificationScreenState();
}

class _PinVerificationScreenState extends ConsumerState<PinVerificationScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isSubmitting = false;
  bool _submitted = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _verifyPin() async {
    final session = ref.read(authSessionProvider);
    if (session == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No active session found.')));
      return;
    }

    final pin = _pinController.text.trim();
    setState(() {
      _submitted = true;
      _errorMessage = null;
    });

    if (!PinUtils.isValidPin(pin)) {
      setState(() {
        _errorMessage = 'PIN must be exactly 4 digits.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final role = widget.targetRole ?? session.role;
      final pinStorage = ref.read(pinStorageProvider);
      final isValid = await pinStorage.verifyPin(role, pin);

      if (!mounted) return;
      if (!isValid) {
        setState(() {
          _errorMessage = 'Incorrect PIN.';
          _isSubmitting = false;
        });
        return;
      }

      widget.onVerified(true);
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'PIN verification failed. Please try again.';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text(widget.title), centerTitle: true),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Re-enter PIN to continue',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            _PinTextField(
                              controller: _pinController,
                              focusNode: _focusNode,
                              label: 'PIN',
                              hintText: '4-digit PIN',
                              submitted: _submitted,
                            ),
                            if (_submitted && _errorMessage != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _verifyPin,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Verify'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Change PIN screen
class ChangePinScreen extends ConsumerStatefulWidget {
  final String forRole; // own, employee, admin

  const ChangePinScreen({required this.forRole, super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  final TextEditingController _oldPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  bool _submitted = false;
  bool _isSaving = false;
  String? _errorMessage;

  String? _targetRole() {
    final session = ref.read(authSessionProvider);
    if (session == null) return null;
    return widget.forRole == 'own' ? session.role : widget.forRole;
  }

  @override
  void dispose() {
    _oldPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _changePin() async {
    final role = _targetRole();
    if (role == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active session. Please login again.')),
      );
      return;
    }

    final oldPin = _oldPinController.text.trim();
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    setState(() {
      _submitted = true;
      _errorMessage = null;
    });

    if (!PinUtils.isValidPin(oldPin)) {
      setState(() {
        _errorMessage = 'Old PIN must be 4 digits.';
      });
      return;
    }
    if (!PinUtils.isValidPin(newPin)) {
      setState(() {
        _errorMessage = 'New PIN must be 4 digits.';
      });
      return;
    }
    if (newPin != confirmPin) {
      setState(() {
        _errorMessage = 'New PIN and confirm PIN do not match.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final pinStorage = ref.read(pinStorageProvider);
      final oldPinValid = await pinStorage.verifyPin(role, oldPin);

      if (!oldPinValid) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Old PIN is incorrect.';
          _isSaving = false;
        });
        return;
      }

      await pinStorage.setPinHash(role, newPin);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN changed successfully.')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to change PIN right now. Please try again.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          widget.forRole == 'own'
              ? 'Change PIN'
              : 'Change ${widget.forRole} PIN',
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Update PIN',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enter old PIN and set a new 4-digit PIN.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 18),
                            _PinTextField(
                              controller: _oldPinController,
                              label: 'Old PIN',
                              hintText: 'Current 4-digit PIN',
                              submitted: _submitted,
                            ),
                            const SizedBox(height: 12),
                            _PinTextField(
                              controller: _newPinController,
                              label: 'New PIN',
                              hintText: 'New 4-digit PIN',
                              submitted: _submitted,
                            ),
                            const SizedBox(height: 12),
                            _PinTextField(
                              controller: _confirmPinController,
                              label: 'Confirm New PIN',
                              hintText: 'Re-enter new PIN',
                              submitted: _submitted,
                            ),
                            if (_submitted && _errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: 18),
                            ElevatedButton(
                              onPressed: _isSaving ? null : _changePin,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Save PIN'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PinTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String hintText;
  final bool submitted;

  const _PinTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.submitted,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final value = controller.text.trim();

    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      obscureText: true,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(PinUtils.pinLength),
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        errorText: submitted && value.length != PinUtils.pinLength
            ? 'Must be 4 digits'
            : null,
      ),
    );
  }
}
