import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_router.dart';
import '../storage.dart';
import '../theme/know_no_know_theme.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _phoneCtrl = TextEditingController();
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

  Future<void> _routeAfterPhoneSuccess(String phone) async {
    await AppStorage.setAuthed(true);
    await AppStorage.setPhone(e164: phone, verified: true);

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRouter.profile,
      (_) => false,
    );
  }

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _sendingCode = true;
      _error = null;
    });

    final phone = _toE164(_phoneCtrl.text);
    if (phone.length < 12) {
      setState(() {
        _sendingCode = false;
        _error = 'Enter a valid phone number';
      });
      return;
    }

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: _resendToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        await _routeAfterPhoneSuccess(phone);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() {
          _sendingCode = false;
          _error = e.message ?? 'Failed to send code';
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
    final verificationId = _verificationId;
    final code = _codeCtrl.text.trim();

    if (verificationId == null || code.length < 6) {
      setState(() => _error = 'Enter the 6-digit code');
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
      await _routeAfterPhoneSuccess(_toE164(_phoneCtrl.text));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifyingCode = false;
        _error = 'Invalid code';
      });
    }
  }

  bool get _phoneOk => _toE164(_phoneCtrl.text).length >= 12;
  bool get _codeOk => _codeCtrl.text.trim().length >= 6;
  bool get _ctaEnabled =>
      !_sendingCode &&
      !_verifyingCode &&
      (_codeSent ? _codeOk : _phoneOk);

  @override
  Widget build(BuildContext context) {
    final busy = _sendingCode || _verifyingCode;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: Colors.black,
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Create account',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                _codeSent ? 'Confirm your number' : 'Use your phone number',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _codeSent
                    ? 'Enter the 6-digit code we sent you.'
                    : 'We’ll text you a code to get started.',
                style: TextStyle(
                  color: Colors.black.withOpacity(0.55),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 28),
              const _Label('Phone number'),
              const SizedBox(height: 8),
              _InputField(
                controller: _phoneCtrl,
                hint: '(555) 555-5555',
                enabled: !busy,
                onChanged: (_) => setState(() {}),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 20),
                const _Label('Verification code'),
                const SizedBox(height: 8),
                _InputField(
                  controller: _codeCtrl,
                  hint: '123456',
                  enabled: !busy,
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const Spacer(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: _ctaEnabled
                      ? (_codeSent ? _verifyCode : _sendCode)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KnowNoKnowTheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        KnowNoKnowTheme.primary.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(
                    _codeSent
                        ? (_verifyingCode ? 'Please wait…' : 'Continue')
                        : (_sendingCode ? 'Please wait…' : 'Send code'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
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

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 16,
        color: Colors.black,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 18,
        color: Colors.black,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.black.withOpacity(0.3),
          fontWeight: FontWeight.w800,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}