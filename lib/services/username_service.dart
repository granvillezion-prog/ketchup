import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UsernameService {
  static final _db = FirebaseFirestore.instance;

  static const Set<String> _reserved = {
    'admin',
    'support',
    'help',
    'system',
    'mod',
    'root',
    'api',
    'null',
    'undefined',
    'me',
    'you',
  };

  /// Canonical username:
  /// - trim
  /// - lowercase
  /// - remove leading '@'
  static String normalize(String raw) {
    var s = raw.trim().toLowerCase();
    if (s.startsWith('@')) s = s.substring(1);
    return s;
  }

  /// 3–16 chars. Letters, numbers, '.' and '_' only.
  static String? validate(String raw) {
    final u = normalize(raw);

    if (u.isEmpty) return 'Username required.';
    if (u.length < 3) return 'Too short (min 3).';
    if (u.length > 16) return 'Too long (max 16).';

    final ok = RegExp(r'^[a-z0-9._]+$').hasMatch(u);
    if (!ok) return "Use letters, numbers, '.' and '_' only.";

    if (_reserved.contains(u)) return 'That username is reserved.';

    if (u.startsWith('_') || u.endsWith('_')) return 'Cannot start or end with _.';
    if (u.startsWith('.') || u.endsWith('.')) return 'Cannot start or end with .';

    if (u.contains('__')) return 'No double underscores.';
    if (u.contains('..')) return 'No double dots.';
    if (u.contains('._') || u.contains('_.')) return 'No dot/underscore combos.';

    return null;
  }

  /// Claims username in a transaction:
  /// - /usernames/{usernameLower} => {uid, displayName, createdAt, updatedAt}
  /// - /users/{uid} merge => username fields + timestamps
  ///
  /// IMPORTANT: Firestore requires ALL reads before ALL writes in a transaction.
  static Future<void> claimUsername({
    required String username,
    String? displayName,
  }) async {
    final err = validate(username);
    if (err != null) throw StateError(err);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in.');

    final uid = user.uid;
    final uLower = normalize(username);

    final unameRef = _db.collection('usernames').doc(uLower);
    final userRef = _db.collection('users').doc(uid);

    // Rules require displayName to be a string if present; your rules require it always.
    final dn = (displayName ?? '').trim();

    await _db.runTransaction((tx) async {
      // ✅ ALL READS FIRST
      final unameSnap = await tx.get(unameRef);
      final userSnap = await tx.get(userRef);

      // ✅ THEN WRITES

      // 1) Username registry
      if (unameSnap.exists) {
        final existingUid = (unameSnap.data()?['uid'] ?? '').toString();
        if (existingUid.isNotEmpty && existingUid != uid) {
          throw StateError('Username is taken.');
        }

        // Keep original createdAt if it exists.
        final existingCreatedAt = unameSnap.data()?['createdAt'];
        tx.set(unameRef, {
          'uid': uid,
          'displayName': dn,
          'createdAt': existingCreatedAt ?? FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(unameRef, {
          'uid': uid,
          'displayName': dn,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 2) User doc
      final isNewUserDoc = !userSnap.exists;

      final userData = <String, Object?>{
        'uid': uid,
        'username': uLower, // store canonical
        'usernameLower': uLower,
        'updatedAt': FieldValue.serverTimestamp(),
        if (dn.isNotEmpty) 'displayName': dn,
        if (isNewUserDoc) 'createdAt': FieldValue.serverTimestamp(),
      };

      tx.set(userRef, userData, SetOptions(merge: true));
    });
  }

  /// UI helper (not transaction-safe). If exists and owned by current user, treat as available.
  static Future<bool> isAvailable(String raw) async {
    final err = validate(raw);
    if (err != null) return false;

    final uLower = normalize(raw);
    final snap = await _db.collection('usernames').doc(uLower).get();
    if (!snap.exists) return true;

    final existingUid = (snap.data()?['uid'] ?? '').toString();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && existingUid == uid;
  }
}