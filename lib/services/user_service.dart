import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_service.dart';

class UserService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> ensureUserDoc() async {
    final uid = AuthService.uid;

    final docRef = _db.collection('users').doc(uid);
    final snap = await docRef.get();

    // Always keep these fields present
    final base = <String, dynamic>{
      'displayName': AuthService.displayName ?? 'Anonymous',
      'points': 0,
      'currentStreak': 0,
      'longestStreak': 0,
      'lastCompletedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!snap.exists) {
      await docRef.set({
        ...base,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    // If doc exists, patch any missing fields (merge)
    await docRef.set(base, SetOptions(merge: true));
  }
}
