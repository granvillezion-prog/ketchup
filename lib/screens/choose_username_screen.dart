// lib/screens/choose_username_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../storage.dart';
import '../app_router.dart';
import '../services/username_service.dart';

class ChooseUsernameScreen extends StatefulWidget {
  const ChooseUsernameScreen({super.key});

  @override
  State<ChooseUsernameScreen> createState() => _ChooseUsernameScreenState();
}

class _ChooseUsernameScreenState extends State<ChooseUsernameScreen> {
  final _ctrl = TextEditingController();

  bool _saving = false;
  bool _editing = false;
  String? _error;

  String _suggested = '';

  // Passed from ProfileScreen
  String _firstArg = '';
  String _lastArg = '';

  Color get _primary => Theme.of(context).colorScheme.primary;

  String _lettersDigitsOnly(String s) =>
      s.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();

  // ✅ Base MUST come from first + last they entered on the previous screen.
  String _baseFromArgs() {
    final first = _lettersDigitsOnly(_firstArg);
    final last = _lettersDigitsOnly(_lastArg);

    final combined = '$first$last'; // e.g. ziongranville

    // UsernameService: 3–16 chars
    if (combined.length >= 3) return combined;
    if (first.length >= 3) return first;

    // If they typed something extremely short/empty, hard fallback
    return 'user';
  }

  // ✅ Suggestion = base + 4 digits; keep <= 16 total chars.
  String _makeSuggestion(String base) {
    final r = Random();
    final trimmedBase = base.length > 12 ? base.substring(0, 12) : base;
    final digits = (1000 + r.nextInt(9000)).toString(); // 4 digits
    return (trimmedBase + digits).toLowerCase();
  }

  void _setSuggested(String value) {
    _suggested = UsernameService.normalize(value);
    _ctrl.text = _suggested;
  }

  void _initFromRouteArgsIfNeeded() {
    final saved = AppStorage.getUsername().trim();
    if (saved.isNotEmpty) {
      _setSuggested(saved);
      _editing = false;
      return;
    }

    // Grab args from ProfileScreen
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _firstArg = (args['first'] ?? '').toString();
      _lastArg = (args['last'] ?? '').toString();
    }

    final base = _baseFromArgs();
    _setSuggested(_makeSuggestion(base));
    _editing = false;
  }

  @override
  void initState() {
    super.initState();

    // ✅ If user is coming here, they haven't completed Add Friends yet.
    AppStorage.setAddFriendsDone(false);

    // IMPORTANT: Route arguments require context -> read after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(_initFromRouteArgsIfNeeded);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() {
      _editing = true;
      _error = null;
      _ctrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _ctrl.text.length),
      );
    });
  }

  void _useSuggested() {
    setState(() {
      _ctrl.text = _suggested;
      _editing = false;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_saving) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _error = "Not signed in.");
      return;
    }

    final username = UsernameService.normalize(_ctrl.text);
    final reason = UsernameService.validate(username);
    setState(() => _error = reason);
    if (reason != null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // Use stored profile name if available (nice for display), but username itself
      // is already derived from the route args above.
      final displayName = AppStorage.getProfileName().trim().isNotEmpty
          ? AppStorage.getProfileName().trim()
          : ((user.displayName ?? '').trim().isNotEmpty
              ? (user.displayName ?? '').trim()
              : 'User');

      await UsernameService.claimUsername(
        username: username,
        displayName: displayName,
      );

      await AppStorage.setUsername(username);

      if (!mounted) return;

      Navigator.pushReplacementNamed(context, AppRouter.contacts);
    } on StateError catch (e) {
      setState(() => _error = e.message);
    } on FirebaseException catch (e, st) {
      debugPrint("FIREBASE USERNAME ERROR: ${e.code} ${e.message}");
      debugPrintStack(stackTrace: st);
      setState(() => _error = "${e.code}: ${e.message ?? ''}".trim());
    } catch (e, st) {
      debugPrint("USERNAME ERROR: $e");
      debugPrintStack(stackTrace: st);
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = UsernameService.normalize(_ctrl.text);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: _saving ? null : () => Navigator.maybePop(context),
        ),
        centerTitle: true,
        title: const Text(
          "Create account",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Step 3 of 5",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF9AA0A6),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 36),
              const Text(
                "Your username is",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                shown,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w900,
                  fontSize: 38,
                ),
              ),
              const SizedBox(height: 12),
              if (!_editing) ...[
                TextButton(
                  onPressed: _saving ? null : _toggleEdit,
                  style: TextButton.styleFrom(
                    foregroundColor: _primary,
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  child: const Text("Change my username"),
                ),
              ] else ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _ctrl,
                  enabled: !_saving,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    prefixText: "@",
                    prefixStyle: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w800,
                    ),
                    hintText: "yourname",
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    errorText: _error,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _saving ? null : _useSuggested,
                    style: TextButton.styleFrom(
                      foregroundColor: _primary,
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    child: const Text("Use suggested"),
                  ),
                ),
              ],
              if (!_editing && _error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Continue"),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}