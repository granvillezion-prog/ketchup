// lib/services/progress_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProgressService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String _uidOrThrow() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("No user signed in.");
    return uid;
  }

  static DocumentReference<Map<String, dynamic>> _userDoc() {
    final uid = _uidOrThrow();
    return _db.collection('users').doc(uid);
  }

  static CollectionReference<Map<String, dynamic>> _daysCol() {
    return _userDoc().collection('days');
  }

  /// Ensures /users/{uid} exists
  static Future<void> ensureUserDoc() async {
    final ref = _userDoc();
    final snap = await ref.get();

    final base = <String, dynamic>{
      'points': 0,
      'currentStreak': 0,
      'longestStreak': 0,
      'lastCallAtMs': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!snap.exists) {
      await ref.set(base, SetOptions(merge: true));
      return;
    }

    // keep updatedAt fresh (and ensure any missing fields are added)
    await ref.set(
      {
        'updatedAt': FieldValue.serverTimestamp(),
        if (!(snap.data() ?? {}).containsKey('points')) 'points': 0,
        if (!(snap.data() ?? {}).containsKey('currentStreak')) 'currentStreak': 0,
        if (!(snap.data() ?? {}).containsKey('longestStreak')) 'longestStreak': 0,
        if (!(snap.data() ?? {}).containsKey('lastCallAtMs')) 'lastCallAtMs': null,
      },
      SetOptions(merge: true),
    );
  }

  /// Reads /users/{uid}
  static Future<Map<String, dynamic>> getUserProgress() async {
    final snap = await _userDoc().get();
    return (snap.data() ?? <String, dynamic>{});
  }

  /// Writes /users/{uid} (merge)
  static Future<void> setUserProgress(Map<String, dynamic> data) async {
    await _userDoc().set(data, SetOptions(merge: true));
  }

  /// Reads /users/{uid}/days/{dateKey}
  static Future<Map<String, dynamic>?> getDay(String dateKey) async {
    final snap = await _daysCol().doc(dateKey).get();
    if (!snap.exists) return null;
    return snap.data();
  }

  /// Writes /users/{uid}/days/{dateKey} (merge)
  ///
  /// Expected day fields (your prototype):
  /// - dateKey: String
  /// - hiddenName: String
  /// - phone: String
  /// - questionId: String
  /// - questionText: String
  /// - answerText: String
  /// - callCompleted: bool
  /// - circleId / circleName / callIndex / totalCalls
  /// - createdAt / updatedAt: timestamps
  /// - completedAt: timestamp (when call completes)
  static Future<void> setDay(String dateKey, Map<String, dynamic> data) async {
    // ✅ Make sure every write refreshes updatedAt automatically
    final merged = <String, dynamic>{
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _daysCol().doc(dateKey).set(merged, SetOptions(merge: true));
  }
}
