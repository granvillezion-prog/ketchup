import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'screens/circle_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<void> _signInAnon() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null) return;
    await auth.signInAnonymously();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _signInAnon(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const CircleScreen();
      },
    );
  }
}

