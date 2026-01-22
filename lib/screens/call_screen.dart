// lib/screens/call_screen.dart
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../storage.dart';
import '../theme/know_no_know_theme.dart';

class CallScreen extends StatefulWidget {
  final String hiddenName;
  final String phone;

  final VoidCallback onConnect;  // reveal happens when YOU join
  final VoidCallback onComplete; // parent navigates to reveal / refreshes Today

  const CallScreen({
    super.key,
    required this.hiddenName,
    required this.phone,
    required this.onConnect,
    required this.onComplete,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  static const int baseSeconds = AppState.baseCallSeconds; // 300
  static const int minSecondsBeforeEnd = 10;

  int remaining = baseSeconds;

  Timer? _timer;

  bool joined = false;
  bool extended = false;
  bool _firedConnect = false;

  // countdown state
  bool _countingDown = false;
  int _count = 3;
  Timer? _countTimer;

  String? _callError;

  @override
  void initState() {
    super.initState();
    _resumeIfNeeded();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countTimer?.cancel();
    super.dispose();
  }

  // ----------------------------
  // REAL CALL LAUNCH
  // ----------------------------

  String _sanitizePhone(String raw) {
    return raw.trim().replaceAll(RegExp(r'[^0-9+]'), '');
  }

  Future<void> _launchNativeCall() async {
    setState(() => _callError = null);

    final phone = _sanitizePhone(widget.phone);
    if (phone.isEmpty) {
      setState(() => _callError = "No phone number found for this person.");
      return;
    }

    // iOS prefers FaceTime, fallback to tel:
    if (Platform.isIOS) {
      final ft = Uri.parse('facetime:$phone');
      if (await canLaunchUrl(ft)) {
        final ok = await launchUrl(ft, mode: LaunchMode.externalApplication);
        if (!ok) setState(() => _callError = "Couldn’t open FaceTime.");
        return;
      }

      final tel = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(tel)) {
        final ok = await launchUrl(tel, mode: LaunchMode.externalApplication);
        if (!ok) setState(() => _callError = "Couldn’t open the Phone app.");
        return;
      }

      setState(() => _callError = "FaceTime/Phone not available on this device.");
      return;
    }

    // Android: tel:
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await canLaunchUrl(uri)) {
      setState(() => _callError = "Couldn’t open the dialer on this device.");
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) setState(() => _callError = "Couldn’t open the dialer.");
  }

  // ----------------------------
  // TIMER / RESUME
  // ----------------------------

  Future<void> _resumeIfNeeded() async {
    final r = AppState.getRemainingCallSeconds();
    if (r == null) return;

    final total = AppStorage.getCallTotalSeconds() ?? baseSeconds;

    // If timer already expired, finish immediately and return.
    if (r <= 0) {
      await _finishCall();
      return;
    }

    if (!mounted) return;
    setState(() {
      remaining = r;
      joined = true;
      extended = total > baseSeconds;
      _firedConnect = true; // already joined previously
    });

    _startTimerOnly();
  }

  void _startTimerOnly() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      final r = AppState.getRemainingCallSeconds();
      final total = AppStorage.getCallTotalSeconds() ?? baseSeconds;

      if (r == null) {
        // Shouldn’t happen often, but keep UI moving.
        setState(() => remaining = max(0, remaining - 1));
        if (remaining == 0) {
          scheduleMicrotask(_finishCall);
        }
        return;
      }

      setState(() {
        remaining = r;
        extended = total > baseSeconds;
      });

      if (r == 0) {
        scheduleMicrotask(_finishCall);
      }
    });
  }

  void _beginJoinFlow() {
    if (joined || _countingDown) return;

    setState(() {
      _countingDown = true;
      _count = 3;
      _callError = null;
    });

    _countTimer?.cancel();
    _countTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }

      setState(() => _count -= 1);

      if (_count <= 0) {
        t.cancel();
        if (!mounted) return;

        setState(() {
          _countingDown = false;
          joined = true;
        });

        _startCall();
      }
    });
  }

  Future<void> _startCall() async {
    // Persist timer start (only once)
    await AppState.setCallStartedNowIfEmpty();

    // Fire connect callback once (this is the “reveal when you join” moment)
    if (!_firedConnect) {
      _firedConnect = true;
      widget.onConnect();
    }

    // Launch native call UI
    await _launchNativeCall();

    final r = AppState.getRemainingCallSeconds() ?? baseSeconds;
    final total = AppStorage.getCallTotalSeconds() ?? baseSeconds;

    if (!mounted) return;
    setState(() {
      remaining = r;
      extended = total > baseSeconds;
    });

    _startTimerOnly();
  }

  Future<void> _extendCall() async {
    if (!joined || extended) return;

    await AppState.markExtendedOnce();

    final r = AppState.getRemainingCallSeconds();
    final total = AppStorage.getCallTotalSeconds() ?? baseSeconds;

    if (!mounted) return;
    setState(() {
      extended = total > baseSeconds;
      if (r != null) remaining = r;
    });
  }

  Future<void> _finishCall() async {
    _timer?.cancel();
    _countTimer?.cancel();

    // ✅ IMPORTANT:
    // AppState.markCallComplete() already:
    // - marks day complete + points/streak
    // - clears call timer
    // - advances (Plus) exactly once
    await AppState.markCallComplete();

    if (!mounted) return;
    widget.onComplete();
  }

  String _format(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  @override
  Widget build(BuildContext context) {
    final startedAt = AppStorage.getCallStartedAt();
    final elapsed = (startedAt == null)
        ? 0
        : ((DateTime.now().millisecondsSinceEpoch - startedAt) / 1000).floor();

    final canEnd = joined && elapsed >= minSecondsBeforeEnd;

    final statusLine = joined
        ? (extended ? "Extended • timer is live" : "Timer is live")
        : "Press JOIN to reveal + start 5:00";

    final countdownOverlay = _countingDown
        ? Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    KnowNoKnowTheme.primary,
                    Color(0xFF6A35D8),
                    Color(0xFF0B0B0C),
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _count > 0 ? _count.toString() : "GO",
                style: const TextStyle(
                  color: KnowNoKnowTheme.white,
                  fontSize: 120,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Know No Know',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: KnowNoKnowTheme.bgGradient),
        child: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: KnowNoKnowTheme.cardGradient,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: KnowNoKnowTheme.stroke,
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.10),
                            blurRadius: 26,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            joined ? "YOU'RE CALLING" : "MYSTERY CALL",
                            style: const TextStyle(
                              color: KnowNoKnowTheme.ink,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (joined) ...[
                            Text(
                              widget.hiddenName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: KnowNoKnowTheme.ink,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text(
                            _format(remaining),
                            style: const TextStyle(
                              color: KnowNoKnowTheme.ink,
                              fontSize: 46,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            statusLine,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: KnowNoKnowTheme.mutedInk,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (_callError != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: KnowNoKnowTheme.panel,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: KnowNoKnowTheme.stroke,
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                _callError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: KnowNoKnowTheme.mutedInk,
                                  fontWeight: FontWeight.w900,
                                  height: 1.15,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF0B0B0C),
                              Color(0xFF141417),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: KnowNoKnowTheme.stroke,
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.10),
                              blurRadius: 22,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            joined
                                ? "CALL OPENED\n(Phone / FaceTime)\nTimer continues here."
                                : "JOIN starts the call + timer.",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: (joined || _countingDown) ? null : _beginJoinFlow,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: (joined || _countingDown)
                                    ? KnowNoKnowTheme.stroke
                                    : KnowNoKnowTheme.ink,
                                foregroundColor: KnowNoKnowTheme.white,
                              ),
                              child: Text(
                                joined ? "JOINED" : (_countingDown ? "..." : "JOIN"),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: (!joined || extended) ? null : _extendCall,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: KnowNoKnowTheme.primary,
                                foregroundColor: KnowNoKnowTheme.white,
                              ),
                              child: Text(
                                extended ? "EXTENDED" : "EXTEND +5",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: canEnd ? _finishCall : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canEnd ? KnowNoKnowTheme.white : KnowNoKnowTheme.stroke,
                          foregroundColor: canEnd ? KnowNoKnowTheme.ink : KnowNoKnowTheme.mutedInk,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: canEnd ? KnowNoKnowTheme.ink : Colors.transparent,
                              width: 1.2,
                            ),
                          ),
                        ),
                        child: const Text(
                          "END CALL",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      canEnd ? "You can end now." : "Let it run a moment before ending.",
                      style: const TextStyle(
                        color: KnowNoKnowTheme.mutedInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              countdownOverlay,
            ],
          ),
        ),
      ),
    );
  }
}
