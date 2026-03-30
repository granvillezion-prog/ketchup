import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_router.dart';
import '../services/firestore_service.dart';
import '../services/username_service.dart';
import '../storage.dart';
import '../theme/know_no_know_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _first;

  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser == null) {
        Navigator.pushReplacementNamed(context, AppRouter.auth);
      }
    });

    final existingName = AppStorage.getProfileName().trim();
    String first = '';

    if (existingName.isNotEmpty) {
      final parts = existingName
          .split(RegExp(r'\s+'))
          .where((p) => p.trim().isNotEmpty)
          .toList();
      if (parts.isNotEmpty) first = parts.first;
    }

    _first = TextEditingController(text: first);
  }

  @override
  void dispose() {
    _first.dispose();
    super.dispose();
  }

  bool get _ok => _first.text.trim().isNotEmpty;

  String _lettersDigitsOnly(String s) =>
      s.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();

  String _makeBase(String first) {
    final clean = _lettersDigitsOnly(first);
    if (clean.length >= 3) return clean;
    if (clean.isNotEmpty) return '${clean}user';
    return 'user';
  }

  String _makeCandidate(String base) {
    final r = Random();
    final trimmedBase = base.length > 12 ? base.substring(0, 12) : base;
    final digits = (1000 + r.nextInt(9000)).toString();
    return '$trimmedBase$digits';
  }

  Future<String> _claimUsernameSilently({
    required String first,
    required String displayName,
  }) async {
    final base = _makeBase(first);

    for (var i = 0; i < 12; i++) {
      final candidate = UsernameService.normalize(_makeCandidate(base));
      final reason = UsernameService.validate(candidate);
      if (reason != null) continue;

      try {
        await UsernameService.claimUsername(
          username: candidate,
          displayName: displayName,
        );
        return candidate;
      } on StateError {
        continue;
      } on FirebaseException {
        continue;
      }
    }

    throw StateError('Could not generate a username.');
  }

  Future<void> _continue() async {
    final first = _first.text.trim();
    final displayName = first;

    if (first.isEmpty) {
      setState(() => _error = 'Enter your first name');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? '';
      if (uid.isEmpty) throw StateError('Not signed in.');

      await AppStorage.setProfile(name: displayName);

      final fs = FirestoreService(uid);
      await fs.setDisplayName(displayName: displayName);

      await user!.updateDisplayName(displayName);
      await user.reload();

      final existingUsername = AppStorage.getUsername().trim();
      if (existingUsername.isEmpty) {
        final username = await _claimUsernameSilently(
          first: first,
          displayName: displayName,
        );
        await AppStorage.setUsername(username);
      }

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRouter.today,
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('StateError: ', ''));
    } finally {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ok = _ok;

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
              const SizedBox(height: 18),
              const Text(
                'What should we call you?',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This is what your friends will see.',
                style: TextStyle(
                  color: Colors.black.withOpacity(0.55),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 28),
              const _FieldLabel('First name'),
              const SizedBox(height: 10),
              _WhiteField(
                controller: _first,
                hint: 'First name',
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) {
                  if (!_saving && ok) _continue();
                },
              ),
              const Spacer(),
              if (_error != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: (_saving || !ok) ? null : _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KnowNoKnowTheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        KnowNoKnowTheme.primary.withOpacity(0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _saving ? 'Please wait…' : 'Continue',
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.w900,
        fontSize: 16,
      ),
    );
  }
}

class _WhiteField extends StatelessWidget {
  const _WhiteField({
    required this.controller,
    required this.hint,
    required this.textInputAction,
    required this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputAction textInputAction;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      style: const TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.w900,
        fontSize: 18,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.black.withOpacity(0.35),
          fontWeight: FontWeight.w800,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: KnowNoKnowTheme.primary.withOpacity(0.9),
          ),
        ),
      ),
    );
  }
}