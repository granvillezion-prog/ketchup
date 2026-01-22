import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final phoneCtrl = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> sendCode() async {
    final phone = phoneCtrl.text.trim();
    if (phone.isEmpty) return;

    setState(() {
      loading = true;
      error = null;
    });

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone, // must be like +1XXXXXXXXXX
      timeout: const Duration(seconds: 45),
      verificationCompleted: (cred) async {
        await FirebaseAuth.instance.signInWithCredential(cred);
        HapticFeedback.heavyImpact();
      },
      verificationFailed: (e) {
        setState(() {
          loading = false;
          error = e.message ?? "Failed to send code.";
        });
      },
      codeSent: (verificationId, resendToken) {
        setState(() => loading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpScreen(verificationId: verificationId),
          ),
        );
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Text(
                "KetchUp",
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              const Text(
                "Enter your phone number.\nWe’ll text you a code.",
                style: TextStyle(
                  fontSize: 14,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F6F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: "+1 555 123 4567",
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  error!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: loading ? null : sendCode,
                  child: Text(
                    loading ? "Sending..." : "Continue",
                    style: const TextStyle(fontWeight: FontWeight.w900),
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

class OtpScreen extends StatefulWidget {
  final String verificationId;
  const OtpScreen({super.key, required this.verificationId});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final codeCtrl = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    codeCtrl.dispose();
    super.dispose();
  }

  Future<void> verify() async {
    final code = codeCtrl.text.trim();
    if (code.length != 6) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: code,
      );
      await FirebaseAuth.instance.signInWithCredential(cred);
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() {
        loading = false;
        error = e.message ?? "Invalid code.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify")),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF6F6F6),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "6-digit code",
                  counterText: "",
                ),
                onChanged: (v) {
                  if (v.trim().length == 6) verify();
                },
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 14),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: loading ? null : verify,
                child: Text(
                  loading ? "Verifying..." : "Verify",
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
