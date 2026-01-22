// lib/widgets/boarding_overlay.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/know_no_know_theme.dart';
import 'subway_circle.dart';

class BoardingOverlay extends StatelessWidget {
  const BoardingOverlay({
    super.key,
    required this.routes,
  });

  final List<RouteChip> routes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KnowNoKnowTheme.subwayBlack,
      body: Stack(
        children: [
          // subtle moving scanline
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.03),
                      Colors.transparent,
                      Colors.white.withOpacity(0.02),
                      Colors.transparent,
                    ],
                  ),
                ),
              ).animate(onPlay: (c) => c.repeat())
                  .moveY(begin: -40, end: 40, duration: 1800.ms),
            ),
          ),

          Center(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: KnowNoKnowTheme.panel,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: KnowNoKnowTheme.stroke, width: 1.2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "DOORS CLOSING",
                      style: TextStyle(
                        color: KnowNoKnowTheme.subwayWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Identity classified.\nYou’ll find out inside the call.",
                      style: TextStyle(
                        color: KnowNoKnowTheme.muted,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // routes row
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: routes.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) {
                          final r = routes[i];
                          return SubwayCircle(label: r.label, color: r.color, size: 30)
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .scaleXY(begin: 0.95, end: 1.05, duration: (800 + i * 60).ms);
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    _StatusLine(text: "CONNECTING…", delayMs: 0),
                    _StatusLine(text: "NO TURNING BACK.", delayMs: 450),
                    _StatusLine(text: "REVEAL IN CALL.", delayMs: 900),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.text, required this.delayMs});
  final String text;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: KnowNoKnowTheme.subwayWhite,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    )
        .animate()
        .fadeIn(delay: delayMs.ms, duration: 250.ms)
        .then()
        .fadeOut(duration: 250.ms)
        .then()
        .fadeIn(duration: 250.ms);
  }
}

class RouteChip {
  final String label;
  final Color color;
  const RouteChip(this.label, this.color);
}
