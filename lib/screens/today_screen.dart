// lib/screens/today_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../app_router.dart';
import '../app_state.dart';
import '../models.dart';
import '../storage.dart';
import '../theme/know_no_know_theme.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen>
    with SingleTickerProviderStateMixin {
  MockPair? _pair;

  Timer? _ticker;
  int? _remainingCallSeconds;
  String _nextDropText = "";

  late final AnimationController _mysteryCtrl;

  @override
  void initState() {
    super.initState();
    _mysteryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _load();
    _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _mysteryCtrl.dispose();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();

    _remainingCallSeconds = AppState.getRemainingCallSeconds();
    _nextDropText = _computeNextDropText();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      final nextRem = AppState.getRemainingCallSeconds();
      final nextDrop = _computeNextDropText();

      if (nextRem != _remainingCallSeconds || nextDrop != _nextDropText) {
        setState(() {
          _remainingCallSeconds = nextRem;
          _nextDropText = nextDrop;
        });
      }
    });
  }

  String _formatClock(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  String _computeNextDropText() {
    final now = DateTime.now();
    final nextMidnight =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final diff = nextMidnight.difference(now);

    final h = diff.inHours;
    final m = diff.inMinutes % 60;

    if (h <= 0 && m <= 0) return "soon";
    if (h == 0) return "${m}m";
    return "${h}h ${m}m";
  }

  Future<void> _load() async {
    // ✅ IMPORTANT CHANGE:
    // Do NOT block on AppStorage.getCircle(). This is legacy/local fallback.
    // Firestore circles are the real source now, and this check can falsely redirect.
    final p = await AppState.ensureTodayPair();
    if (!mounted) return;

    setState(() {
      _pair = p;
      _remainingCallSeconds = AppState.getRemainingCallSeconds();
      _nextDropText = _computeNextDropText();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pair = _pair;
    final name = AppStorage.getProfileName();

    if (pair == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'TODAY',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(gradient: KnowNoKnowTheme.bgGradient),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final questionText = (pair.questionText.isNotEmpty)
        ? pair.questionText
        : AppState.getQuestionById(pair.questionId).text;

    final clueText = (pair.answerText.isNotEmpty) ? pair.answerText : "…";

    final rem = _remainingCallSeconds;
    final hasActiveCall = rem != null && rem > 0;

    final headline =
        pair.callCompleted ? "Completed" : (hasActiveCall ? "In progress" : "Ready");

    final rightMeta = pair.callCompleted ? "NEXT • $_nextDropText" : "";

    final subline = pair.callCompleted
        ? "Next drop in $_nextDropText"
        : (hasActiveCall
            ? "Timer is running — jump back in."
            : "One mystery call. Timed. Reveal after.");

    final primaryCtaLabel = pair.callCompleted
        ? "OPEN REVEAL"
        : (hasActiveCall ? "RESUME • ${_formatClock(rem!)}" : "JOIN • 5:00");

    final primaryCtaSub = pair.callCompleted
        ? "See who it was"
        : (hasActiveCall ? "Keep it alive" : "You won’t know who it is until you join");

    final callsPill = "CALLS ${pair.callIndex}/${pair.totalCalls}";

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'TODAY',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, AppRouter.plus),
            icon: const Icon(Icons.star_rounded),
            tooltip: "Plus",
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, AppRouter.settings),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: KnowNoKnowTheme.bgGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yo $name 👋',
                  style: const TextStyle(
                    color: KnowNoKnowTheme.ink,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                _MetaRow(left: headline, right: rightMeta),
                const SizedBox(height: 6),
                Text(
                  subline,
                  style: const TextStyle(
                    color: KnowNoKnowTheme.mutedInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _Pill(text: "⭐ ${pair.points}", filled: true),
                    const SizedBox(width: 10),
                    _Pill(text: "🔥 ${pair.currentStreak}", filled: true),
                    const Spacer(),
                    _Pill(text: callsPill, filled: false),
                  ],
                ),
                const SizedBox(height: 14),

                // CLUE card: one signature “mystery” detail
                _MysterySweepCard(
                  controller: _mysteryCtrl,
                  child: _HeroCard(
                    eyebrow: "THE CLUE",
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "“$clueText”",
                          style: const TextStyle(
                            color: KnowNoKnowTheme.ink,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: KnowNoKnowTheme.stroke,
                                  width: 1.2,
                                ),
                                color: Colors.transparent,
                              ),
                              child: const Text(
                                "PROMPT",
                                style: TextStyle(
                                  color: KnowNoKnowTheme.mutedInk,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                questionText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: KnowNoKnowTheme.mutedInk,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    onPressed: () async {
                      await Navigator.pushNamed(
                        context,
                        pair.callCompleted ? AppRouter.reveal : AppRouter.call,
                      );
                      await _load();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KnowNoKnowTheme.ink,
                      foregroundColor: KnowNoKnowTheme.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(KnowNoKnowTheme.rBtn),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          primaryCtaLabel,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          primaryCtaSub,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------------- UI bits ---------------- */

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.left, required this.right});
  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          left,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: KnowNoKnowTheme.ink,
          ),
        ),
        const Spacer(),
        if (right.isNotEmpty)
          Text(
            right,
            style: const TextStyle(
              color: KnowNoKnowTheme.mutedInk,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.eyebrow, required this.child});
  final String eyebrow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: KnowNoKnowTheme.cardGradient,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: KnowNoKnowTheme.stroke, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 22,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: KnowNoKnowTheme.mutedInk,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.filled});
  final String text;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? KnowNoKnowTheme.pillFill : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: KnowNoKnowTheme.stroke, width: 1.2),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: filled ? KnowNoKnowTheme.pillFillText : KnowNoKnowTheme.ink,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MysterySweepCard extends StatelessWidget {
  const _MysterySweepCard({
    required this.controller,
    required this.child,
  });

  final AnimationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return CustomPaint(
          painter: _MysterySweepPainter(t: controller.value),
          child: child,
        );
      },
    );
  }
}

class _MysterySweepPainter extends CustomPainter {
  _MysterySweepPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const r = 26.0;
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(r));

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = KnowNoKnowTheme.stroke;

    canvas.drawRRect(rr, basePaint);

    final sweep = SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      colors: [
        Colors.transparent,
        KnowNoKnowTheme.primary.withOpacity(0.22),
        Colors.transparent,
      ],
      stops: const [0.0, 0.12, 0.22],
      transform: GradientRotation(t * math.pi * 2),
    );

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..shader = sweep.createShader(rect);

    final inflate = rect.inflate(0.8);
    final rr2 = RRect.fromRectAndRadius(
      inflate,
      const Radius.circular(r + 0.8),
    );
    canvas.drawRRect(rr2, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _MysterySweepPainter oldDelegate) {
    return oldDelegate.t != t;
  }
}
