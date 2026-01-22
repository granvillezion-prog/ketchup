// lib/models.dart

class MockQuestion {
  final String id;
  final String text;

  const MockQuestion({
    required this.id,
    required this.text,
  });
}

class MockPair {
  final String dateKey; // YYYY-MM-DD
  final String hiddenName;

  /// contact method for launching a call
  final String phone;

  final String questionId;
  final String answerText;
  final String questionText;

  final bool callCompleted;

  final int points;
  final int currentStreak;
  final int longestStreak;

  final int? lastCallAtMs;

  // ✅ NEW: circles-per-day metadata
  final String circleId;
  final String circleName;
  final int callIndex;   // 1..totalCalls
  final int totalCalls;  // 1..5

  const MockPair({
    required this.dateKey,
    required this.hiddenName,
    this.phone = "",
    required this.questionId,
    this.answerText = "",
    this.questionText = "",
    this.callCompleted = false,
    this.points = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastCallAtMs,

    // ✅ defaults so old saved JSON won’t crash
    this.circleId = "",
    this.circleName = "",
    this.callIndex = 1,
    this.totalCalls = 1,
  });

  MockPair copyWith({
    String? dateKey,
    String? hiddenName,
    String? phone,
    String? questionId,
    String? answerText,
    String? questionText,
    bool? callCompleted,
    int? points,
    int? currentStreak,
    int? longestStreak,
    int? lastCallAtMs,

    String? circleId,
    String? circleName,
    int? callIndex,
    int? totalCalls,
  }) {
    return MockPair(
      dateKey: dateKey ?? this.dateKey,
      hiddenName: hiddenName ?? this.hiddenName,
      phone: phone ?? this.phone,
      questionId: questionId ?? this.questionId,
      answerText: answerText ?? this.answerText,
      questionText: questionText ?? this.questionText,
      callCompleted: callCompleted ?? this.callCompleted,
      points: points ?? this.points,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastCallAtMs: lastCallAtMs ?? this.lastCallAtMs,

      circleId: circleId ?? this.circleId,
      circleName: circleName ?? this.circleName,
      callIndex: callIndex ?? this.callIndex,
      totalCalls: totalCalls ?? this.totalCalls,
    );
  }
}
