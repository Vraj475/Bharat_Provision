/// Security Question Model
class SecurityQuestion {
  final String id;
  final String question;
  final String answerHash;
  // Only used during setup/editing, not stored
  final String? plainAnswer;

  SecurityQuestion({
    required this.id,
    required this.question,
    required this.answerHash,
    this.plainAnswer,
  });

  SecurityQuestion copyWith({
    String? id,
    String? question,
    String? answerHash,
    String? plainAnswer,
  }) {
    return SecurityQuestion(
      id: id ?? this.id,
      question: question ?? this.question,
      answerHash: answerHash ?? this.answerHash,
      plainAnswer: plainAnswer ?? this.plainAnswer,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'question': question, 'answerHash': answerHash};
  }

  factory SecurityQuestion.fromJson(Map<String, dynamic> json) {
    return SecurityQuestion(
      id: json['id'] as String,
      question: json['question'] as String,
      answerHash: json['answerHash'] as String,
    );
  }
}

/// Predefined Security Questions List
class SecurityQuestionsLibrary {
  static const List<String> questions = [
    'What was the name of your first pet?',
    'What city were you born in?',
    'What is your mother\'s maiden name?',
    'What was the name of your elementary school?',
    'What was your childhood nickname?',
    'What is the name of your favorite childhood friend?',
    'What street did you grow up on?',
    'What was the make of your first car?',
    'What is your oldest sibling\'s middle name?',
    'What was the name of your first stuffed animal?',
    'In what city or town did your mother and father meet?',
    'What is the name of the place where you were born?',
    'What was the name of your first teacher?',
    'What was your first job title?',
    'What was the name of your favorite book in childhood?',
  ];

  static int get count => questions.length;
  static String getQuestion(int index) => questions[index];
}

/// User Account Security Configuration
class UserSecurityConfig {
  final String userId;
  final String role;
  final List<SecurityQuestion> securityQuestions;
  final DateTime createdAt;
  final DateTime? lastModifiedAt;
  final bool isVerified;

  UserSecurityConfig({
    required this.userId,
    required this.role,
    required this.securityQuestions,
    required this.createdAt,
    this.lastModifiedAt,
    this.isVerified = false,
  });

  // Validate: max 3 questions, min 1
  bool get isValid {
    return securityQuestions.isNotEmpty && securityQuestions.length <= 3;
  }

  UserSecurityConfig copyWith({
    String? userId,
    String? role,
    List<SecurityQuestion>? securityQuestions,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    bool? isVerified,
  }) {
    return UserSecurityConfig(
      userId: userId ?? this.userId,
      role: role ?? this.role,
      securityQuestions: securityQuestions ?? this.securityQuestions,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'role': role,
      'securityQuestions': securityQuestions.map((q) => q.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'lastModifiedAt': lastModifiedAt?.toIso8601String(),
      'isVerified': isVerified,
    };
  }

  factory UserSecurityConfig.fromJson(Map<String, dynamic> json) {
    final questionsJson = json['securityQuestions'] as List<dynamic>? ?? [];
    return UserSecurityConfig(
      userId: json['userId'] as String,
      role: json['role'] as String,
      securityQuestions: questionsJson
          .map((q) => SecurityQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastModifiedAt: json['lastModifiedAt'] != null
          ? DateTime.parse(json['lastModifiedAt'] as String)
          : null,
      isVerified: json['isVerified'] as bool? ?? false,
    );
  }
}

/// Forgot PIN Recovery Models
class ForgotPinRecovery {
  final String userId; // username or email
  final String role;
  final List<SecurityQuestion> questionsToAnswer;
  final List<bool> answeredCorrectly;
  final int attemptCount;
  final bool isCompleted;

  ForgotPinRecovery({
    required this.userId,
    required this.role,
    required this.questionsToAnswer,
    this.answeredCorrectly = const [],
    this.attemptCount = 0,
    this.isCompleted = false,
  });

  int get correctAnswerCount => answeredCorrectly.where((x) => x).length;
  int get requiredCorrectAnswers =>
      (questionsToAnswer.length * 0.66).ceil(); // 66% of answers

  ForgotPinRecovery copyWith({
    String? userId,
    String? role,
    List<SecurityQuestion>? questionsToAnswer,
    List<bool>? answeredCorrectly,
    int? attemptCount,
    bool? isCompleted,
  }) {
    return ForgotPinRecovery(
      userId: userId ?? this.userId,
      role: role ?? this.role,
      questionsToAnswer: questionsToAnswer ?? this.questionsToAnswer,
      answeredCorrectly: answeredCorrectly ?? this.answeredCorrectly,
      attemptCount: attemptCount ?? this.attemptCount,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
