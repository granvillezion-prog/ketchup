import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  /// Ensures request.auth is not null for Firestore rules.
  /// MVP: anonymous auth (upgrade to phone auth later).
  static Future<void> ensureSignedIn() async {
    final user = _auth.currentUser;
    if (user != null) return;

    await _auth.signInAnonymously();

    // Optional sanity log
    // ignore: avoid_print
    print("✅ Signed in anonymously: ${_auth.currentUser?.uid}");
  }

  static String get uid {
    final u = _auth.currentUser;
    if (u == null) {
      throw StateError("No Firebase user. Did you call ensureSignedIn()?");
    }
    return u.uid;
  }

  static User? get currentUser => _auth.currentUser;
}
