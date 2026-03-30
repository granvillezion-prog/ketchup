// lib/widgets/lava_background.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/know_no_know_theme.dart';

class LavaBackground extends StatefulWidget {
  const LavaBackground({
    super.key,
    required this.child,
    this.parallax = 0.0,
    this.overlayAsset,
    this.overlayOpacity = 0.18,
    this.overlayDriftPx = 8.0, // ✅ NEW: Apple-like ambient drift amount
  });

  final Widget child;

  /// Foreground scroll pixels (optional). Map to tiny translation.
  final double parallax;

  /// Optional overlay image (PNG with transparency) drawn on top of the base bg.
  final String? overlayAsset;

  /// Opacity for overlay image.
  final double overlayOpacity;

  /// Total drift range (pixels) for the overlay (ping-pong).
  final double overlayDriftPx;

  @override
  State<LavaBackground> createState() => _LavaBackgroundState();
}

class _LavaBackgroundState extends State<LavaBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _drift;

  @override
  void initState() {
    super.initState();

    // ✅ Slow, subtle drift (forward <-> backward)
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat(reverse: true);

    _drift = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // scroll px -> tiny translation (subtle)
    final parallaxDy = (-widget.parallax * 0.06).clamp(-18.0, 18.0).toDouble();

    // drift -> tiny translation (Apple-like “life”)
    final driftDy = _drift.value * widget.overlayDriftPx;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // Base background (slight parallax)
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(0, parallaxDy),
                child: CustomPaint(
                  painter: _BgPainter(t: _ctrl.value),
                ),
              ),
            ),

            // ✅ Overlay PNG: parallax + ambient drift (drift is independent)
            if (widget.overlayAsset != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: widget.overlayOpacity.clamp(0.0, 1.0),
                    child: Transform.translate(
                      // parallax is subtle; drift adds “life”
                      offset: Offset(0, parallaxDy * 0.55 + driftDy),
                      child: Image.asset(
                        widget.overlayAsset!,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                ),
              ),

            // Foreground
            Positioned.fill(child: widget.child),
          ],
        );
      },
    );
  }
}

class _BgPainter extends CustomPainter {
  _BgPainter({required this.t});
  final double t; // 0..1-ish

  Color _a(Color c, double alpha) =>
      c.withAlpha((alpha * 255).round().clamp(0, 255));

  double _s(double x) => math.sin(x);

  @override
  void paint(Canvas canvas, Size size) {
    // Base
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = KnowNoKnowTheme.lavaBase,
    );

    // Soft wash
    final wash = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        _a(KnowNoKnowTheme.bg1, 0.98),
        _a(KnowNoKnowTheme.bg2, 0.78),
        _a(KnowNoKnowTheme.bg3, 0.95),
      ],
      stops: const [0.0, 0.60, 1.0],
    ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, Paint()..shader = wash);

    // Premium energy using brand purple (via KnowNoKnowTheme.primary)
    final tt = t * math.pi * 2;

    final p1 = Offset(
      size.width * (0.20 + 0.06 * _s(tt * 0.6)),
      size.height * (0.20 + 0.05 * _s(tt * 0.8)),
    );
    final p2 = Offset(
      size.width * (0.78 + 0.05 * _s(tt * 0.7 + 2.0)),
      size.height * (0.68 + 0.06 * _s(tt * 0.55 + 1.0)),
    );

    Paint glow(Offset c, double r, double a) {
      return Paint()
        ..shader = RadialGradient(
          colors: [
            KnowNoKnowTheme.primary.withOpacity(a),
            Colors.transparent,
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r));
    }

    canvas.drawRect(
      Offset.zero & size,
      glow(p1, size.width * 0.72, 0.10),
    );
    canvas.drawRect(
      Offset.zero & size,
      glow(p2, size.width * 0.85, 0.08),
    );

    // Light vignette for depth
    final vignette = RadialGradient(
      center: Alignment.center,
      radius: 1.12,
      colors: [
        Colors.transparent,
        _a(KnowNoKnowTheme.ink, 0.06),
      ],
      stops: const [0.72, 1.0],
    ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, Paint()..shader = vignette);

    // Ultra-subtle speckle (keeps it from looking flat)
    final speckle = Paint()..color = _a(KnowNoKnowTheme.ink, 0.018);
    final seed = t * 999.0;
    for (int i = 0; i < 360; i++) {
      final x = (i * 37.0 + seed) % size.width;
      final y = (i * 61.0 + seed * 0.7) % size.height;
      if (((x + y) % 17) < 0.9) {
        canvas.drawCircle(Offset(x, y), 0.65, speckle);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BgPainter oldDelegate) => oldDelegate.t != t;
}
