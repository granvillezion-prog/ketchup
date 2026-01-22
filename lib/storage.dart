// lib/storage.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class AppStorage {
  static SharedPreferences? _prefs;

  static const _kAuthed = 'authed';
  static const _kName = 'profile_name';
  static const _kProfileComplete = 'profile_complete';

  // IMPORTANT: this stays as the "ACTIVE circle members"
  // so Today/DailyPairService can still work even if Firestore circles aren't loaded.
  static const _kCircle = 'circle_list';

  static const _kTodayPair = 'today_pair_json';

  // remember which circle user is currently using (optional / legacy)
  static const _kSelectedCircleId = 'selected_circle_id';

  // ✅ DAILY MULTI-CALL STATE (Plus)
  static const _kStoredTodayKey = 'stored_today_key';
  static const _kCallsUsedToday = 'calls_used_today';
  static const _kUsedCircleIds = 'used_circle_ids';

  // CALL TIMER
  static const _kCallStartedAt = 'call_started_at';
  static const _kCallTotalSeconds = 'call_total_seconds';

  /// Call once in main()
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static SharedPreferences get _p {
    final p = _prefs;
    if (p == null) {
      throw StateError("AppStorage.init() not called. Call it before runApp().");
    }
    return p;
  }

  // ---------------------------------------------------------------------------
  // SELECTED CIRCLE
  // ---------------------------------------------------------------------------

  static String? getSelectedCircleId() => _p.getString(_kSelectedCircleId);

  static Future<void> setSelectedCircleId(String id) async {
    await _p.setString(_kSelectedCircleId, id);
  }

  static Future<void> clearSelectedCircleId() async {
    await _p.remove(_kSelectedCircleId);
  }

  // ---------------------------------------------------------------------------
  // DAILY MULTI-CALL STATE (Plus)
  // ---------------------------------------------------------------------------

  static String? getStoredTodayKey() => _p.getString(_kStoredTodayKey);

  static Future<void> setStoredTodayKey(String key) async {
    await _p.setString(_kStoredTodayKey, key);
  }

  static int getCallsUsedToday() => _p.getInt(_kCallsUsedToday) ?? 0;

  static Future<void> setCallsUsedToday(int v) async {
    await _p.setInt(_kCallsUsedToday, v);
  }

  static List<String> getUsedCircleIds() =>
      _p.getStringList(_kUsedCircleIds) ?? <String>[];

  static Future<void> setUsedCircleIds(List<String> ids) async {
    final cleaned = ids.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    await _p.setStringList(_kUsedCircleIds, cleaned);
  }

  /// ✅ IMPORTANT:
  /// Do NOT remove stored_today_key here. That key is the day marker.
  /// We only reset the counters.
  static Future<void> clearDailyCallState() async {
    await _p.remove(_kCallsUsedToday);
    await _p.remove(_kUsedCircleIds);
  }

  // ---------------------------------------------------------------------------
  // CALL TIMER
  // ---------------------------------------------------------------------------

  static int? getCallStartedAt() => _p.getInt(_kCallStartedAt);

  static Future<void> setCallStartedAt(int ms) async {
    await _p.setInt(_kCallStartedAt, ms);
  }

  static int? getCallTotalSeconds() => _p.getInt(_kCallTotalSeconds);

  static Future<void> setCallTotalSeconds(int seconds) async {
    await _p.setInt(_kCallTotalSeconds, seconds);
  }

  static Future<void> clearCallTimer() async {
    await _p.remove(_kCallStartedAt);
    await _p.remove(_kCallTotalSeconds);
  }

  // ---------------------------------------------------------------------------
  // AUTH
  // ---------------------------------------------------------------------------

  static bool isAuthed() => _p.getBool(_kAuthed) ?? false;

  static Future<void> setAuthed(bool v) async {
    await _p.setBool(_kAuthed, v);
  }

  // ---------------------------------------------------------------------------
  // PROFILE
  // ---------------------------------------------------------------------------

  static String getProfileName() => _p.getString(_kName) ?? '';

  static bool isProfileComplete() => _p.getBool(_kProfileComplete) ?? false;

  static Future<void> setProfile({required String name}) async {
    final trimmed = name.trim();
    await _p.setString(_kName, trimmed);
    await _p.setBool(_kProfileComplete, trimmed.isNotEmpty);
  }

  // ---------------------------------------------------------------------------
  // ACTIVE CIRCLE MEMBERS (legacy/local fallback)
  // ---------------------------------------------------------------------------

  static List<String> getCircle() => _p.getStringList(_kCircle) ?? <String>[];

  static Future<void> setCircle(List<String> names) async {
    final cleaned = names.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    await _p.setStringList(_kCircle, cleaned);
  }

  // ---------------------------------------------------------------------------
  // TODAY PAIR
  // ---------------------------------------------------------------------------

  static MockPair? getTodayPair() {
    final jsonStr = _p.getString(_kTodayPair);
    if (jsonStr == null || jsonStr.isEmpty) return null;

    try {
      final m = json.decode(jsonStr) as Map<String, dynamic>;

      return MockPair(
        dateKey: (m['dateKey'] ?? '') as String,
        hiddenName: (m['hiddenName'] ?? '') as String,
        phone: (m['phone'] ?? '') as String,
        questionId: (m['questionId'] ?? '') as String,
        questionText: (m['questionText'] ?? '') as String,
        answerText: (m['answerText'] ?? '') as String,
        callCompleted: (m['callCompleted'] ?? false) as bool,
        points: (m['points'] ?? 0) as int,
        currentStreak: (m['currentStreak'] ?? 0) as int,
        longestStreak: (m['longestStreak'] ?? 0) as int,
        lastCallAtMs: m['lastCallAtMs'] == null ? null : (m['lastCallAtMs'] as int),

        // ✅ circles-per-day metadata (safe defaults)
        circleId: (m['circleId'] ?? '') as String,
        circleName: (m['circleName'] ?? '') as String,
        callIndex: (m['callIndex'] ?? 1) as int,
        totalCalls: (m['totalCalls'] ?? 1) as int,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> setTodayPair(MockPair pair) async {
    final m = <String, dynamic>{
      'dateKey': pair.dateKey,
      'hiddenName': pair.hiddenName,
      'phone': pair.phone,
      'questionId': pair.questionId,
      'questionText': pair.questionText,
      'answerText': pair.answerText,
      'callCompleted': pair.callCompleted,
      'points': pair.points,
      'currentStreak': pair.currentStreak,
      'longestStreak': pair.longestStreak,
      'lastCallAtMs': pair.lastCallAtMs,
      'circleId': pair.circleId,
      'circleName': pair.circleName,
      'callIndex': pair.callIndex,
      'totalCalls': pair.totalCalls,
    };

    await _p.setString(_kTodayPair, json.encode(m));
  }

  static Future<void> clearTodayPair() async {
    await _p.remove(_kTodayPair);
  }
}
