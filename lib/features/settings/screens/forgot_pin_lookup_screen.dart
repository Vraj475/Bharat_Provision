import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/security_questions_provider.dart';
import '../models/security_question_models.dart';

class ForgotPinLookupScreen extends ConsumerStatefulWidget {
  final Function(String role, List<SecurityQuestion> questions) onUserFound;
  final VoidCallback onBackPressed;

  const ForgotPinLookupScreen({
    required this.onUserFound,
    required this.onBackPressed,
    super.key,
  });

  @override
  ConsumerState<ForgotPinLookupScreen> createState() =>
      _ForgotPinLookupScreenState();
}

class _ForgotPinLookupScreenState extends ConsumerState<ForgotPinLookupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userInputController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedRole;

  @override
  void dispose() {
    _userInputController.dispose();
    super.dispose();
  }

  Future<void> _lookupUser() async {
    if (!_formKey.currentState!.validate() || _selectedRole == null) {
      setState(() {
        _errorMessage = 'Please select a role and enter username/email';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Simulate user lookup delay
      await Future.delayed(const Duration(milliseconds: 500));

      // Get security questions for the role
      final questions = await ref.read(
        checkUserForForgotPinProvider(_selectedRole!).future,
      );

      if (questions == null || questions.isEmpty) {
        setState(() {
          _errorMessage =
              'No security questions configured for this role. Contact administrator.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _isLoading = false;
      });

      // Found user, proceed to verification
      widget.onUserFound(_selectedRole!, questions);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: Unable to retrieve account information';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Recover PIN'),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBackPressed,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Account Recovery',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your details to recover your PIN using security questions',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 30),

              // Role Selection
              Text(
                'Select Your Role',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButton<String>(
                    value: _selectedRole,
                    isExpanded: true,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down),
                    items: const [
                      DropdownMenuItem(
                        value: 'superadmin',
                        child: Text('Super Admin'),
                      ),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(
                        value: 'employee',
                        child: Text('Employee'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value;
                        _errorMessage = null;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Username/Email Input
              Text(
                'Username or Email',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _userInputController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  hintText: 'Enter your username or email',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter username or email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Note: Security questions are available for all roles. No password required.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.blue.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 20),

              // Error Message
              if (_errorMessage != null && _errorMessage!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade600),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _lookupUser,
                  icon: _isLoading
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
                      : const Icon(Icons.search),
                  label: _isLoading
                      ? const Text('Searching...')
                      : const Text('Find My Account'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
