import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/security_question_models.dart';

/// Service for managing security questions securely
class SecurityQuestionsService {
  static const String _questionsKeyPrefix = 'security_questions_';
  static const List<String> _supportedRoles = [
    'superadmin',
    'admin',
    'employee',
  ];

  final FlutterSecureStorage _storage;

  const SecurityQuestionsService(this._storage);

  /// Get security questions configuration for a user
  Future<UserSecurityConfig?> getSecurityQuestions(
    String userId,
    String role,
  ) async {
    try {
      final key = _getStorageKey(role);
      final jsonString = await _storage.read(key: key);
      if (jsonString == null) return null;

      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return UserSecurityConfig.fromJson(jsonMap);
    } catch (e) {
      return null;
    }
  }

  /// Save/update security questions for a user
  Future<void> saveSecurityQuestions(UserSecurityConfig config) async {
    try {
      final key = _getStorageKey(config.role);

      // Hash all answer fields before storing
      final hashedQuestions = config.securityQuestions
          .map((q) => q.copyWith(answerHash: _hashAnswer(q.plainAnswer ?? '')))
          .toList();

      final configToSave = config.copyWith(
        securityQuestions: hashedQuestions,
        lastModifiedAt: DateTime.now(),
      );

      await _storage.write(key: key, value: jsonEncode(configToSave.toJson()));
    } catch (e) {
      rethrow;
    }
  }

  /// Verify a single answer by question text across all configured roles.
  Future<bool> verifyAnswer(String question, String answer) async {
    final normalizedQuestion = question.trim();
    final normalizedAnswer = answer.trim();

    if (normalizedQuestion.isEmpty || normalizedAnswer.isEmpty) {
      return false;
    }

    final Map<String, String> storedQuestions =
        await _getStoredQuestionHashesAcrossRoles();

    final expectedHash = storedQuestions[normalizedQuestion];
    if (expectedHash == null) {
      return false;
    }

    return _hashAnswer(normalizedAnswer) == expectedHash;
  }

  /// Verify multiple answers where key = question and value = plain answer.
  Future<bool> verifyAnswers(Map<String, String> answers) async {
    final Map<String, String> providedAnswers = {
      for (final entry in answers.entries) entry.key.trim(): entry.value.trim(),
    };

    if (providedAnswers.isEmpty) {
      return false;
    }

    final Map<String, String> storedQuestions =
        await _getStoredQuestionHashesAcrossRoles();

    for (final entry in providedAnswers.entries) {
      final expectedHash = storedQuestions[entry.key];
      if (expectedHash == null) {
        return false;
      }
      if (_hashAnswer(entry.value) != expectedHash) {
        return false;
      }
    }

    return true;
  }

  /// Returns question text list from any configured role.
  Future<List<String>> getQuestionsForVerification() async {
    final Map<String, String> storedQuestions =
        await _getStoredQuestionHashesAcrossRoles();
    return storedQuestions.keys.toList();
  }

  /// Returns true when any role has configured questions.
  Future<bool> hasSecurityQuestions() async {
    final questions = await getQuestionsForVerification();
    return questions.isNotEmpty;
  }

  /// Role-scoped helper for verification flows.
  Future<List<String>> getQuestionsForVerificationByRole(String role) async {
    final config = await getSecurityQuestions('', role);
    if (config == null || config.securityQuestions.isEmpty) {
      return [];
    }
    return config.securityQuestions.map((q) => q.question).toList();
  }

  /// Role-scoped helper for setup/feature gating.
  Future<bool> hasSecurityQuestionsForRole(String role) async {
    final questions = await getQuestionsForVerificationByRole(role);
    return questions.isNotEmpty;
  }

  /// Role-scoped single-answer verification.
  Future<bool> verifyAnswerForRole(
    String role,
    String question,
    String answer,
  ) async {
    final questions = await _getStoredQuestionHashesByRole(role);
    final expectedHash = questions[question.trim()];
    if (expectedHash == null) {
      return false;
    }
    return _hashAnswer(answer) == expectedHash;
  }

  /// Role-scoped multi-answer verification.
  Future<bool> verifyAnswersForRole(
    String role,
    Map<String, String> answers,
  ) async {
    final storedQuestions = await _getStoredQuestionHashesByRole(role);
    final providedAnswers = {
      for (final entry in answers.entries) entry.key.trim(): entry.value.trim(),
    };

    if (providedAnswers.isEmpty) {
      return false;
    }

    for (final entry in providedAnswers.entries) {
      final expectedHash = storedQuestions[entry.key];
      if (expectedHash == null || _hashAnswer(entry.value) != expectedHash) {
        return false;
      }
    }

    return true;
  }

  Future<Map<String, String>> _getStoredQuestionHashesAcrossRoles() async {
    final Map<String, String> storedQuestions = {};

    for (final role in _supportedRoles) {
      final roleQuestions = await _getStoredQuestionHashesByRole(role);
      storedQuestions.addAll(roleQuestions);
    }

    return storedQuestions;
  }

  Future<Map<String, String>> _getStoredQuestionHashesByRole(
    String role,
  ) async {
    final config = await getSecurityQuestions('', role);
    if (config == null || config.securityQuestions.isEmpty) {
      return {};
    }

    return {
      for (final question in config.securityQuestions)
        question.question.trim(): question.answerHash,
    };
  }

  /// Hash answer for secure storage
  String _hashAnswer(String answer) {
    // Use SHA256 hash for secure storage (case-insensitive)
    final bytes = utf8.encode(answer.trim().toLowerCase());
    return crypto.sha256.convert(bytes).toString();
  }

  /// Initialize default security questions for all roles (called on app startup)
  /// Each role gets 1 default security question that must be answered
  Future<void> initializeDefaultQuestions() async {
    try {
      // Keep this method for compatibility; users configure questions manually.
      final hasAnyQuestions = await hasSecurityQuestions();
      if (hasAnyQuestions) return;

      final defaultConfigs = [
        UserSecurityConfig(
          userId: '',
          role: 'superadmin',
          securityQuestions: [
            SecurityQuestion(
              id: '1',
              question: 'What was the name of your first pet?',
              answerHash: '', // Will be hashed during save
              plainAnswer: '', // User fills this during setup
            ),
          ],
          createdAt: DateTime.now(),
          isVerified: false,
        ),
        UserSecurityConfig(
          userId: '',
          role: 'admin',
          securityQuestions: [
            SecurityQuestion(
              id: '1',
              question: 'What city were you born in?',
              answerHash: '', // Will be hashed during save
              plainAnswer: '', // User fills this during setup
            ),
          ],
          createdAt: DateTime.now(),
          isVerified: false,
        ),
        UserSecurityConfig(
          userId: '',
          role: 'employee',
          securityQuestions: [
            SecurityQuestion(
              id: '1',
              question: 'What is your mother\'s maiden name?',
              answerHash: '', // Will be hashed during save
              plainAnswer: '', // User fills this during setup
            ),
          ],
          createdAt: DateTime.now(),
          isVerified: false,
        ),
      ];

      for (final config in defaultConfigs) {
        final existing = await getSecurityQuestions('', config.role);
        if (existing == null) {
          await saveSecurityQuestions(config);
        }
      }
    } catch (e) {
      return;
    }
  }

  String _getStorageKey(String role) {
    return '$_questionsKeyPrefix$role';
  }
}
