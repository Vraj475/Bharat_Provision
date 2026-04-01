import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/security_question_models.dart';
import '../providers/security_questions_provider.dart';

class ForgotPinVerificationScreen extends ConsumerStatefulWidget {
  final String role;
  final List<SecurityQuestion> questions;
  final Function(bool allCorrect) onVerificationComplete;
  final VoidCallback onBackPressed;

  const ForgotPinVerificationScreen({
    required this.role,
    required this.questions,
    required this.onVerificationComplete,
    required this.onBackPressed,
    super.key,
  });

  @override
  ConsumerState<ForgotPinVerificationScreen> createState() =>
      _ForgotPinVerificationScreenState();
}

class _ForgotPinVerificationScreenState
    extends ConsumerState<ForgotPinVerificationScreen> {
  late List<TextEditingController> _answerControllers;
  bool _isLoading = false;
  String? _errorMessage;
  int _attemptCount = 0;

  @override
  void initState() {
    super.initState();
    _answerControllers = List.generate(
      widget.questions.length,
      (index) => TextEditingController(),
    );
  }

  @override
  void dispose() {
    for (var controller in _answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _verifyAnswers() async {
    // Check all answers are filled
    for (var controller in _answerControllers) {
      if (controller.text.trim().isEmpty) {
        setState(() {
          _errorMessage = 'Please answer all security questions';
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _attemptCount++;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 500));

      final service = ref.read(securityQuestionsServiceProvider);

      // Verify all answers
      int correctCount = 0;
      final answers = _answerControllers.map((c) => c.text).toList();

      for (int i = 0; i < widget.questions.length; i++) {
        final isCorrect = await service.verifyAnswer(
          widget.questions[i].question,
          answers[i],
        );
        if (isCorrect) correctCount++;
      }

      // Calculate passing grade (at least 66% correct)
      final requiredCorrect = (widget.questions.length * 0.66).ceil();
      final allCorrect = correctCount >= requiredCorrect;

      setState(() {
        _isLoading = false;
      });

      if (allCorrect) {
        widget.onVerificationComplete(true);
      } else {
        setState(() {
          _errorMessage =
              'Incorrect answers. Please try again. '
              'Attempts: $_attemptCount/3';
        });

        // Lock after 3 failed attempts
        if (_attemptCount >= 3) {
          setState(() {
            _errorMessage = 'Too many failed attempts. Please try again later.';
          });
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              widget.onBackPressed();
            }
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error verifying answers: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Answer Security Questions'),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isLoading ? null : widget.onBackPressed,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Security Verification',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Answer your security questions to verify your identity and reset your PIN',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'At least ${(widget.questions.length * 0.66).ceil()} out of ${widget.questions.length} answers must be correct',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.blue.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            // Questions and Answers
            ...List.generate(widget.questions.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Question ${index + 1}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.questions[index].question,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _answerControllers[index],
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: 'Your answer',
                        prefixIcon: const Icon(Icons.edit),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      autofocus: index == 0,
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 12),

            // Attempt Counter
            if (_attemptCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Attempt $_attemptCount of 3',
                      style: TextStyle(
                        color: Colors.orange.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

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
                        style: TextStyle(
                          color: Colors.red.shade600,
                          fontSize: 13,
                        ),
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
                onPressed: (_isLoading || _attemptCount >= 3)
                    ? null
                    : _verifyAnswers,
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
                    : const Icon(Icons.check_circle),
                label: _isLoading
                    ? const Text('Verifying...')
                    : const Text('Verify Answers'),
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
    );
  }
}
