// lib/storage.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class AppStorage {
  static SharedPreferences? _prefs;

  static const _kAuthed = 'authed';

  // ---------------------------------------------------------------------------
  // ONBOARDING FLAGS
  // ---------------------------------------------------------------------------
  static const _kPhoneE164 = 'phone_e164';
  static const _kPhoneVerified = 'phone_verified';

  static const _kContactsSynced = 'contacts_synced';
  static const _kAddFriendsDone = 'add_friends_done';
  static const _kContactsSyncPopupDismissed = 'contacts_sync_popup_dismissed';

  // ---------------------------------------------------------------------------
  // PROFILE
  // ---------------------------------------------------------------------------
  static const _kName = 'profile_name';
  static const _kUsername = 'profile_username';

  static const _kProfileComplete = 'profile_complete';
  static const _kUsernameComplete = 'username_complete';

  static const _kProfileIconId = 'profile_icon_id';
  static const _kProfilePhotoUrl = 'profile_photo_url';

  static const _kFriendIconMapJson = 'friend_icon_map_json';

  // Active circle members
  static const _kCircle = 'circle_list';

  // Today pair
  static const _kTodayPair = 'today_pair_json';
  static const _kSelectedCircleId = 'selected_circle_id';

  // Daily multi-call
  static const _kStoredTodayKey = 'stored_today_key';
  static const _kCallsUsedToday = 'calls_used_today';
  static const _kUsedCircleIds = 'used_circle_ids';

  // Call timer
  static const _kCallStartedAt = 'call_started_at';
  static const _kCallTotalSeconds = 'call_total_seconds';

  static const int minCircleMembersToUnlock = 5;

  // ---------------------------------------------------------------------------
  // INIT
  // ---------------------------------------------------------------------------
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static SharedPreferences get _p {
    final p = _prefs;
    if (p == null) {
      throw StateError('AppStorage.init() not called. Call it before runApp().');
    }
    return p;
  }

  // ---------------------------------------------------------------------------
  // AUTH
  // ---------------------------------------------------------------------------
  static bool isAuthed() => _p.getBool(_kAuthed) ?? false;

  static Future<void> setAuthed(bool v) async {
    await _p.setBool(_kAuthed, v);
  }

  // ---------------------------------------------------------------------------
  // PHONE
  // ---------------------------------------------------------------------------
  static String getPhoneE164() => _p.getString(_kPhoneE164) ?? '';

  static String? getPhoneE164OrNull() {
    final v = getPhoneE164().trim();
    return v.isEmpty ? null : v;
  }

  static bool isPhoneVerified() => _p.getBool(_kPhoneVerified) ?? false;

  static Future<void> setPhone({
    required String e164,
    required bool verified,
  }) async {
    final cleaned = e164.trim();
    await _p.setString(_kPhoneE164, cleaned);
    await _p.setBool(_kPhoneVerified, verified);
  }

  static Future<void> setPhoneVerified(bool v) async {
    await _p.setBool(_kPhoneVerified, v);
  }

  static Future<void> clearPhone() async {
    await _p.remove(_kPhoneE164);
    await _p.remove(_kPhoneVerified);
  }

  // ---------------------------------------------------------------------------
  // CONTACTS SYNC
  // ---------------------------------------------------------------------------
  static bool areContactsSynced() => _p.getBool(_kContactsSynced) ?? false;

  static Future<void> setContactsSynced(bool v) async {
    await _p.setBool(_kContactsSynced, v);
  }

  static Future<void> clearContactsSynced() async {
    await _p.remove(_kContactsSynced);
  }

  static bool isContactsSyncPopupDismissed() =>
      _p.getBool(_kContactsSyncPopupDismissed) ?? false;

  static Future<void> setContactsSyncPopupDismissed(bool v) async {
    await _p.setBool(_kContactsSyncPopupDismissed, v);
  }

  // ---------------------------------------------------------------------------
  // LEGACY ADD FRIENDS FLAG
  // ---------------------------------------------------------------------------
  static bool isAddFriendsDone() => _p.getBool(_kAddFriendsDone) ?? false;

  static Future<void> setAddFriendsDone(bool v) async {
    await _p.setBool(_kAddFriendsDone, v);
  }

  static Future<void> clearAddFriendsDone() async {
    await _p.remove(_kAddFriendsDone);
  }

  // ---------------------------------------------------------------------------
  // PROFILE
  // ---------------------------------------------------------------------------
  static String getProfileName() => _p.getString(_kName) ?? '';
  static String getProfileUsername() => _p.getString(_kUsername) ?? '';
  static String getUsername() => _p.getString(_kUsername) ?? '';

  static bool isProfileComplete() {
    final n = getProfileName().trim();
    return n.isNotEmpty;
  }

  static bool isUsernameComplete() =>
      _p.getBool(_kUsernameComplete) ?? getProfileUsername().trim().isNotEmpty;

  static Future<void> setProfile({
    required String name,
    String? username,
  }) async {
    final trimmedName = name.trim();
    await _p.setString(_kName, trimmedName);

    if (username != null) {
      final u = username.trim();
      await _p.setString(_kUsername, u);
      await _p.setBool(_kUsernameComplete, u.isNotEmpty);
    }

    await _p.setBool(_kProfileComplete, trimmedName.isNotEmpty);
  }

  static Future<void> setUsername(String username) async {
    final u = username.trim();
    await _p.setString(_kUsername, u);
    await _p.setBool(_kUsernameComplete, u.isNotEmpty);

    final nameOk = getProfileName().trim().isNotEmpty;
    await _p.setBool(_kProfileComplete, nameOk);
  }

  static Future<void> clearUsername() async {
    await _p.remove(_kUsername);
    await _p.remove(_kUsernameComplete);

    final nameOk = getProfileName().trim().isNotEmpty;
    await _p.setBool(_kProfileComplete, nameOk);
  }

  // ---------------------------------------------------------------------------
  // PROFILE PHOTO
  // ---------------------------------------------------------------------------
  static String getProfilePhotoUrl() => _p.getString(_kProfilePhotoUrl) ?? '';

  static Future<void> setProfilePhotoUrl(String url) async {
    await _p.setString(_kProfilePhotoUrl, url.trim());
  }

  static Future<void> clearProfilePhotoUrl() async {
    await _p.remove(_kProfilePhotoUrl);
  }

  // ---------------------------------------------------------------------------
  // ICON PICKER
  // ---------------------------------------------------------------------------
  static String getProfileIconId() => _p.getString(_kProfileIconId) ?? '';

  static Future<void> setProfileIconId(String iconId) async {
    await _p.setString(_kProfileIconId, iconId.trim());
  }

  static Future<void> clearProfileIconId() async {
    await _p.remove(_kProfileIconId);
  }

  // ---------------------------------------------------------------------------
  // FRIEND ICON MAP
  // ---------------------------------------------------------------------------
  static Map<String, String> getFriendIconMap() {
    final raw = _p.getString(_kFriendIconMapJson);
    if (raw == null || raw.isEmpty) return <String, String>{};

    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) return <String, String>{};

      final out = <String, String>{};
      decoded.forEach((k, v) {
        final key = k.toString().trim();
        final val = v.toString().trim();
        if (key.isNotEmpty && val.isNotEmpty) out[key] = val;
      });
      return out;
    } catch (_) {
      return <String, String>{};
    }
  }

  static String getFriendIconId(String friendName) {
    final key = friendName.trim();
    if (key.isEmpty) return '';
    final map = getFriendIconMap();
    return map[key] ?? '';
  }

  static Future<void> setFriendIconId(String friendName, String iconId) async {
    final key = friendName.trim();
    final val = iconId.trim();
    if (key.isEmpty) return;

    final map = getFriendIconMap();
    if (val.isEmpty) {
      map.remove(key);
    } else {
      map[key] = val;
    }
    await _p.setString(_kFriendIconMapJson, json.encode(map));
  }

  static Future<void> setFriendIconMap(Map<String, String> map) async {
    final cleaned = <String, String>{};
    map.forEach((k, v) {
      final kk = k.trim();
      final vv = v.trim();
      if (kk.isNotEmpty && vv.isNotEmpty) cleaned[kk] = vv;
    });
    await _p.setString(_kFriendIconMapJson, json.encode(cleaned));
  }

  static Future<void> clearFriendIconMap() async {
    await _p.remove(_kFriendIconMapJson);
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
  // DAILY MULTI-CALL STATE
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
  // ACTIVE CIRCLE MEMBERS
  // ---------------------------------------------------------------------------
  static List<String> getCircle() => _p.getStringList(_kCircle) ?? <String>[];

  static Future<void> setCircle(List<String> namesOrUsernames) async {
    final cleaned =
        namesOrUsernames.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    await _p.setStringList(_kCircle, cleaned);
  }

  static int getCircleCount() => getCircle().length;

  static bool hasMinimumCircleMembers([int min = minCircleMembersToUnlock]) {
    return getCircleCount() >= min;
  }

  static bool isCoreOnboardingComplete() {
    return isAuthed() &&
        isProfileComplete() &&
        areContactsSynced() &&
        hasMinimumCircleMembers();
  }

  // ---------------------------------------------------------------------------
  // TODAY PAIR
  // ---------------------------------------------------------------------------
  static MockPair? getTodayPair() {
    final jsonStr = _p.getString(_kTodayPair);
    if (jsonStr == null || jsonStr.isEmpty) return null;

    try {
      final decoded = json.decode(jsonStr);
      if (decoded is! Map<String, dynamic>) return null;
      return MockPair.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setTodayPair(MockPair pair) async {
    await _p.setString(_kTodayPair, json.encode(pair.toJson()));
  }

  static Future<void> clearTodayPair() async {
    await _p.remove(_kTodayPair);
  }
}