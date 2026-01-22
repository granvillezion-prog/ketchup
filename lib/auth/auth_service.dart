import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> ensureSignedIn() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
  }

  static String get uid {
    final u = _auth.currentUser;
    if (u == null) {
      throw StateError("No Firebase user. Did you call ensureSignedIn()?");
    }
    return u.uid;
  }

  static String? get displayName => _auth.currentUser?.displayName;
}
