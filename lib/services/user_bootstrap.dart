import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserBootstrap {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static Future<void> ensureUserDoc() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('ensureUserDoc called with no signed-in user');
    }

    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();

    if (snap.exists) return;

    await ref.set({
      'displayName': user.displayName ?? 'New User',
      'createdAt': FieldValue.serverTimestamp(),
      'points': 0,
      'currentStreak': 0,
      'longestStreak': 0,
      'lastCompletedAt': null,
      'spentToday': false,
      'todayPick': null,
      'networkScore': 0,
      'contactsOnAppCount': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
