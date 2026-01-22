// lib/screens/reveal_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../app_router.dart';
import '../app_state.dart';
import '../storage.dart';
import '../theme/know_no_know_theme.dart';

class RevealScreen extends StatefulWidget {
  const RevealScreen({super.key});

  @override
  State<RevealScreen> createState() => _RevealScreenState();
}

class _RevealScreenState extends State<RevealScreen> {
  bool revealed = false;

  @override
  void initState() {
    super.initState();

    final pair = AppStorage.getTodayPair();
    if (pair == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRouter.today,
          (r) => false,
        );
      });
      return;
    }

    // ✅ Option C safety: if call timer expired or day is completed, clear call state.
    Future.microtask(() async {
      final remaining = AppState.getRemainingCallSeconds(); // null if never started
      final shouldClear = pair.callCompleted || (remaining != null && remaining <= 0);
      if (shouldClear) {
        await AppState.clearCallStarted(); // clears startedAt + totalSeconds
      }
    });

    // suspense beat, then reveal
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => revealed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pair = AppStorage.getTodayPair();

    if (pair == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(gradient: KnowNoKnowTheme.bgGradient),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final revealedName = pair.hiddenName;

    // ✅ Use the SAME stored fields as TodayScreen (pair is the source of truth)
    final questionText = pair.questionText.isNotEmpty ? pair.questionText : "…";
    final answerText = pair.answerText.isNotEmpty ? pair.answerText : "…";

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          "RECAP",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: KnowNoKnowTheme.bgGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "You just talked to…",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: KnowNoKnowTheme.ink,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                const SizedBox(height: 12),

                _RevealCard(
                  revealed: revealed,
                  revealedName: revealedName,
                  completed: pair.callCompleted,
                  points: pair.points,
                  currentStreak: pair.currentStreak,
                  longestStreak: pair.longestStreak,
                  answerText: answerText,
                  questionText: questionText,
                )
                    .animate()
                    .fadeIn(duration: 180.ms)
                    .moveY(begin: 10, end: 0, duration: 220.ms),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRouter.today,
                        (r) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KnowNoKnowTheme.ink,
                      foregroundColor: KnowNoKnowTheme.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      "BACK TO TODAY",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 200.ms, delay: 150.ms)
                    .moveY(begin: 12, end: 0, duration: 220.ms),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RevealCard extends StatelessWidget {
  const _RevealCard({
    required this.revealed,
    required this.revealedName,
    required this.completed,
    required this.points,
    required this.currentStreak,
    required this.longestStreak,
    required this.answerText,
    required this.questionText,
  });

  final bool revealed;
  final String revealedName;

  final bool completed;
  final int points;
  final int currentStreak;
  final int longestStreak;

  final String answerText;
  final String questionText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: KnowNoKnowTheme.cardGradient,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: KnowNoKnowTheme.stroke, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _Pill(
                text: revealed ? "IDENTIFIED" : "CLASSIFIED",
                filled: true,
              ),
              const SizedBox(width: 10),
              _Pill(
                text: completed ? "COMPLETED" : "INCOMPLETE",
                filled: false,
              ),
              const Spacer(),
              Icon(
                revealed ? Icons.lock_open_rounded : Icons.lock_rounded,
                color: KnowNoKnowTheme.ink,
              ),
            ],
          ),

          const SizedBox(height: 16),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: revealed
                ? _RevealedName(name: revealedName, key: const ValueKey("revealed"))
                : _BlurredPlaceholder(key: const ValueKey("blurred")),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(child: _StatBox(label: "SCORE", value: "$points")),
              const SizedBox(width: 10),
              Expanded(child: _StatBox(label: "STREAK", value: "$currentStreak")),
              const SizedBox(width: 10),
              Expanded(child: _StatBox(label: "BEST", value: "$longestStreak")),
            ],
          ),

          const SizedBox(height: 14),

          // ✅ The "receipt": show what you saw + the prompt (same as Today)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: KnowNoKnowTheme.panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: KnowNoKnowTheme.stroke, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "THE CLUE",
                  style: TextStyle(
                    color: KnowNoKnowTheme.mutedInk,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.9,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "“$answerText”",
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    color: KnowNoKnowTheme.ink,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Prompt: $questionText",
                  style: const TextStyle(
                    color: KnowNoKnowTheme.mutedInk,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: KnowNoKnowTheme.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KnowNoKnowTheme.stroke, width: 1.2),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: KnowNoKnowTheme.mutedInk,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: KnowNoKnowTheme.ink,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurredPlaceholder extends StatelessWidget {
  const _BlurredPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          "IDENTITY REDACTED",
          style: TextStyle(
            color: KnowNoKnowTheme.ink,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              Container(
                height: 70,
                width: double.infinity,
                color: KnowNoKnowTheme.panel,
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(color: Colors.transparent),
                ),
              ),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: KnowNoKnowTheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    "… … …",
                    style: TextStyle(
                      color: KnowNoKnowTheme.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 120.ms);
  }
}

class _RevealedName extends StatelessWidget {
  const _RevealedName({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          "REVEALED",
          style: TextStyle(
            color: KnowNoKnowTheme.ink,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: KnowNoKnowTheme.ink,
            fontSize: 42,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            height: 1.0,
          ),
        )
            .animate()
            .fadeIn(duration: 160.ms)
            .moveY(begin: 10, end: 0, duration: 220.ms)
            .scaleXY(begin: 0.98, end: 1.0, duration: 220.ms),
      ],
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
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
