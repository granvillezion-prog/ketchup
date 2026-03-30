import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_router.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Future<void>? _future;

  @override
  void initState() {
    super.initState();
    _future = _signInAnon();
  }

  Future<void> _signInAnon() async {
    final auth = FirebaseAuth.instance;

    if (auth.currentUser != null) {
      debugPrint('[AUTH] already signed in uid=${auth.currentUser!.uid}');
      return;
    }

    debugPrint('[AUTH] signInAnonymously...');
    await auth.signInAnonymously().timeout(const Duration(seconds: 12));
    debugPrint('[AUTH] signInAnonymously OK uid=${auth.currentUser?.uid}');
  }

  void _retry() {
    setState(() {
      _future = _signInAnon();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snap.hasError) {
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'AUTH FAILED',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        snap.error.toString(),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: _retry,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // ✅ Success -> render splash gate widget directly (no Navigator in build)
        return AppRouter.buildSplash();
      },
    );
  }
}
