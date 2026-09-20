import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_data.dart';
import 'package:go_router/go_router.dart';
import '../../../routing/app_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final ValueChanged<String> onLoginSuccess;
  final String? initialRole;

  const LoginScreen({
    required this.onLoginSuccess,
    this.initialRole,
    super.key,
  });

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  String? _selectedRole;
  bool _isOpeningPinScreen = false;
  bool _isLoadingRole = true;
  bool isNavigating = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    _selectedRole = widget.initialRole;

    if (!mounted) return;

    if (_selectedRole == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _selectedRole != null) return;
        context.go(AppRouter.roleSelection);
      });
      return;
    }

    setState(() {
      _isLoadingRole = false;
    });
  }

  Future<void> _continueToPinEntry() async {
    if (_selectedRole == null || _isOpeningPinScreen) {
      return;
    }

    setState(() {
      _isOpeningPinScreen = true;
    });

    try {
      // PinEntryScreen navigates to billing on success via context.go
      // so no return value is needed; just push and let it handle navigation
      await context.push(AppRouter.pinEntry, extra: _selectedRole!);
      // If we're here, the user pressed back without logging in
      if (mounted) {
        widget.onLoginSuccess(_selectedRole!);
      }
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
    if (_isLoadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
                              FutureBuilder<String>(
                                future: AppData.getShopName(),
                                builder: (context, snapshot) {
                                  return Text(
                                    snapshot.data ?? 'ભારત પ્રોવિઝન હાપા',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Login as ${_selectedRole!.toUpperCase()}',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 22),
                              ElevatedButton.icon(
                                onPressed:
                                    (_selectedRole == null ||
                                        _isOpeningPinScreen ||
                                        isNavigating)
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
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _isOpeningPinScreen
                                    ? null
                                    : () {
                                        context.go(AppRouter.roleSelection);
                                      },
                                child: const Text('Change role'),
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
