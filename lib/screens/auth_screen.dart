// lib/screens/auth_screen.dart
import 'package:flutter/material.dart';
import '../app_router.dart';
import '../storage.dart';
import '../theme/know_no_know_theme.dart';
import '../app_state.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // ✅ keep consistent with theme gradient
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(gradient: KnowNoKnowTheme.bgGradient),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 26),

                // Logo / brand lockup
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: KnowNoKnowTheme.cardGradient,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: KnowNoKnowTheme.stroke, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 26,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.call_rounded, color: KnowNoKnowTheme.primary),
                      SizedBox(width: 10),
                      Text(
                        "Know No Know",
                        style: TextStyle(
                          color: KnowNoKnowTheme.ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  "One mystery call a day.",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: KnowNoKnowTheme.ink,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Keep friendships alive — without the 2-hour convo.",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: KnowNoKnowTheme.mutedInk,
                        fontWeight: FontWeight.w900,
                      ),
                ),

                const SizedBox(height: 18),

                // Feature bullets
                const _FeatureCard(
                  title: "HOW IT WORKS",
                  bullets: [
                    "Pick your people.",
                    "You get 1 random pairing each day.",
                    "You don’t know who it is until you JOIN.",
                    "5 minutes — extend +5 once.",
                  ],
                ),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () async {
                      await AppStorage.setAuthed(true);
                      if (!context.mounted) return;
                      Navigator.pushReplacementNamed(context, AppRouter.profile);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KnowNoKnowTheme.ink,
                      foregroundColor: KnowNoKnowTheme.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      "CONTINUE",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Center(
                  child: TextButton(
                    onPressed: () async {
                      // ✅ dev reset should also clear in-progress call timer (Option C)
                      await AppState.clearCallStarted();

                      await AppStorage.setAuthed(false);
                      await AppStorage.setProfile(name: '');
                      await AppStorage.setCircle([]);
                      await AppStorage.clearTodayPair();

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Local data reset.")),
                      );
                    },
                    child: const Text(
                      "Dev: reset local data",
                      style: TextStyle(
                        color: KnowNoKnowTheme.mutedInk,
                        fontWeight: FontWeight.w900,
                      ),
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

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.title, required this.bullets});

  final String title;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: KnowNoKnowTheme.cardGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: KnowNoKnowTheme.stroke, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 26,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: KnowNoKnowTheme.mutedInk,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
          ),
          const SizedBox(height: 10),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: KnowNoKnowTheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(
                        color: KnowNoKnowTheme.ink,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
