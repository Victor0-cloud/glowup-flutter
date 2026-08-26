import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Walking & Steps' circular progress ring — same [CustomPainter]/
/// [SweepGradient] arc technique as `WaterProgressRing`, kept as its own
/// small widget (gold/yellow gradient, matching the module's own accent)
/// rather than a generic shared ring, same "each module owns its exact
/// visual" precedent `WaterProgressRing`'s own doc comment establishes.
/// `steps: null` (sensor unavailable/not yet read) renders an honest
/// static empty ring with a "—" readout, never a fabricated 0 that looks
/// like a real zero-step measurement.
class StepProgressRing extends StatelessWidget {
  const StepProgressRing({
    super.key,
    required this.steps,
    required this.goal,
    this.size = 160,
    this.strokeWidth = 14,
  });

  final int? steps;
  final int goal;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final progress = (steps == null || goal <= 0)
        ? 0.0
        : (steps! / goal).clamp(0, 1).toDouble();
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final percent = (progress * 100).round();

    return Semantics(
      label: "Today's step progress",
      value: steps == null
          ? 'Step count not available'
          : '$percent percent of goal, $steps of $goal steps',
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress),
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (context, animatedProgress, child) {
            return CustomPaint(
              painter: _StepRingPainter(
                progress: animatedProgress,
                trackColor: AppColors.cardEnd,
                strokeWidth: strokeWidth,
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
                      steps?.toString() ?? '—',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (steps != null)
                      Text(
                        '$percent%',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    Text(
                      'of $goal steps',
                      style: const TextStyle(
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
}

class _StepRingPainter extends CustomPainter {
  _StepRingPainter({
    required this.progress,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final double strokeWidth;

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
      ..shader = const SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        transform: GradientRotation(startAngle),
        colors: [Color(0xFFFFE9A8), AppColors.gold],
      ).createShader(arcRect);

    if (sweepAngle > 0) {
      canvas.drawArc(arcRect, startAngle, sweepAngle, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StepRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
