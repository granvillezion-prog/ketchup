import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DailyDoc {
  DailyDoc({
    required this.dateKey,
    required this.mystoUid,
    required this.questionId,
    required this.status, // pending | active | completed
  });

  final String dateKey;
  final String mystoUid;
  final String questionId;
  final String status;

  factory DailyDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return DailyDoc(
      dateKey: doc.id,
      mystoUid: (data['mystoUid'] ?? '') as String,
      questionId: (data['questionId'] ?? '') as String,
      status: (data['status'] ?? 'pending') as String,
    );
  }
}

class DailyService {
  static final _db = FirebaseFirestore.instance;

  static String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static DocumentReference<Map<String, dynamic>> _dailyRef(String uid, String dateKey) {
    return _db.collection('users').doc(uid).collection('daily').doc(dateKey);
  }

  static Future<DailyDoc?> getToday() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final key = _dateKey(DateTime.now());
    final doc = await _dailyRef(uid, key).get();
    if (!doc.exists) return null;
    return DailyDoc.fromDoc(doc);
  }

  /// Call this when user presses "Start Call"
  static Future<void> markActiveToday() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final key = _dateKey(DateTime.now());
    final ref = _dailyRef(uid, key);

    await ref.set({
      'status': 'active',
    }, SetOptions(merge: true));
  }

  /// Call this when call ends (completed)
  static Future<void> completeTodayAndUpdateUser({
    int pointsEarned = 10,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final key = _dateKey(DateTime.now());
    final userRef = _db.collection('users').doc(uid);
    final dailyRef = _dailyRef(uid, key);

    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final user = userSnap.data() ?? {};

      final currentStreak = (user['currentStreak'] ?? 0) as int;
      final longestStreak = (user['longestStreak'] ?? 0) as int;
      final points = (user['points'] ?? 0) as int;

      final now = Timestamp.now();

      final newStreak = currentStreak + 1;
      final newLongest = newStreak > longestStreak ? newStreak : longestStreak;

      tx.set(dailyRef, {
        'status': 'completed',
        'completedAt': now,
      }, SetOptions(merge: true));

      tx.set(userRef, {
        'points': points + pointsEarned,
        'currentStreak': newStreak,
        'longestStreak': newLongest,
        'lastCompletedAt': now,
      }, SetOptions(merge: true));
    });
  }
}
