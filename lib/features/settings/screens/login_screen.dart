import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/security_questions_provider.dart';
import '../settings_providers.dart';
import '../widgets/pin_numpad.dart';
import '../models/security_question_models.dart';
import '../screens/forgot_pin_verification_screen.dart';
import '../screens/reset_pin_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final Function(String role) onLoginSuccess;

  const LoginScreen({required this.onLoginSuccess, super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  String? _selectedRole;
  String _enteredPin = '';
  String _errorMessage = '';
  bool _isShaking = false;
  late AnimationController _lockoutController;
  var _lockoutCountdown = 0;

  // Forgot PIN flow state
  bool _isInForgotPinFlow = false;
  bool _isLoadingForgotPin = false;
  String? _forgotPinRole;
  List<SecurityQuestion>? _forgotPinQuestions;
  bool _isInVerificationStep = false;
  bool _isInResetStep = false;

  @override
  void initState() {
    super.initState();
    _lockoutController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _lockoutController.dispose();
    super.dispose();
  }

  Future<void> _verifyPin() async {
    final attempt = ref.read(pinAttemptProvider);

    if (attempt.isLocked) {
      _showError(
        'Pin locked. Try again in ${attempt.remainingLockSeconds} seconds',
      );
      return;
    }

    if (_selectedRole == null || _enteredPin.isEmpty) {
      _showError('Please select role and enter PIN');
      return;
    }

    // Validate PIN length
    if (_selectedRole == 'superadmin' && _enteredPin.length != 6) {
      _showError('Superadmin PIN must be 6 digits');
      return;
    }
    if (_selectedRole != 'superadmin' &&
        (_enteredPin.length < 4 || _enteredPin.length > 6)) {
      _showError('PIN must be 4-6 digits');
      return;
    }

    // Verify PIN
    final isValid = await ref.read(
      validatePinProvider((_selectedRole!, _enteredPin)).future,
    );

    if (isValid) {
      // Reset attempts
      ref.read(pinAttemptProvider.notifier).reset();
      _clearPin();
      _errorMessage = '';

      // Read session settings
      final securitySettings = await ref.read(securitySettingsProvider.future);
      final sessionTimeoutMinutes =
          securitySettings['session_timeout_minutes'] as int;
      final requirePinOnOpen = securitySettings['require_pin_on_open'] as bool;

      // Set auth session
      ref
          .read(authSessionProvider.notifier)
          .setSession(
            _selectedRole!,
            timeoutMinutes: sessionTimeoutMinutes,
            requirePinOnOpen: requirePinOnOpen,
          );

      // Navigate
      widget.onLoginSuccess(_selectedRole!);
    } else {
      // Failed attempt
      ref.read(pinAttemptProvider.notifier).incrementFailure();
      final updatedAttempt = ref.read(pinAttemptProvider);

      if (updatedAttempt.isLocked) {
        _showError('Too many failed attempts. Locked for 30 seconds');
        _startLockoutCountdown(updatedAttempt.remainingLockSeconds);
      } else {
        _showError('Wrong PIN (Attempt ${updatedAttempt.failureCount}/3)');
        _triggerShakeAnimation();
      }
      _clearPin();
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
  }

  void _triggerShakeAnimation() {
    setState(() {
      _isShaking = true;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _isShaking = false;
      });
    });
  }

  void _startLockoutCountdown(int seconds) {
    _lockoutCountdown = seconds;
    _updateCountdown();
  }

  void _updateCountdown() {
    if (_lockoutCountdown > 0) {
      Future.delayed(const Duration(seconds: 1), () {
        setState(() {
          _lockoutCountdown--;
        });
        _updateCountdown();
      });
    }
  }

  void _clearPin() {
    setState(() {
      _enteredPin = '';
    });
  }

  void _selectRole(String role) {
    setState(() {
      _selectedRole = role;
      _enteredPin = '';
      _errorMessage = '';
    });
  }

  Future<void> _startForgotPinFlow() async {
    if (_selectedRole == null) {
      _showError('Please select a role first to recover PIN');
      return;
    }

    setState(() {
      _isLoadingForgotPin = true;
      _errorMessage = '';
    });

    try {
      final questions = await ref.read(
        forgotPinQuestionsByRoleProvider(_selectedRole!).future,
      );

      if (questions.isEmpty) {
        _showError(
          'No security questions found for this role. Configure security questions first.',
        );
        return;
      }

      setState(() {
        _forgotPinRole = _selectedRole;
        _forgotPinQuestions = questions;
        _isInForgotPinFlow = true;
        _isInVerificationStep = true;
        _isInResetStep = false;
      });
    } catch (_) {
      _showError('Unable to load security questions. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingForgotPin = false;
        });
      }
    }
  }

  void _exitForgotPinFlow() {
    setState(() {
      _isInForgotPinFlow = false;
      _forgotPinRole = null;
      _forgotPinQuestions = null;
      _isInVerificationStep = false;
      _isInResetStep = false;
    });
  }

  void _handleVerificationComplete(bool allCorrect) {
    if (allCorrect) {
      setState(() {
        _isInVerificationStep = false;
        _isInResetStep = true;
      });
    }
  }

  void _handleResetComplete() {
    _exitForgotPinFlow();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'PIN reset successfully! Please login with your new PIN.',
        ),
        backgroundColor: Colors.green.shade600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attempt = ref.watch(pinAttemptProvider);

    if (_isLoadingForgotPin) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Loading security questions...'),
            ],
          ),
        ),
      );
    }

    // Show forgot PIN flow
    if (_isInForgotPinFlow) {
      if (_isInVerificationStep && _forgotPinQuestions != null) {
        return ForgotPinVerificationScreen(
          role: _forgotPinRole ?? 'user',
          questions: _forgotPinQuestions!,
          onVerificationComplete: _handleVerificationComplete,
          onBackPressed: _exitForgotPinFlow,
        );
      } else if (_isInResetStep) {
        return ResetPinScreen(
          role: _forgotPinRole ?? 'user',
          onResetComplete: _handleResetComplete,
        );
      }
    }

    // Show normal login flow
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: _selectedRole != null
            ? _getRoleColor(_selectedRole!)
            : Colors.grey[700],
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Role selection
              if (_selectedRole == null) ...[
                const Text(
                  'Select Role',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),
                _buildRoleButton('🟣 Superadmin', 'superadmin', Colors.purple),
                const SizedBox(height: 16),
                _buildRoleButton('🔵 Admin', 'admin', Colors.blue),
                const SizedBox(height: 16),
                _buildRoleButton('🟢 Employee', 'employee', Colors.green),
              ] else ...[
                // PIN entry
                Text(
                  'Enter PIN for $_selectedRole',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                // Numpad
                PinNumpad(
                  onPinChanged: (pin) {
                    setState(() {
                      _enteredPin = pin;
                    });
                    if (pin.length == (_selectedRole == 'superadmin' ? 6 : 4)) {
                      Future.delayed(const Duration(milliseconds: 300), () {
                        _verifyPin();
                      });
                    }
                  },
                  maxLength: _selectedRole == 'superadmin' ? 6 : 6,
                  isShaking: _isShaking,
                ),
                const SizedBox(height: 24),
                // Error message
                if (_errorMessage.isNotEmpty)
                  Text(
                    _errorMessage,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                // Lockout countdown
                if (attempt.isLocked)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      'Locked. Try again in $_lockoutCountdown seconds',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                // Forgot PIN Button
                Center(
                  child: TextButton.icon(
                    onPressed: _startForgotPinFlow,
                    icon: const Icon(Icons.help_outline),
                    label: const Text('Forgot PIN?'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue.shade600,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Back button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[400],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedRole = null;
                        _enteredPin = '';
                        _errorMessage = '';
                      });
                      ref.read(pinAttemptProvider.notifier).reset();
                    },
                    child: const Text(
                      'Back to Role Selection',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleButton(String label, String role, Color color) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () => _selectRole(role),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'superadmin':
        return Colors.purple;
      case 'admin':
        return Colors.blue;
      case 'employee':
        return Colors.green;
      default:
        return Colors.grey[700]!;
    }
  }
}
