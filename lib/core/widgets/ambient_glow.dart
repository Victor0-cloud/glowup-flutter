import 'dart:ui';
import 'package:flutter/material.dart';

/// The soft blurred color blob Figma places behind the Today header
/// (368:896 and its per-variant siblings) — a 140px-radius circle at 35%
/// opacity, gaussian-blurred. Implemented as a real blurred shape (not a
/// static asset) since its color must shift per time-of-day variant.
class AmbientGlow extends StatelessWidget {
  const AmbientGlow({super.key, required this.color, this.size = 280});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Opacity(
          opacity: 0.35,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ),
      ),
    );
  }
}
