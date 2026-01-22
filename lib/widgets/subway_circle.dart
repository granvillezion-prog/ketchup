// lib/widgets/subway_circle.dart
import 'package:flutter/material.dart';
import '../theme/know_no_know_theme.dart';

class SubwayCircle extends StatelessWidget {
  const SubwayCircle({
    super.key,
    required this.label,
    required this.color,
    this.size = 30,
  });

  final String label;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final textColor = KnowNoKnowTheme.routeTextColor(color);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: 14,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Stack(
        children: [
          // subtle highlight
          Positioned.fill(
            child: ClipOval(
              child: Align(
                alignment: Alignment.topLeft,
                child: Container(
                  width: size * 0.9,
                  height: size * 0.9,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.25),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.48,
                height: 1,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
