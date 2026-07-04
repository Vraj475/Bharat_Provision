import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/role_provider.dart';
import '../../../core/utils/app_data.dart';
import '../../../core/widgets/home_screen.dart';
import '../providers/auth_provider.dart';
import '../settings_providers.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  static const int _pinLength = 4;

  String? _selectedRole;
  String _pin = '';
  bool _showPinEntry = false;
  bool _isVerifying = false;
  bool _isNavigating = false;
  String? _errorMessage;

  late final TextEditingController _pinController;
  late final FocusNode _pinFocusNode;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
    _pinFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleRoleTap(String role) async {
    if (!mounted || _isNavigating || _isVerifying) {
      return;
    }

    setState(() {
      _selectedRole = role;
      _showPinEntry = true;
      _pin = '';
      _errorMessage = null;
    });
    _pinController.clear();

    // Persist role in background so UI transition feels immediate.
    _persistSelectedRole(role);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showPinEntry) {
        FocusScope.of(context).requestFocus(_pinFocusNode);
      }
    });

    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (mounted && _showPinEntry) {
        FocusScope.of(context).requestFocus(_pinFocusNode);
      }
    });
  }

  Future<void> _persistSelectedRole(String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('role', role);
    } catch (_) {}
  }

  void _onPinChanged(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
    final trimmed = digitsOnly.length > _pinLength
        ? digitsOnly.substring(0, _pinLength)
        : digitsOnly;

    if (trimmed != _pinController.text) {
      _pinController.value = TextEditingValue(
        text: trimmed,
        selection: TextSelection.collapsed(offset: trimmed.length),
      );
    }

    setState(() {
      _pin = trimmed;
      if (_errorMessage != null) {
        _errorMessage = null;
      }
    });

    if (trimmed.length == _pinLength && !_isVerifying) {
      Future.microtask(() {
        if (mounted &&
            _showPinEntry &&
            !_isVerifying &&
            _pin.length == _pinLength) {
          _submitPin();
        }
      });
    }
  }

  void _backToRoleSelection() {
    setState(() {
      _showPinEntry = false;
      _pin = '';
      _errorMessage = null;
    });
    _pinController.clear();
    _pinFocusNode.unfocus();
  }

  Future<void> _submitPin() async {
    if (_selectedRole == null || _pin.length != _pinLength || _isVerifying) {
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedPin = prefs.getString('user_pin') ?? '0000';
      final enteredPin = _pin.trim();

      final isValid = enteredPin == storedPin;
      if (!mounted) return;

      if (!isValid) {
        setState(() {
          _errorMessage = 'Incorrect PIN. Please try again.';
          _isVerifying = false;
        });
        FocusScope.of(context).requestFocus(_pinFocusNode);
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
            _selectedRole!,
            timeoutMinutes: sessionTimeoutMinutes,
            requirePinOnOpen: requirePinOnOpen,
          );
      ref.read(currentRoleProvider.notifier).state = _selectedRole!;

      if (_isNavigating) return;
      _isNavigating = true;

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to verify PIN right now. Please try again.';
        _isVerifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_showPinEntry,
      onPopInvokedWithResult: (didPop, result) {
        if (_showPinEntry) {
          _backToRoleSelection();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF64B5F6)],
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
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: Card(
                          elevation: 12,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 6),
                                Icon(
                                  Icons.storefront_rounded,
                                  size: 56,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(height: 12),
                                FutureBuilder<String>(
                                  future: AppData.getShopName(),
                                  builder: (context, snapshot) {
                                    return Text(
                                      snapshot.data ?? 'My Shop',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  switchInCurve: Curves.easeOut,
                                  switchOutCurve: Curves.easeIn,
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SizeTransition(
                                        sizeFactor: animation,
                                        axisAlignment: -1,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _showPinEntry
                                      ? _buildPinEntryView(context)
                                      : _buildRoleSelectionView(context),
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
      ),
    );
  }

  Widget _buildRoleSelectionView(BuildContext context) {
    return Column(
      key: const ValueKey('role-selection-view'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Select your role to continue',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 22),
        _RoleTile(
          title: 'Superadmin',
          subtitle: '',
          icon: Icons.admin_panel_settings_rounded,
          color: const Color(0xFF4A148C),
          selected: _selectedRole == 'superadmin',
          onTap: () => _handleRoleTap('superadmin'),
        ),
        const SizedBox(height: 12),
        _RoleTile(
          title: 'Admin',
          subtitle: '',
          icon: Icons.manage_accounts_rounded,
          color: const Color(0xFF0D47A1),
          selected: _selectedRole == 'admin',
          onTap: () => _handleRoleTap('admin'),
        ),
        const SizedBox(height: 12),
        _RoleTile(
          title: 'Employee',
          subtitle: '',
          icon: Icons.person_rounded,
          color: const Color(0xFF1B5E20),
          selected: _selectedRole == 'employee',
          onTap: () => _handleRoleTap('employee'),
        ),
      ],
    );
  }

  Widget _buildPinEntryView(BuildContext context) {
    return Column(
      key: const ValueKey('pin-entry-view'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Role: ${(_selectedRole ?? '').toUpperCase()}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your 4-digit PIN',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _pinController,
                focusNode: _pinFocusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                showCursor: false,
                enableInteractiveSelection: false,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_pinLength),
                ],
                onChanged: _onPinChanged,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).requestFocus(_pinFocusNode),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pinLength, (index) {
              final hasDigit = index < _pin.length;
              return Container(
                width: 54,
                height: 62,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasDigit
                        ? Theme.of(context).colorScheme.primary
                        : Colors.blueGrey.shade200,
                    width: hasDigit ? 1.8 : 1,
                  ),
                ),
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: hasDigit ? 1 : 0,
                    child: const Text(
                      '●',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 14),
        if (_errorMessage != null) ...[
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
        ],
        ElevatedButton.icon(
          onPressed: _isVerifying || _pin.length != _pinLength
              ? null
              : _submitPin,
          icon: _isVerifying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login_rounded),
          label: Text(_isVerifying ? 'Verifying...' : 'Login'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 4,
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _isVerifying ? null : _backToRoleSelection,
          child: const Text('Back to role selection'),
        ),
      ],
    );
  }
}

class _RoleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _RoleTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? color.withValues(alpha: 0.12) : Colors.white,
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withValues(alpha: 0.18),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? color : Colors.grey.shade500,
            ),
          ],
        ),
      ),
    );
  }
}
