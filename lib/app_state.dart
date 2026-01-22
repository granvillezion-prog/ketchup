// lib/app_state.dart
import 'dart:math' show max;
import 'package:cloud_firestore/cloud_firestore.dart';

import 'models.dart';
import 'storage.dart';
import 'services/progress_service.dart';
import 'services/daily_pair_service.dart';

class AppState {
  /// Optional fallback questions (main question text should come from DailyPairService)
  static const List<MockQuestion> questions = <MockQuestion>[
    MockQuestion(id: 'q0', text: 'What’s something that made you laugh recently?'),
    MockQuestion(id: 'q1', text: 'What’s your favorite meal ever?'),
    MockQuestion(id: 'q2', text: 'What’s one habit you’re trying to build?'),
    MockQuestion(id: 'q3', text: 'What’s a memory you keep replaying lately?'),
  ];

  static MockQuestion getQuestionById(String id) {
    return questions.firstWhere(
      (q) => q.id == id,
      orElse: () => questions.first,
    );
  }

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  /// ✅ Option C: if a call is in progress, "today" is the call-start day.
  static String todayKey() => DailyPairService.effectiveKeyNowOrCallStart();

  /// Ensures there is a today pair (DailyPairService is the source of truth)
  static Future<MockPair?> ensureTodayPair() async {
    await DailyPairService.ensureTodayPair();
    return AppStorage.getTodayPair();
  }

  // ---------------------------------------------------------------------------
  // TIMER / RESUME (+ extend persistence)
  // ---------------------------------------------------------------------------

  static const int baseCallSeconds = 300; // 5 minutes
  static const int extendSeconds = 300; // +5 minutes
  static const int extendedTotalSeconds = baseCallSeconds + extendSeconds; // 600

  /// Returns remaining seconds for the active call if it was started, else null.
  /// - null => call hasn't started (JOIN not pressed)
  /// - 0..totalSeconds => call was started; how many seconds remain
  static int? getRemainingCallSeconds() {
    final startedAtMs = AppStorage.getCallStartedAt();
    if (startedAtMs == null) return null;

    final total = AppStorage.getCallTotalSeconds() ?? baseCallSeconds;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsedSec = ((nowMs - startedAtMs) / 1000).floor();
    final remaining = total - elapsedSec;

    if (remaining <= 0) return 0;
    if (remaining > total) return total;
    return remaining;
  }

  /// True if the timer has started (JOIN happened) and has not been cleared yet.
  static bool hasCallStarted() => AppStorage.getCallStartedAt() != null;

  /// Safe start: sets startedAt only once and initializes total seconds to 5:00.
  static Future<void> setCallStartedNowIfEmpty() async {
    final existing = AppStorage.getCallStartedAt();
    if (existing != null) return;

    await AppStorage.setCallTotalSeconds(baseCallSeconds);
    await AppStorage.setCallStartedAt(DateTime.now().millisecondsSinceEpoch);
  }

  /// Extend once: total time becomes 10:00 (never shrinks).
  static Future<void> markExtendedOnce() async {
    final cur = AppStorage.getCallTotalSeconds() ?? baseCallSeconds;
    if (cur >= extendedTotalSeconds) return;
    await AppStorage.setCallTotalSeconds(extendedTotalSeconds);
  }

  /// Clears persisted call state (use when call fully ends).
  static Future<void> clearCallStarted() async {
    await AppStorage.clearCallTimer();
  }

  // ---------------------------------------------------------------------------
  // Call completion:
  // - awards points once per effective day key
  // - updates streak
  // - writes to Firestore + local storage
  // - then advances (Plus) exactly once
  // ---------------------------------------------------------------------------

  static Future<void> markCallComplete() async {
    // ✅ Lock key up front (before we clear call timer)
    final key = todayKey();

    // Make sure user doc exists + load current day doc
    await ProgressService.ensureUserDoc();
    final day = await ProgressService.getDay(key);

    // If already completed for this key, just sync local + cleanup
    if (day != null && (day['callCompleted'] == true)) {
      final local = AppStorage.getTodayPair();
      if (local != null && !local.callCompleted) {
        await AppStorage.setTodayPair(local.copyWith(callCompleted: true));
      }

      await clearCallStarted();

      // ✅ Only advance once (Plus only)
      await DailyPairService.advanceAfterCompletion();
      return;
    }

    // Pull current progress from Firestore (source of truth)
    final progress = await ProgressService.getUserProgress();
    final points = (progress['points'] ?? 0) as int;
    final currentStreak = (progress['currentStreak'] ?? 0) as int;
    final longestStreak = (progress['longestStreak'] ?? 0) as int;
    final lastCallAtMs = progress['lastCallAtMs'] as int?;

    // ✅ Streak logic should align with the effective key (call-start day),
    // not always DateTime.now() (which could be "tomorrow" after midnight).
    final nowForStreak = () {
      final startedAt = AppStorage.getCallStartedAt();
      if (startedAt == null) return DateTime.now();
      return DateTime.fromMillisecondsSinceEpoch(startedAt);
    }();

    final last = lastCallAtMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lastCallAtMs);

    int newCurrent;
    if (last == null) {
      newCurrent = 1;
    } else {
      final lastDay = _startOfDay(last);
      final nowDay = _startOfDay(nowForStreak);
      final diff = nowDay.difference(lastDay).inDays;

      if (diff == 0) {
        newCurrent = currentStreak;
      } else if (diff == 1) {
        newCurrent = currentStreak + 1;
      } else {
        newCurrent = 1;
      }
    }

    final newLongest = max(longestStreak, newCurrent);

    const pointsEarnedToday = 10;
    final newPoints = points + pointsEarnedToday;

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // 1) Update Firestore user progress
    await ProgressService.setUserProgress({
      'points': newPoints,
      'currentStreak': newCurrent,
      'longestStreak': newLongest,
      'lastCallAtMs': nowMs,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2) Update Firestore day doc (merge)
    await ProgressService.setDay(key, {
      'callCompleted': true,
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 3) Update local cache so UI updates immediately
    final local = AppStorage.getTodayPair();
    if (local != null) {
      await AppStorage.setTodayPair(
        local.copyWith(
          callCompleted: true,
          points: newPoints,
          currentStreak: newCurrent,
          longestStreak: newLongest,
          lastCallAtMs: nowMs,
        ),
      );
    }

    // 4) Clear call timer persistence so the next call/day starts clean
    await clearCallStarted();

    // 5) ✅ After a completed call, move to the next call slot if allowed (Plus)
    await DailyPairService.advanceAfterCompletion();
  }
}
