import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../settings_providers.dart';

class PinEntryScreen extends ConsumerStatefulWidget {
  final String role;
  final ValueChanged<String> onLoginSuccess;

  const PinEntryScreen({
    required this.role,
    required this.onLoginSuccess,
    super.key,
  });

  @override
  ConsumerState<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends ConsumerState<PinEntryScreen> {
  static const int _pinLength = 4;

  final TextEditingController _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = false;
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

  Future<void> _submit() async {
    final pin = _pinController.text.trim();
    setState(() {
      _submitted = true;
      _errorMessage = null;
    });

    if (pin.length != _pinLength) {
      setState(() {
        _errorMessage = 'Please enter a valid 4-digit PIN.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final isValid = await ref.read(
        validatePinProvider((widget.role, pin)).future,
      );

      if (!mounted) return;

      if (!isValid) {
        setState(() {
          _errorMessage = 'Incorrect PIN. Please try again.';
          _isLoading = false;
        });
        return;
      }

      final securitySettings = await ref.read(securitySettingsProvider.future);
      final sessionTimeoutMinutes =
          securitySettings['session_timeout_minutes'] as int? ?? 5;
      final requirePinOnOpen =
          securitySettings['require_pin_on_open'] as bool? ?? false;

      ref
          .read(authSessionProvider.notifier)
          .setSession(
            widget.role,
            timeoutMinutes: sessionTimeoutMinutes,
            requirePinOnOpen: requirePinOnOpen,
          );

      widget.onLoginSuccess(widget.role);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to verify PIN right now. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pin = _pinController.text;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Enter PIN'), centerTitle: true),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF2F7FF), Color(0xFFE6EEF9)],
          ),
        ),
        child: SafeArea(
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
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Icon(
                                Icons.lock_open_rounded,
                                size: 46,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Role: ${widget.role.toUpperCase()}',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Enter your 4-digit PIN',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 18),
                              GestureDetector(
                                onTap: () => _focusNode.requestFocus(),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(_pinLength, (index) {
                                    final hasDigit = index < pin.length;
                                    final isActive =
                                        index == pin.length &&
                                        pin.length < _pinLength;
                                    return Container(
                                      width: 52,
                                      height: 58,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isActive
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                              : Colors.blueGrey.shade200,
                                          width: isActive ? 2 : 1.2,
                                        ),
                                        color: hasDigit
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withValues(alpha: 0.12)
                                            : Colors.white,
                                      ),
                                      child: Center(
                                        child: Text(
                                          hasDigit ? '•' : '',
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                              Offstage(
                                offstage: true,
                                child: TextField(
                                  controller: _pinController,
                                  focusNode: _focusNode,
                                  autofocus: true,
                                  keyboardType: TextInputType.number,
                                  obscureText: true,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(
                                      _pinLength,
                                    ),
                                  ],
                                  onChanged: (_) {
                                    if (_submitted && _errorMessage != null) {
                                      setState(() {
                                        _errorMessage = null;
                                      });
                                    } else {
                                      setState(() {});
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(height: 18),
                              if (_submitted && _errorMessage != null) ...[
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              ElevatedButton.icon(
                                onPressed: _isLoading ? null : _submit,
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.login_rounded),
                                label: Text(
                                  _isLoading ? 'Verifying...' : 'Login',
                                ),
                                style: ElevatedButton.styleFrom(
                                  elevation: 3,
                                  minimumSize: const Size.fromHeight(50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                child: const Text('Back to role selection'),
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
      ),
    );
  }
}
