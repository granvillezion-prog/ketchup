import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../app_router.dart';
import '../services/user_service.dart';
import '../storage.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  static const Color _oauthBtn = Color(0xFFFFFFFF);
  static const Color _oauthStroke = Color(0x1A000000);
  static const Color _phoneBtn = Color(0xFF4dff00);
  static const Color _appleBtn = Color(0xFF000000);

  Future<void> _postAuthContinue(BuildContext context) async {
    await UserService.ensureUserDoc();
    await AppStorage.setAuthed(true);
    if (!context.mounted) return;

    final nextRoute = !AppStorage.isProfileComplete()
        ? AppRouter.profile
        : AppRouter.today;

    Navigator.pushNamedAndRemoveUntil(context, nextRoute, (_) => false);
  }

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final googleUser = await GoogleSignIn(scopes: const ['email']).signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      await _postAuthContinue(context);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google sign-in failed')),
      );
    }
  }

  Future<void> _signInWithApple(BuildContext context) async {
    try {
      if (!Platform.isIOS && !Platform.isMacOS) return;

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final provider = OAuthProvider('apple.com');
      final credential = provider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      await _postAuthContinue(context);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apple sign-in failed')),
      );
    }
  }

  void _goPhone(BuildContext context) {
    Navigator.pushNamed(context, AppRouter.phone);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/today_screen4.jpg',
                fit: BoxFit.cover,
              ),
            ),

            Positioned(
              top: 240,
              right: (MediaQuery.of(context).size.width - 320) / 2 + 20,
              child: Image.asset(
                'assets/logo2.jpg',
                height: 140,
                fit: BoxFit.contain,
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  const SizedBox(height: 250),

                  Column(
                    children: [
                      _buttonWrapper(
                        ElevatedButton(
                          onPressed: () => _goPhone(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _phoneBtn,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40),
                            ),
                          ),
                          child: const Text(
                            'Continue with phone',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buttonWrapper(
                        OutlinedButton(
                          onPressed: () => _signInWithGoogle(context),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _oauthBtn,
                            foregroundColor: Colors.black,
                            side: const BorderSide(color: _oauthStroke),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.g_mobiledata_rounded, size: 34),
                              SizedBox(width: 6),
                              Text(
                                'Continue with Google',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buttonWrapper(
                        OutlinedButton(
                          onPressed: () => _signInWithApple(context),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _appleBtn,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.apple, size: 36, color: Colors.white),
                              SizedBox(width: 12),
                              Text(
                                'Continue with Apple',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 80),

                  Column(
                    children: const [
                      Text(
                        'You know your friends. You don’t know which one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'One Mystery Friend a Day',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '5-minute timed calls',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 3),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buttonWrapper(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: SizedBox(
          height: 60,
          width: double.infinity,
          child: child,
        ),
      ),
    );
  }
}