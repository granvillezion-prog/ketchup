// lib/models.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// ---------------------------
/// QUESTIONS
/// ---------------------------

class MockQuestion {
  final String id;
  final String text;

  const MockQuestion({
    required this.id,
    required this.text,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
      };

  factory MockQuestion.fromJson(Map<String, dynamic> json) {
    return MockQuestion(
      id: (json['id'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
    );
  }
}

/// ---------------------------
/// LEGACY PAIR (KEEPING YOUR SYSTEM WORKING)
/// ---------------------------

class MockPair {
  final String dateKey;
  final String hiddenName;

  final String phone;

  final String questionId;

  final String answerText;
  final String myAnswerText;

  final String questionText;

  final bool callCompleted;

  final int points;
  final int currentStreak;
  final int longestStreak;

  final int? lastCallAtMs;

  final String circleId;
  final String circleName;
  final int callIndex;
  final int totalCalls;

  /// 🔥 NEW (REAL IDENTITY SUPPORT)
  final String? partnerUid;
  final String? partnerUsername;

  const MockPair({
    required this.dateKey,
    required this.hiddenName,
    this.phone = "",
    required this.questionId,
    this.answerText = "",
    this.myAnswerText = "",
    this.questionText = "",
    this.callCompleted = false,
    this.points = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastCallAtMs,
    this.circleId = "",
    this.circleName = "",
    this.callIndex = 1,
    this.totalCalls = 1,

    // 🔥 NEW
    this.partnerUid,
    this.partnerUsername,
  });

  MockPair copyWith({
    String? dateKey,
    String? hiddenName,
    String? phone,
    String? questionId,
    String? answerText,
    String? myAnswerText,
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
    String? partnerUid,
    String? partnerUsername,
  }) {
    return MockPair(
      dateKey: dateKey ?? this.dateKey,
      hiddenName: hiddenName ?? this.hiddenName,
      phone: phone ?? this.phone,
      questionId: questionId ?? this.questionId,
      answerText: answerText ?? this.answerText,
      myAnswerText: myAnswerText ?? this.myAnswerText,
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
      partnerUid: partnerUid ?? this.partnerUid,
      partnerUsername: partnerUsername ?? this.partnerUsername,
    );
  }

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'hiddenName': hiddenName,
        'phone': phone,
        'questionId': questionId,
        'answerText': answerText,
        'myAnswerText': myAnswerText,
        'questionText': questionText,
        'callCompleted': callCompleted,
        'points': points,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastCallAtMs': lastCallAtMs,
        'circleId': circleId,
        'circleName': circleName,
        'callIndex': callIndex,
        'totalCalls': totalCalls,
        'partnerUid': partnerUid,
        'partnerUsername': partnerUsername,
      };

  factory MockPair.fromJson(Map<String, dynamic> json) {
    int? _toNullableInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    int _toInt(dynamic v, int fallback) {
      if (v == null) return fallback;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? fallback;
    }

    bool _toBool(dynamic v, bool fallback) {
      if (v == null) return fallback;
      if (v is bool) return v;
      final s = v.toString().toLowerCase().trim();
      if (s == 'true') return true;
      if (s == 'false') return false;
      return fallback;
    }

    return MockPair(
      dateKey: (json['dateKey'] ?? '').toString(),
      hiddenName: (json['hiddenName'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      questionId: (json['questionId'] ?? '').toString(),
      answerText: (json['answerText'] ?? '').toString(),
      myAnswerText: (json['myAnswerText'] ?? '').toString(),
      questionText: (json['questionText'] ?? '').toString(),
      callCompleted: _toBool(json['callCompleted'], false),
      points: _toInt(json['points'], 0),
      currentStreak: _toInt(json['currentStreak'], 0),
      longestStreak: _toInt(json['longestStreak'], 0),
      lastCallAtMs: _toNullableInt(json['lastCallAtMs']),
      circleId: (json['circleId'] ?? '').toString(),
      circleName: (json['circleName'] ?? '').toString(),
      callIndex: _toInt(json['callIndex'], 1),
      totalCalls: _toInt(json['totalCalls'], 1),
      partnerUid: (json['partnerUid'] ?? '').toString().isEmpty
          ? null
          : json['partnerUid'],
      partnerUsername: (json['partnerUsername'] ?? '').toString().isEmpty
          ? null
          : json['partnerUsername'],
    );
  }
}

/// ---------------------------
/// 🔥 REAL CIRCLE MEMBER (CRITICAL FIX)
/// ---------------------------

class CircleMember {
  final String id;
  final String displayName;
  final bool onKetchUp;

  /// 🔥 THIS IS THE KEY TO EVERYTHING
  final String? uid;

  final String? username;
  final String? phoneE164;

  const CircleMember({
    required this.id,
    required this.displayName,
    required this.onKetchUp,
    this.uid,
    this.username,
    this.phoneE164,
  });

  factory CircleMember.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return CircleMember(
      id: doc.id,
      displayName: (data['displayName'] ?? '').toString(),
      onKetchUp: (data['onKetchUp'] ?? false) as bool,
      uid: (data['uid'] ?? '').toString().isEmpty ? null : data['uid'],
      username: (data['username'] ?? '').toString().isEmpty ? null : data['username'],
      phoneE164: (data['phoneE164'] ?? '').toString().isEmpty ? null : data['phoneE164'],
    );
  }
}

/// ---------------------------
/// 🔥 MATCHING SYSTEM MODELS
/// ---------------------------

class DailyEligibility {
  final String userId;
  final List<String> eligibleFriendUids;
  final int degree;
  final bool isNewUser;
  final bool isPriorityTomorrow;

  const DailyEligibility({
    required this.userId,
    required this.eligibleFriendUids,
    required this.degree,
    this.isNewUser = false,
    this.isPriorityTomorrow = false,
  });
}

class DailyAssignment {
  final String userId;
  final String? pairedUserId;
  final String state;
  final DateTime assignedAt;

  const DailyAssignment({
    required this.userId,
    required this.pairedUserId,
    required this.state,
    required this.assignedAt,
  });
}

class PairHistoryEntry {
  final String userA;
  final String userB;
  final DateTime pairedAt;

  const PairHistoryEntry({
    required this.userA,
    required this.userB,
    required this.pairedAt,
  });
}