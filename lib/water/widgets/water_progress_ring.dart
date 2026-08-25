import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../models/water_entry.dart';
import '../theme/water_variant_config.dart';

/// Water Tracker's circular progress indicator — same [CustomPainter]/
/// [SweepGradient] arc technique as `GlowScoreRing`, kept as its own
/// widget rather than a reuse of it (that ring is shared elsewhere and
/// structurally tied to a 0-100 "SCORE" caption). Animates fill changes
/// (a real, accessible progress indicator, not a static image) and
/// exposes the percentage through [Semantics] so a screen reader
/// announces real progress, not just a decorative shape.
class WaterProgressRing extends StatelessWidget {
  const WaterProgressRing({
    super.key,
    required this.consumedMl,
    required this.goalMl,
    required this.unit,
    this.gradientColors = const [Color(0xFF5FE1FF), WaterColors.brandBlue],
    this.accentColor = WaterColors.brandBlue,
    this.size = 160,
    this.strokeWidth = 14,
  });

  final double consumedMl;
  final double goalMl;
  final WaterUnit unit;
  final List<Color> gradientColors;

  /// Color for the inline percentage readout — the per-time-of-day accent,
  /// matching the approved reference's colored "72%" line inside the ring.
  final Color accentColor;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final progress = goalMl <= 0
        ? 0.0
        : (consumedMl / goalMl).clamp(0, 1).toDouble();
    final consumedDisplay = unit.fromMl(consumedMl);
    final goalDisplay = unit.fromMl(goalMl);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final percent = (progress * 100).round();

    return Semantics(
      label: 'Today\'s water progress',
      value:
          '$percent percent of goal, ${_fmt(consumedDisplay)} of ${_fmt(goalDisplay)} ${unit.label}',
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress),
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (context, animatedProgress, child) {
            return CustomPaint(
              painter: _WaterRingPainter(
                progress: animatedProgress,
                trackColor: AppColors.cardEnd,
                strokeWidth: strokeWidth,
                gradientColors: gradientColors,
              ),
              child: child,
            );
          },
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _fmt(consumedDisplay),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'of ${_fmt(goalDisplay)} ${unit.label}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class _WaterRingPainter extends CustomPainter {
  _WaterRingPainter({
    required this.progress,
    required this.trackColor,
    required this.strokeWidth,
    required this.gradientColors,
  });

  final double progress;
  final Color trackColor;
  final double strokeWidth;
  final List<Color> gradientColors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        transform: const GradientRotation(startAngle),
        colors: gradientColors.length == 1
            ? [gradientColors.first, gradientColors.first]
            : gradientColors,
      ).createShader(arcRect);

    if (sweepAngle > 0) {
      canvas.drawArc(arcRect, startAngle, sweepAngle, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaterRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gradientColors != gradientColors;
  }
}
