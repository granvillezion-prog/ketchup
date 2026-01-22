import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/know_no_know_theme.dart';

class MystoProfileScreen extends StatelessWidget {
  final String name;
  const MystoProfileScreen({super.key, required this.name});

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return "?";
    if (parts.length == 1) {
      final s = parts.first;
      return s.characters.take(2).toString().toUpperCase();
    }
    final a = parts.first.characters.first.toUpperCase();
    final b = parts.last.characters.first.toUpperCase();
    return "$a$b";
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);

    return Scaffold(
      backgroundColor: KnowNoKnowTheme.yellow,
      appBar: AppBar(
        title: const Text(
          "MYSTO",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: KnowNoKnowTheme.white,
                  borderRadius: BorderRadius.circular(26),
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
                  children: [
                    // Avatar
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: KnowNoKnowTheme.panel,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: KnowNoKnowTheme.stroke, width: 1.2),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: KnowNoKnowTheme.ink,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Name + status
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: KnowNoKnowTheme.ink,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Not on KetchUp yet (placeholder)",
                            style: TextStyle(
                              color: KnowNoKnowTheme.mutedInk,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 180.ms).moveY(begin: 10, end: 0, duration: 220.ms),

              const SizedBox(height: 14),

              // Stats cards (placeholders)
              _SnapCard(
                title: "Streak with this Mysto",
                value: "—",
                subtitle: "Coming soon",
              ).animate().fadeIn(duration: 180.ms, delay: 60.ms).moveY(begin: 10, end: 0, duration: 220.ms),

              const SizedBox(height: 10),

              _SnapCard(
                title: "Last KetchUp",
                value: "—",
                subtitle: "Coming soon",
              ).animate().fadeIn(duration: 180.ms, delay: 110.ms).moveY(begin: 10, end: 0, duration: 220.ms),

              const Spacer(),

              // Action buttons (placeholders)
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: null, // later: invite deep link
                  child: const Text(
                    "INVITE (SOON)",
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ).animate().fadeIn(duration: 180.ms, delay: 140.ms),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KnowNoKnowTheme.white,
                    foregroundColor: KnowNoKnowTheme.ink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: KnowNoKnowTheme.ink, width: 1.2),
                    ),
                  ),
                  child: const Text(
                    "BACK",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ),
              ).animate().fadeIn(duration: 180.ms, delay: 170.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _SnapCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _SnapCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: KnowNoKnowTheme.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: KnowNoKnowTheme.stroke, width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: KnowNoKnowTheme.mutedInk,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: const TextStyle(
                    color: KnowNoKnowTheme.ink,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: KnowNoKnowTheme.mutedInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: KnowNoKnowTheme.ink),
        ],
      ),
    );
  }
}
