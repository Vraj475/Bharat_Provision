import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/security_question_models.dart';
import '../services/security_questions_service.dart';
import './auth_provider.dart';

// Security Questions Service Provider
final securityQuestionsServiceProvider = Provider<SecurityQuestionsService>((
  ref,
) {
  final storage = ref.watch(secureStorageProvider);
  return SecurityQuestionsService(storage);
});

// Get security questions for current role
final userSecurityConfigProvider =
    FutureProvider.family<UserSecurityConfig?, String>((ref, role) async {
      final service = ref.watch(securityQuestionsServiceProvider);
      return service.getSecurityQuestions('', role);
    });

// Get questions for verification (without answers)
final questionsForVerificationProvider =
    FutureProvider.family<List<SecurityQuestion>?, String>((ref, role) async {
      final service = ref.watch(securityQuestionsServiceProvider);
      final questions = await service.getQuestionsForVerificationByRole(role);
      return questions
          .asMap()
          .entries
          .map(
            (entry) => SecurityQuestion(
              id: (entry.key + 1).toString(),
              question: entry.value,
              answerHash: '',
            ),
          )
          .toList();
    });

// Check if security questions are configured
final hasSecurityQuestionsProvider = FutureProvider.family<bool, String>((
  ref,
  role,
) async {
  final service = ref.watch(securityQuestionsServiceProvider);
  return service.hasSecurityQuestionsForRole(role);
});

// Forgot PIN Recovery State
class ForgotPinRecoveryNotifier extends StateNotifier<ForgotPinRecovery?> {
  ForgotPinRecoveryNotifier() : super(null);

  void initialize(
    String userId,
    String role,
    List<SecurityQuestion> questions,
  ) {
    state = ForgotPinRecovery(
      userId: userId,
      role: role,
      questionsToAnswer: questions,
      answeredCorrectly: List<bool>.filled(questions.length, false),
    );
  }

  void updateAnswer(int questionIndex, bool isCorrect) {
    if (state == null) return;
    final updated = List<bool>.from(state!.answeredCorrectly);
    updated[questionIndex] = isCorrect;
    state = state!.copyWith(answeredCorrectly: updated);
  }

  void incrementAttempt() {
    if (state == null) return;
    state = state!.copyWith(attemptCount: state!.attemptCount + 1);
  }

  void complete() {
    if (state == null) return;
    state = state!.copyWith(isCompleted: true);
  }

  void reset() {
    state = null;
  }
}

// Forgot PIN Recovery Provider
final forgotPinRecoveryProvider =
    StateNotifierProvider<ForgotPinRecoveryNotifier, ForgotPinRecovery?>(
      (ref) => ForgotPinRecoveryNotifier(),
    );

// Verify single security answer
final verifySingleAnswerProvider =
    FutureProvider.family<bool, (SecurityQuestion, String)>((
      ref,
      params,
    ) async {
      final service = ref.watch(securityQuestionsServiceProvider);
      return service.verifyAnswer(params.$1.question, params.$2);
    });

// Verify multiple security answers
final verifyMultipleAnswersProvider =
    FutureProvider.family<bool, (List<SecurityQuestion>, List<String>)>((
      ref,
      params,
    ) async {
      final service = ref.watch(securityQuestionsServiceProvider);
      final questions = params.$1;
      final answers = params.$2;

      final mappedAnswers = <String, String>{};
      final length = questions.length < answers.length
          ? questions.length
          : answers.length;

      for (var i = 0; i < length; i++) {
        mappedAnswers[questions[i].question] = answers[i];
      }

      return service.verifyAnswers(mappedAnswers);
    });

// Save security questions
final saveSecurityQuestionsProvider =
    FutureProvider.family<void, UserSecurityConfig>((ref, config) async {
      final service = ref.watch(securityQuestionsServiceProvider);
      await service.saveSecurityQuestions(config);
    });

// Forgot PIN - Check if user exists and get their questions
final checkUserForForgotPinProvider =
    FutureProvider.family<List<SecurityQuestion>?, String>((
      ref,
      userInput,
    ) async {
      // In a real app, this would:
      // 1. Look up user by username or email
      // 2. Get their role
      // 3. Retrieve their security questions
      // For now, we'll just return questions for the provided role
      // This assumes userInput is the role for demo purposes

      final service = ref.watch(securityQuestionsServiceProvider);
      final questions = await service.getQuestionsForVerificationByRole(
        userInput,
      );
      return questions
          .asMap()
          .entries
          .map(
            (entry) => SecurityQuestion(
              id: (entry.key + 1).toString(),
              question: entry.value,
              answerHash: '',
            ),
          )
          .toList();
    });

// Forgot PIN - Get questions directly by role (no username/email step)
final forgotPinQuestionsByRoleProvider =
    FutureProvider.family<List<SecurityQuestion>, String>((ref, role) async {
      final service = ref.watch(securityQuestionsServiceProvider);
      final questions = await service.getQuestionsForVerificationByRole(role);
      return questions
          .asMap()
          .entries
          .map(
            (entry) => SecurityQuestion(
              id: (entry.key + 1).toString(),
              question: entry.value,
              answerHash: '',
            ),
          )
          .toList();
    });

// Initialize default security questions for all roles (called on app startup)
final initializeSecurityQuestionsProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(securityQuestionsServiceProvider);
  await service.initializeDefaultQuestions();
});
