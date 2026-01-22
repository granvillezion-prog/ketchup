import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DailyMatch {
  final String dateKey;
  final String pairId;
  final String roomId;
  final String otherUid;
  final DateTime? joinedAt;

  DailyMatch({
    required this.dateKey,
    required this.pairId,
    required this.roomId,
    required this.otherUid,
    required this.joinedAt,
  });

  factory DailyMatch.fromMap(String dateKey, Map<String, dynamic> data) {
    DateTime? joined;
    final j = data['joinedAt'];
    if (j is Timestamp) joined = j.toDate();

    return DailyMatch(
      dateKey: dateKey,
      pairId: (data['pairId'] ?? '') as String,
      roomId: (data['roomId'] ?? '') as String,
      otherUid: (data['otherUid'] ?? '') as String,
      joinedAt: joined,
    );
  }
}

class DailyMatchService {
  DailyMatchService._();
  static final instance = DailyMatchService._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) throw Exception("Not signed in");
    return u.uid;
  }

  String todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return "$y-$m-$d";
  }

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  DocumentReference<Map<String, dynamic>> _dailyDoc(String uid, String dateKey) =>
      _db.collection('users').doc(uid).collection('daily').doc(dateKey);

  DocumentReference<Map<String, dynamic>> _pairDoc(String pairId) =>
      _db.collection('pairings').doc(pairId);

  Stream<DailyMatch?> streamToday() {
    final dateKey = todayKey();
    return _dailyDoc(_uid, dateKey).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return DailyMatch.fromMap(dateKey, data);
    });
  }

  Future<String?> getOtherDisplayName(String otherUid) async {
    final snap = await _userDoc(otherUid).get();
    final data = snap.data();
    return (data?['displayName'] as String?)?.trim();
  }

  /// Ensures a daily match exists (creates one if possible).
  /// Requires: users/{uid}.circleUids contains actual user IDs.
  Future<void> ensureTodayMatch() async {
    final me = _uid;
    final dateKey = todayKey();

    // If already matched today, stop.
    final mine = await _dailyDoc(me, dateKey).get();
    if (mine.exists) return;

    // Load my circle
    final meSnap = await _userDoc(me).get();
    final meData = meSnap.data() ?? {};
    final raw = (meData['circleUids'] as List?) ?? [];
    final candidates = raw.map((e) => e.toString()).toList();

    if (candidates.isEmpty) return;

    // Shuffle candidates (random but still stable enough)
    candidates.shuffle(Random());

    // Try each candidate until we create a pair
    for (final other in candidates) {
      if (other == me) continue;

      final small = (me.compareTo(other) <= 0) ? me : other;
      final big = (me.compareTo(other) <= 0) ? other : me;
      final pairId = "${dateKey}_$small\_$big";
      final roomId = pairId;

      final otherDailyRef = _dailyDoc(other, dateKey);
      final myDailyRef = _dailyDoc(me, dateKey);
      final pairRef = _pairDoc(pairId);
      final otherUserRef = _userDoc(other);

      try {
        await _db.runTransaction((tx) async {
          // If either already has a match today, abort this candidate
          final myDaily = await tx.get(myDailyRef);
          if (myDaily.exists) throw Exception("ME_ALREADY_MATCHED");

          final otherDaily = await tx.get(otherDailyRef);
          if (otherDaily.exists) throw Exception("OTHER_ALREADY_MATCHED");

          // Confirm other user exists + mutual circle membership
          final otherUser = await tx.get(otherUserRef);
          final otherData = otherUser.data() ?? {};
          final otherCircle = (otherData['circleUids'] as List?) ?? [];
          final mutual = otherCircle.map((e) => e.toString()).contains(me);
          if (!mutual) throw Exception("NOT_MUTUAL");

          // Create the pair doc (idempotent-ish)
          final expiresAt = Timestamp.fromDate(
            DateTime.now().add(const Duration(hours: 18)),
          );

          tx.set(pairRef, {
            'dateKey': dateKey,
            'users': [small, big],
            'roomId': roomId,
            'createdAt': FieldValue.serverTimestamp(),
            'expiresAt': expiresAt,
          }, SetOptions(merge: true));

          // Create daily docs for both users
          tx.set(myDailyRef, {
            'pairId': pairId,
            'roomId': roomId,
            'otherUid': other,
            'createdAt': FieldValue.serverTimestamp(),
            'expiresAt': expiresAt,
          }, SetOptions(merge: true));

          tx.set(otherDailyRef, {
            'pairId': pairId,
            'roomId': roomId,
            'otherUid': me,
            'createdAt': FieldValue.serverTimestamp(),
            'expiresAt': expiresAt,
          }, SetOptions(merge: true));
        });

        // Transaction succeeded — done for today
        return;
      } catch (_) {
        // Try next candidate
        continue;
      }
    }
  }

  /// Call this when user actually "joins" the call.
  Future<void> markJoinedToday() async {
    final dateKey = todayKey();
    await _dailyDoc(_uid, dateKey).set({
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
