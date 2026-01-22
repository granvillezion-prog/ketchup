// lib/services/user_data_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DailyMeta {
  final String? lastDailyKey;
  final String? todaysPick;
  final bool spentToday;

  const DailyMeta({
    required this.lastDailyKey,
    required this.todaysPick,
    required this.spentToday,
  });
}

class UserScore {
  final int contactsOnAppCount;
  final int networkScore;
  final int momentumScore;
  final int currentStreak;
  final int longestStreak;

  int get totalScore => networkScore + momentumScore;

  const UserScore({
    required this.contactsOnAppCount,
    required this.networkScore,
    required this.momentumScore,
    required this.currentStreak,
    required this.longestStreak,
  });

  const UserScore.empty()
      : contactsOnAppCount = 0,
        networkScore = 0,
        momentumScore = 0,
        currentStreak = 0,
        longestStreak = 0;

  factory UserScore.fromMap(Map<String, dynamic>? data) {
    final m = data ?? {};
    return UserScore(
      contactsOnAppCount: (m['contactsOnAppCount'] ?? 0) as int,
      networkScore: (m['networkScore'] ?? 0) as int,
      momentumScore: (m['momentumScore'] ?? 0) as int,
      currentStreak: (m['currentStreak'] ?? 0) as int,
      longestStreak: (m['longestStreak'] ?? 0) as int,
    );
  }
}

class UserDataService {
  UserDataService._();
  static final UserDataService instance = UserDataService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // local cache to prevent redundant writes from UI rebuilds
  int? _lastNetworkContactsCountWritten;
  int? _lastNetworkScoreWritten;

  String get uid {
    final u = _auth.currentUser;
    if (u == null) throw StateError("Not signed in.");
    return u.uid;
  }

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _db.collection('users').doc(uid);

  Stream<List<String>> circleStream() {
    return _userDoc.snapshots().map((snap) {
      final data = snap.data();
      final list = (data?['circle'] as List?) ?? const [];
      return list.map((e) => e.toString()).toList();
    });
  }

  Future<void> addToCircle(String name) async {
    await _userDoc.set({
      'circle': FieldValue.arrayUnion([name]),
    }, SetOptions(merge: true));
  }

  Future<void> removeFromCircle(String name) async {
    await _userDoc.set({
      'circle': FieldValue.arrayRemove([name]),
    }, SetOptions(merge: true));
  }

  /// --- DAILY META ---
  Future<void> setTodaysPick(String dailyKey, String? pick) async {
    // If the pick is unchanged, avoid unnecessary writes.
    final snap = await _userDoc.get();
    final data = snap.data() ?? {};
    final currentKey = data['lastDailyKey'] as String?;
    final currentPick = data['todaysPick'] as String?;

    if (currentKey == dailyKey && currentPick == pick) return;

    await _userDoc.set({
      'lastDailyKey': dailyKey,
      'todaysPick': pick,
    }, SetOptions(merge: true));
  }

  /// Ensures:
  /// - If day changed -> reset spentToday=false and clear todaysPick (so UI can set a fresh one)
  Future<void> ensureDailyState(String dailyKey) async {
    await _db.runTransaction((tx) async {
      final snap = await tx.get(_userDoc);
      final data = snap.data() ?? <String, dynamic>{};

      final lastKey = data['lastDailyKey'] as String?;
      if (lastKey == dailyKey) return;

      tx.set(_userDoc, {
        'lastDailyKey': dailyKey,
        'spentToday': false,
        'todaysPick': null,
      }, SetOptions(merge: true));
    });
  }

  Future<DailyMeta> getDailyMeta() async {
    final snap = await _userDoc.get();
    final data = snap.data();
    return DailyMeta(
      lastDailyKey: data?['lastDailyKey'] as String?,
      todaysPick: data?['todaysPick'] as String?,
      spentToday: (data?['spentToday'] ?? false) as bool,
    );
  }

  Future<void> markSpentToday() async {
    // avoid extra write if already true
    final snap = await _userDoc.get();
    final spent = (snap.data()?['spentToday'] ?? false) as bool;
    if (spent) return;

    await _userDoc.set({'spentToday': true}, SetOptions(merge: true));
  }

  /// --- SCORE ---
  Stream<UserScore> scoreStream() {
    return _userDoc.snapshots().map((snap) => UserScore.fromMap(snap.data()));
  }

  /// IMPORTANT:
  /// Only writes if values are different from what's stored OR from our cache.
  Future<void> syncNetworkScore({required int contactsOnAppCount}) async {
    final networkScore = contactsOnAppCount * 10;

    // Fast local cache short-circuit
    if (_lastNetworkContactsCountWritten == contactsOnAppCount &&
        _lastNetworkScoreWritten == networkScore) {
      return;
    }

    // Read current doc values to avoid redundant writes
    final snap = await _userDoc.get();
    final data = snap.data() ?? {};
    final currentCount = (data['contactsOnAppCount'] ?? 0) as int;
    final currentScore = (data['networkScore'] ?? 0) as int;

    if (currentCount == contactsOnAppCount && currentScore == networkScore) {
      _lastNetworkContactsCountWritten = contactsOnAppCount;
      _lastNetworkScoreWritten = networkScore;
      return;
    }

    await _userDoc.set({
      'contactsOnAppCount': contactsOnAppCount,
      'networkScore': networkScore,
    }, SetOptions(merge: true));

    _lastNetworkContactsCountWritten = contactsOnAppCount;
    _lastNetworkScoreWritten = networkScore;
  }

  String _yesterdayKeyFrom(String dailyKey) {
    final parts = dailyKey.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);

    final dt = DateTime(y, m, d).subtract(const Duration(days: 1));
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return "${dt.year}-$mm-$dd";
  }

  /// Score is only awarded if the call was meaningful.
  Future<void> recordDailyCompletion({
    required String dailyKey,
    required int contactsOnAppCount,
    required int secondsCompleted,
    int minSecondsForCredit = 60,
  }) async {
    if (secondsCompleted < minSecondsForCredit) return;

    await _db.runTransaction((tx) async {
      final ref = _userDoc;
      final snap = await tx.get(ref);
      final data = snap.data() ?? <String, dynamic>{};

      final lastCompletedKey = data['lastCompletedDailyKey'] as String?;
      final currentStreak0 = (data['currentStreak'] ?? 0) as int;
      final longestStreak0 = (data['longestStreak'] ?? 0) as int;
      final momentum0 = (data['momentumScore'] ?? 0) as int;

      // already completed today? no double points
      if (lastCompletedKey == dailyKey) return;

      final yesterdayKey = _yesterdayKeyFrom(dailyKey);

      final newStreak = (lastCompletedKey == yesterdayKey)
          ? currentStreak0 + 1
          : 1;

      final newLongest =
          (newStreak > longestStreak0) ? newStreak : longestStreak0;

      // points formula (keep yours)
      final gained = 25 + (newStreak * 5);
      final newMomentum = momentum0 + gained;

      final networkScore = contactsOnAppCount * 10;

      tx.set(ref, {
        'lastCompletedDailyKey': dailyKey,
        'currentStreak': newStreak,
        'longestStreak': newLongest,
        'momentumScore': newMomentum,
        'contactsOnAppCount': contactsOnAppCount,
        'networkScore': networkScore,
      }, SetOptions(merge: true));
    });
  }
}
