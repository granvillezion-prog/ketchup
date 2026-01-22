// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';

import '../app_router.dart';
import '../app_state.dart';
import '../storage.dart';
import '../theme/know_no_know_theme.dart';

// ✅ NEW: simple local/dev subscription flag (we’ll create this file next)
import '../subscription.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _plus = false;

  @override
  void initState() {
    super.initState();
    _plus = Subscription.isPlus();
  }

  @override
  Widget build(BuildContext context) {
    final name = AppStorage.getProfileName();
    final pair = AppStorage.getTodayPair();

    final points = pair?.points ?? 0;
    final streak = pair?.currentStreak ?? 0;
    final best = pair?.longestStreak ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          "SETTINGS",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: KnowNoKnowTheme.bgGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ACCOUNT",
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: KnowNoKnowTheme.mutedInk,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        name.isEmpty ? "Signed in" : "Signed in as: $name",
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: KnowNoKnowTheme.ink,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _Pill(text: "⭐ $points", filled: true),
                          const SizedBox(width: 10),
                          _Pill(text: "🔥 $streak", filled: false),
                          const SizedBox(width: 10),
                          _Pill(text: "BEST $best", filled: false),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ✅ NEW: PLUS block (copy + dev toggle)
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "PLUS",
                            style:
                                Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: KnowNoKnowTheme.mutedInk,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.6,
                                    ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: KnowNoKnowTheme.panel,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: KnowNoKnowTheme.stroke,
                                width: 1.2,
                              ),
                            ),
                            child: Text(
                              "\$5.99 / mo",
                              style: const TextStyle(
                                color: KnowNoKnowTheme.ink,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Text(
                        _plus ? "You’re on Plus." : "Upgrade for more daily mysteries.",
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: KnowNoKnowTheme.ink,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 8),

                      Text(
                        _plus
                            ? "• Up to 5 mystery calls/day\n• Unlimited +5 extensions\n• Create up to 5 circles (7 people required to unlock the next)"
                            : "Free includes 1 mystery call/day.\nPlus gives you up to 5 calls/day + unlimited extensions + up to 5 circles.",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: KnowNoKnowTheme.mutedInk,
                              fontWeight: FontWeight.w900,
                              height: 1.25,
                            ),
                      ),

                      const SizedBox(height: 14),

                      // 🚧 No real subscriptions yet → dev switch + placeholder buttons.
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: KnowNoKnowTheme.panel,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: KnowNoKnowTheme.stroke,
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Text(
                                  "DEV: Plus access",
                                  style: TextStyle(
                                    color: KnowNoKnowTheme.ink,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const Spacer(),
                                Switch.adaptive(
                                  value: _plus,
                                  onChanged: (v) async {
                                    await Subscription.setPlus(v);
                                    if (!mounted) return;
                                    setState(() => _plus = v);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: OutlinedButton(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Purchases not wired yet (dev build).",
                                            ),
                                          ),
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: KnowNoKnowTheme.ink,
                                        side: const BorderSide(
                                          color: KnowNoKnowTheme.stroke,
                                          width: 1.2,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: const Text(
                                        "RESTORE",
                                        style: TextStyle(
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
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Paywall not wired yet. Dev switch controls Plus.",
                                            ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: KnowNoKnowTheme.ink,
                                        foregroundColor: KnowNoKnowTheme.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: const Text(
                                        "UPGRADE",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "DEV",
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: KnowNoKnowTheme.mutedInk,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Reset everything (for testing).",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: KnowNoKnowTheme.mutedInk,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: OutlinedButton(
                          onPressed: () async {
                            // ✅ Also clear any in-progress call timer so "resume"
                            // logic never survives a dev reset.
                            await AppState.clearCallStarted();

                            // ✅ Reset dev subscription аа well
                            await Subscription.setPlus(false);

                            await AppStorage.setAuthed(false);
                            await AppStorage.setProfile(name: '');
                            await AppStorage.setCircle([]);
                            await AppStorage.clearTodayPair();

                            if (!context.mounted) return;
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              AppRouter.auth,
                              (r) => false,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: KnowNoKnowTheme.ink,
                            side: const BorderSide(
                              color: KnowNoKnowTheme.stroke,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text(
                            "SIGN OUT (DEV RESET)",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                Text(
                  _plus
                      ? "Know No Know Plus • Up to 5 mysteries a day."
                      : "Know No Know • One mystery a day.",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: KnowNoKnowTheme.mutedInk,
                        fontWeight: FontWeight.w900,
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

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

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
      child: child,
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
        color: filled ? KnowNoKnowTheme.ink : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: KnowNoKnowTheme.stroke, width: 1.2),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: filled ? KnowNoKnowTheme.white : KnowNoKnowTheme.ink,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
