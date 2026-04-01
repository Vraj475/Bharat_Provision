import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/security_question_models.dart';

/// Service for managing security questions securely
class SecurityQuestionsService {
  static const String _questionsKeyPrefix =
      'security_questions_'; // role-based: security_questions_superadmin

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
  /// Initialize or validate security questions for a role
  /// Users will add their own questions - this just validates they exist
  Future<void> initializeDefaultQuestions() async {
    try {
      // This method is kept for compatibility but doesn't auto-initialize
      // Users manually add questions via Settings > Security tab
      return;
    } catch (e) {
      return;
    }
  }
      if (jsonString == null) return null;

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return UserSecurityConfig.fromJson(json);
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

      return config != null && config.securityQuestions.isNotEmpty;

    int correctCount = 0;
    for (int i = 0; i < storedQuestions.length; i++) {
      final isCorrect = await verifyAnswer(
        storedQuestions[i],
        providedAnswers[i],
      );
      if (isCorrect) correctCount++;
    }

    return correctCount;
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
      // Check if already initialized for any role
      final superadminHasQuestions = await hasSecurityQuestions('superadmin');
      if (superadminHasQuestions) return; // Already initialized

      // Define default security questions for each role
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

      // Save default configs for each role
      for (final config in defaultConfigs) {
        // Only save if not already configured
        final existing = await getSecurityQuestions('', config.role);
        if (existing == null) {
          await saveSecurityQuestions(config);
        }
      }
    } catch (e) {
      // Silently fail if initialization doesn't work - app can still function
      return;
    }
  }

  String _getStorageKey(String role) {
    return '$_questionsKeyPrefix$role';
  }
}
