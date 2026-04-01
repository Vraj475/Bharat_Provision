import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/security_question_models.dart';
import '../providers/security_questions_provider.dart';

class SecurityQuestionsSetupScreen extends ConsumerStatefulWidget {
  final String role;
  final VoidCallback? onSaveComplete;

  const SecurityQuestionsSetupScreen({
    required this.role,
    this.onSaveComplete,
    super.key,
  });

  @override
  ConsumerState<SecurityQuestionsSetupScreen> createState() =>
      _SecurityQuestionsSetupScreenState();
}

class _SecurityQuestionsSetupScreenState
    extends ConsumerState<SecurityQuestionsSetupScreen> {
  final List<SecurityQuestion> _selectedQuestions = [];
  final List<TextEditingController> _answerControllers = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    // Initialize with 1 empty question slot
    _addQuestionSlot();
  }

  @override
  void dispose() {
    for (var controller in _answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addQuestionSlot() {
    if (_selectedQuestions.length < 3) {
      setState(() {
        _selectedQuestions.add(
          SecurityQuestion(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            question: '',
            answerHash: '',
          ),
        );
        _answerControllers.add(TextEditingController());
      });
    }
  }

  void _removeQuestionSlot(int index) {
    if (_selectedQuestions.length > 1) {
      setState(() {
        _selectedQuestions.removeAt(index);
        _answerControllers[index].dispose();
        _answerControllers.removeAt(index);
      });
    }
  }

  Future<void> _saveSecurityQuestions() async {
    // Validate
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    // Check all questions are selected and answered
    for (int i = 0; i < _selectedQuestions.length; i++) {
      if (_selectedQuestions[i].question.isEmpty) {
        setState(() {
          _errorMessage = 'Please select all security questions';
        });
        return;
      }
      if (_answerControllers[i].text.trim().isEmpty) {
        setState(() {
          _errorMessage = 'Please answer all security questions';
        });
        return;
      }
    }

    // Check for duplicate questions
    final questionTexts = _selectedQuestions.map((q) => q.question).toList();
    if (questionTexts.length != questionTexts.toSet().length) {
      setState(() {
        _errorMessage =
            'Duplicate questions selected. Please choose different questions.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create security config with answers
      final questionsWithAnswers = <SecurityQuestion>[];
      for (int i = 0; i < _selectedQuestions.length; i++) {
        questionsWithAnswers.add(
          SecurityQuestion(
            id: _selectedQuestions[i].id,
            question: _selectedQuestions[i].question,
            answerHash: '',
            plainAnswer: _answerControllers[i].text.trim(),
          ),
        );
      }

      final config = UserSecurityConfig(
        userId: 'current_user', // In real app, use actual user ID
        role: widget.role,
        securityQuestions: questionsWithAnswers,
        createdAt: DateTime.now(),
        isVerified: true,
      );

      // Save via provider
      await ref.read(saveSecurityQuestionsProvider(config).future);

      setState(() {
        _isLoading = false;
        _successMessage = 'Security questions saved successfully!';
      });

      // Navigate back after success
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          widget.onSaveComplete?.call();
          Navigator.of(context).pop();
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving security questions: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Security Questions'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Set Up Security Questions',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose 1-3 security questions to help recover your PIN if needed. '
              'No password required - these are accessible to all roles.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),

            // Questions
            ...List.generate(_selectedQuestions.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Question number and delete button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Question ${index + 1}',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            if (_selectedQuestions.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete),
                                color: Colors.red.shade600,
                                onPressed: () => _removeQuestionSlot(index),
                                tooltip: 'Remove question',
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Question Dropdown
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: DropdownButton<String>(
                              value: _selectedQuestions[index].question.isEmpty
                                  ? null
                                  : _selectedQuestions[index].question,
                              isExpanded: true,
                              hint: const Text('Select a security question'),
                              underline: const SizedBox(),
                              items: SecurityQuestionsLibrary.questions
                                  .map(
                                    (q) => DropdownMenuItem(
                                      value: q,
                                      child: Text(q),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedQuestions[index] =
                                        _selectedQuestions[index].copyWith(
                                          question: value,
                                        );
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Answer Field
                        TextFormField(
                          controller: _answerControllers[index],
                          decoration: InputDecoration(
                            hintText: 'Your answer (case-insensitive)',
                            prefixIcon: const Icon(Icons.edit),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          enabled: !_isLoading,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 12),

            // Add Question Button
            if (_selectedQuestions.length < 3)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _addQuestionSlot,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Another Question'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade600,
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Messages
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
              const SizedBox(height: 16),
            ],

            if (_successMessage != null && _successMessage!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: TextStyle(color: Colors.green.shade600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveSecurityQuestions,
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
                    : const Icon(Icons.save),
                label: _isLoading
                    ? const Text('Saving...')
                    : const Text('Save Security Questions'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Info Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info, color: Colors.blue.shade600, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your answers are stored securely and are case-insensitive. '
                      'You\'ll need to answer these correctly if you forget your PIN.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
