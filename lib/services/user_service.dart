// lib/services/user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/auth_service.dart';
import '../storage.dart';
import '../services/firestore_service.dart'; // ✅ for buildSearchTokens + normalizeUsername

class UserService {
  static final _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  // Remove nulls & empty strings so we never "overwrite" with garbage
  static Map<String, dynamic> _compact(Map<String, dynamic> m) {
    final out = <String, dynamic>{};
    m.forEach((k, v) {
      if (v == null) return;
      if (v is String && v.trim().isEmpty) return;
      out[k] = v;
    });
    return out;
  }

  static String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  /// ✅ Safe bootstrap:
  /// - If user doc doesn't exist => create it with defaults.
  /// - If it exists => only PATCH missing identity fields, NEVER reset stats.
  static Future<void> ensureUserDoc() async {
    final uid = AuthService.uid;
    if (uid.isEmpty) return;

    final docRef = _userDoc(uid);

    final localName = AppStorage.getProfileName().trim();
    final localUsername = AppStorage.getUsername().trim();
    final localPhone = AppStorage.getPhoneE164().trim();

    final snap = await docRef.get();

    if (!snap.exists) {
      final displayName =
          localName.isNotEmpty ? localName : 'Anonymous';

      final unameLower = localUsername.isNotEmpty
          ? FirestoreService.normalizeUsername(localUsername)
          : '';

      final searchTokens = FirestoreService.buildSearchTokens(
        displayName: displayName,
        username: unameLower,
      );

      await docRef.set(
        {
          'displayName': displayName,
          'displayNameLower': displayName.toLowerCase(),
          if (unameLower.isNotEmpty) 'username': unameLower,
          if (unameLower.isNotEmpty) 'usernameLower': unameLower,
          if (unameLower.isNotEmpty) 'searchTokens': searchTokens,

          if (localPhone.isNotEmpty) 'phoneE164': localPhone,
          'phoneDigits': localPhone.isNotEmpty ? _digitsOnly(localPhone) : null,
          'phoneVerified': AppStorage.isPhoneVerified(),

          // ✅ defaults
          'points': 0,
          'currentStreak': 0,
          'longestStreak': 0,
          'lastCompletedAt': null,

          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      return;
    }

    // Doc exists: only patch missing identity fields (don’t reset points/streaks)
    final data = snap.data() ?? <String, dynamic>{};

    final existingDisplay = (data['displayName'] ?? '').toString().trim();
    final existingUsername = (data['username'] ?? '').toString().trim();
    final existingPhone = (data['phoneE164'] ?? '').toString().trim();

    final displayToWrite = existingDisplay.isNotEmpty
        ? null
        : (localName.isNotEmpty ? localName : null);

    final unameToWrite = existingUsername.isNotEmpty
        ? null
        : (localUsername.isNotEmpty
            ? FirestoreService.normalizeUsername(localUsername)
            : null);

    final phoneToWrite =
        existingPhone.isNotEmpty ? null : (localPhone.isNotEmpty ? localPhone : null);

    // If we are writing any of displayName/username, recompute searchTokens
    final finalDisplayName =
        (displayToWrite ?? existingDisplay).trim();
    final finalUsernameLower = (unameToWrite ??
            (existingUsername.isNotEmpty
                ? FirestoreService.normalizeUsername(existingUsername)
                : ''))
        .trim();

    Map<String, dynamic> patch = {
      if (displayToWrite != null) 'displayName': displayToWrite,
      if (displayToWrite != null) 'displayNameLower': displayToWrite.toLowerCase(),

      if (unameToWrite != null) 'username': unameToWrite,
      if (unameToWrite != null) 'usernameLower': unameToWrite.toLowerCase(),

      if (phoneToWrite != null) 'phoneE164': phoneToWrite,
      if (phoneToWrite != null) 'phoneDigits': _digitsOnly(phoneToWrite),

      // keep verified in sync (safe)
      'phoneVerified': AppStorage.isPhoneVerified(),

      'updatedAt': FieldValue.serverTimestamp(),
    };

    final writingIndex = displayToWrite != null || unameToWrite != null;
    if (writingIndex && finalDisplayName.isNotEmpty) {
      patch['searchTokens'] = FirestoreService.buildSearchTokens(
        displayName: finalDisplayName,
        username: finalUsernameLower,
      );
    }

    patch = _compact(patch);

    if (patch.isEmpty) return;
    await docRef.set(patch, SetOptions(merge: true));
  }

  static Future<void> setUsernameOnUserDoc({
    required String username,
    String? displayNameForIndex, // optional: pass if you have it
  }) async {
    final uid = AuthService.uid;
    if (uid.isEmpty) return;

    final u = FirestoreService.normalizeUsername(username);

    // Grab displayName if caller didn't pass it (for searchTokens)
    String displayName = (displayNameForIndex ?? '').trim();
    if (displayName.isEmpty) {
      final snap = await _userDoc(uid).get();
      final data = snap.data() ?? <String, dynamic>{};
      displayName = (data['displayName'] ?? '').toString().trim();
    }

    final patch = _compact({
      'username': u,
      'usernameLower': u,
      if (displayName.isNotEmpty)
        'searchTokens': FirestoreService.buildSearchTokens(
          displayName: displayName,
          username: u,
        ),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _userDoc(uid).set(patch, SetOptions(merge: true));
  }

  static Future<void> setDisplayNameOnUserDoc({
    required String displayName,
    String? usernameForIndex, // optional: pass if you have it
  }) async {
    final uid = AuthService.uid;
    if (uid.isEmpty) return;

    // Grab username if caller didn't pass it (for searchTokens)
    String uname = (usernameForIndex ?? '').trim();
    if (uname.isEmpty) {
      final snap = await _userDoc(uid).get();
      final data = snap.data() ?? <String, dynamic>{};
      uname = (data['username'] ?? '').toString().trim();
    }
    final unameLower =
        uname.isNotEmpty ? FirestoreService.normalizeUsername(uname) : '';

    final patch = _compact({
      'displayName': displayName,
      'displayNameLower': displayName.toLowerCase(),
      if (unameLower.isNotEmpty)
        'searchTokens': FirestoreService.buildSearchTokens(
          displayName: displayName,
          username: unameLower,
        ),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _userDoc(uid).set(patch, SetOptions(merge: true));
  }

  static Future<void> setPhoneOnUserDoc({
    required String phoneE164,
    required bool verified,
  }) async {
    final uid = AuthService.uid;
    if (uid.isEmpty) return;

    await _userDoc(uid).set(
      _compact({
        'phoneE164': phoneE164,
        'phoneDigits': _digitsOnly(phoneE164),
        'phoneVerified': verified,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
      SetOptions(merge: true),
    );
  }
}
