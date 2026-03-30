// lib/screens/login_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_router.dart';
import '../storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _sendingCode = false;
  bool _verifyingCode = false;
  bool _codeSent = false;

  String? _verificationId;
  int? _resendToken;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _usernameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  String _toE164(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 10) return '+1$digits';
    if (digits.length == 11 && digits.startsWith('1')) return '+$digits';
    if (raw.trim().startsWith('+')) return raw.trim();
    return '+$digits';
  }

  String _normalizeUsername(String raw) {
    var v = raw.trim().toLowerCase();
    if (v.startsWith('@')) v = v.substring(1);
    return v;
  }

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _sendingCode = true;
      _error = null;
    });

    final phone = _toE164(_phoneCtrl.text);
    final username = _normalizeUsername(_usernameCtrl.text);

    if (phone.length < 12) {
      setState(() {
        _sendingCode = false;
        _error = 'Enter a valid phone number.';
      });
      return;
    }

    if (username.isEmpty) {
      setState(() {
        _sendingCode = false;
        _error = 'Enter your username.';
      });
      return;
    }

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: _resendToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);
          await _finishLogin();
        } catch (e) {
          if (!mounted) return;
          setState(() => _error = 'Auto-verification failed: $e');
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() {
          _sendingCode = false;
          _error = e.message ?? 'Could not send verification code.';
        });
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() {
          _sendingCode = false;
          _codeSent = true;
          _verificationId = verificationId;
          _resendToken = resendToken;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _verifyCode() async {
    FocusScope.of(context).unfocus();
    final verificationId = _verificationId;
    final code = _codeCtrl.text.trim();

    if (verificationId == null || code.length < 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }

    setState(() {
      _verifyingCode = true;
      _error = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      await _finishLogin();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _verifyingCode = false;
        _error = e.message ?? 'Invalid verification code.';
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifyingCode = false;
        _error = 'Verification failed: $e';
      });
      return;
    }

    if (!mounted) return;
    setState(() => _verifyingCode = false);
  }

  Future<void> _finishLogin() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final enteredUsername = _normalizeUsername(_usernameCtrl.text);

    if (currentUser == null) {
      throw Exception('No authenticated user found.');
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    final data = doc.data();
    final storedUsername =
        ((data?['usernameLower'] ?? data?['username'] ?? '') as String)
            .trim()
            .toLowerCase();

    if (storedUsername.isEmpty || storedUsername != enteredUsername) {
      await FirebaseAuth.instance.signOut();
      throw Exception('That username does not match this phone number.');
    }

    await AppStorage.setAuthed(true);

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRouter.today,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _sendingCode || _verifyingCode;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Log In'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _codeSent
                    ? 'Enter the code we sent to your phone.'
                    : 'Enter your phone number and username.',
                style: TextStyle(
                  color: Colors.black.withOpacity(0.65),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                enabled: !busy,
                decoration: InputDecoration(
                  labelText: 'Phone number',
                  hintText: '(555) 555-5555',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _usernameCtrl,
                enabled: !busy && !_codeSent,
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: '@yourname',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (_codeSent)
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: 'Verification code',
                    hintText: '123456',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: busy ? null : (_codeSent ? _verifyCode : _sendCode),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    _sendingCode
                        ? 'Sending...'
                        : _verifyingCode
                            ? 'Verifying...'
                            : _codeSent
                                ? 'Verify Code'
                                : 'Send Code',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}