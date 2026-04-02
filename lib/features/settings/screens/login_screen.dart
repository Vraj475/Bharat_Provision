import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pin_entry_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final ValueChanged<String> onLoginSuccess;

  const LoginScreen({required this.onLoginSuccess, super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  String? _selectedRole;
  bool _isOpeningPinScreen = false;

  Future<void> _continueToPinEntry() async {
    if (_selectedRole == null || _isOpeningPinScreen) {
      return;
    }

    setState(() {
      _isOpeningPinScreen = true;
    });

    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PinEntryScreen(
            role: _selectedRole!,
            onLoginSuccess: widget.onLoginSuccess,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningPinScreen = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                              Text(
                                'Bharat Provision',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Select your role to continue',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 22),
                              _RoleTile(
                                title: 'Superadmin',
                                subtitle: 'Full control access',
                                icon: Icons.admin_panel_settings_rounded,
                                color: const Color(0xFF4A148C),
                                selected: _selectedRole == 'superadmin',
                                onTap: () {
                                  setState(() {
                                    _selectedRole = 'superadmin';
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              _RoleTile(
                                title: 'Admin',
                                subtitle: 'Operations and settings',
                                icon: Icons.manage_accounts_rounded,
                                color: const Color(0xFF0D47A1),
                                selected: _selectedRole == 'admin',
                                onTap: () {
                                  setState(() {
                                    _selectedRole = 'admin';
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              _RoleTile(
                                title: 'Employee',
                                subtitle: 'Daily billing and stock actions',
                                icon: Icons.person_rounded,
                                color: const Color(0xFF1B5E20),
                                selected: _selectedRole == 'employee',
                                onTap: () {
                                  setState(() {
                                    _selectedRole = 'employee';
                                  });
                                },
                              ),
                              const SizedBox(height: 22),
                              ElevatedButton.icon(
                                onPressed:
                                    (_selectedRole == null ||
                                        _isOpeningPinScreen)
                                    ? null
                                    : _continueToPinEntry,
                                icon: _isOpeningPinScreen
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.arrow_forward_rounded),
                                label: Text(
                                  _isOpeningPinScreen
                                      ? 'Opening...'
                                      : 'Continue to PIN',
                                ),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(54),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 4,
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
      ),
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
        duration: const Duration(milliseconds: 180),
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
