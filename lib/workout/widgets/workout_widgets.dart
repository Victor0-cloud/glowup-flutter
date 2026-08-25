import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_icon.dart';
import '../../routine_player/data/routine_player_registry.dart';
import '../data/exercise_catalog.dart';
import '../models/exercise_models.dart';
import '../models/workout_models.dart';

/// The gold->pink countdown ring used on Get Ready (32b), Active (32c),
/// and Rest (32d). Figma exports these as two flattened SVGs frozen at a
/// fixed angle, which can't represent a live countdown — repainted as a
/// real arc, same approach as [GlowScoreRing], driven by real elapsed
/// state instead of a static value.
class WorkoutTimerRing extends StatelessWidget {
  const WorkoutTimerRing({
    super.key,
    required this.progress,
    required this.size,
    this.strokeWidth = 10,
    this.child,
  });

  final double progress; // 0-1, elapsed fraction
  final double size;
  final double strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TimerRingPainter(
          progress: progress.clamp(0, 1),
          strokeWidth: strokeWidth,
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

class _TimerRingPainter extends CustomPainter {
  _TimerRingPainter({required this.progress, required this.strokeWidth});
  final double progress;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = (Offset.zero & size).center;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
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
        colors: [AppColors.gold, AppColors.ctaStart, AppColors.purple],
      ).createShader(arcRect);
    canvas.drawArc(arcRect, startAngle, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _TimerRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// One 31_workout_categories row (368:2999).
class CategoryCardTile extends StatelessWidget {
  const CategoryCardTile({
    super.key,
    required this.category,
    required this.workoutCount,
    required this.exerciseCount,
    required this.onTap,
  });

  final ExerciseCategory category;
  final int workoutCount;
  final int exerciseCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          height: 100,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(category.gradientStartHex),
                Color(category.gradientEndHex),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      category.label,
                      style: AppTextStyles.screenTitle.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(category.emoji, style: const TextStyle(fontSize: 20)),
                ],
              ),
              const Spacer(),
              Text(
                '$workoutCount Routine${workoutCount == 1 ? '' : 's'}',
                style: AppTextStyles.cardTitle.copyWith(fontSize: 13),
              ),
              Text(
                '$exerciseCount exercises in library',
                style: AppTextStyles.caption.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A stat pill (368:3077 "Stat-Pill") on 32_workout_detail.
class WorkoutStatPill extends StatelessWidget {
  const WorkoutStatPill({super.key, required this.emoji, required this.label});

  final String emoji;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF181436),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.captionBold.copyWith(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One 368:3094 "Exercise-Row" on the detail screen.
class ExerciseListRow extends StatelessWidget {
  const ExerciseListRow({super.key, required this.exercise});

  final WorkoutExercise exercise;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.cardStart, AppColors.cardEnd],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          _ExerciseThumbnail(exercise: exercise),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.title,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                ),
                Text(
                  exercise.playbackType == ExercisePlaybackType.reps &&
                          exercise.reps != null
                      ? '${exercise.reps} reps · ${exercise.formattedDuration}'
                      : exercise.formattedDuration,
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          if (exercise.playbackType != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                exercise.playbackType!.label.toUpperCase(),
                style: AppTextStyles.caption.copyWith(fontSize: 10),
              ),
            ),
          const AppIcon('chevron-right', size: 16),
        ],
      ),
    );
  }
}

/// Small 40x40 exercise thumbnail on a detail-screen exercise row. Shows
/// the real approved Figma pose when [WorkoutExercise] has one — never an
/// emoji/icon substitute (hard rule, see [PoseDisplayBox]). Exercises with
/// no verified image yet get a plain tinted square with no glyph, rather
/// than an invented symbol. Uses frame 1 (the true first pose) for every
/// exercise except ones whose Tier 1 definition declares a different
/// [ExerciseDefinition.thumbnailFrameOrder] (Knee-to-Chest/Supine Twist
/// use their held-stretch frame instead — a neutral starting position
/// reads poorly as a small icon for a side-sequence stretch).
class _ExerciseThumbnail extends StatelessWidget {
  const _ExerciseThumbnail({required this.exercise});

  final WorkoutExercise exercise;

  @override
  Widget build(BuildContext context) {
    final catalogId = exercise.catalogId;
    final tier1 = catalogId != null
        ? routinePlayerExerciseById(catalogId)
        : null;
    final thumbnailStep = tier1?.thumbnailFrameOrder ?? 1;
    final assetPath =
        exercise.thumbnailAssetPath ??
        resolvePoseAssetPath(exercise, step: thumbnailStep);
    return Container(
      width: 40,
      height: 40,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF181436),
        borderRadius: BorderRadius.circular(8),
      ),
      child: assetPath == null
          ? null
          : Image.asset(
              assetPath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                if (kDebugMode) {
                  debugPrint(
                    '_ExerciseThumbnail: asset failed to load: $assetPath ($error)',
                  );
                }
                // Same plain tinted square as the "no verified image yet"
                // case above — never an invented substitute glyph, and
                // never another exercise's image.
                return const SizedBox.shrink();
              },
            ),
    );
  }
}

/// Resolves the real approved pose image for [exercise] at 1-indexed
/// [step], or null if none is verified yet — shared by [_ExerciseThumbnail]
/// and [PoseDisplayBox] so both use the exact same lookup, always by
/// stable exercise ID, never by display-name matching. `poseAssetPath`
/// (the legacy static yoga-pose art) always wins when set; otherwise this
/// tries, in order:
///
/// 1. Tier 2 (legacy catalog) — the original, unchanged behavior. Checked
///    first so every exercise Tier 2 already served correctly (Plank,
///    Squat, Deep Breathing, Jumping Jack, ...) keeps resolving to the
///    exact same approved image as before — this fix must never silently
///    swap an already-working mapping for a different (even if also
///    real) one.
/// 2. Tier 1 (RoutinePlayer registry) — only reached when Tier 2 has
///    nothing for this [catalogId] at all. Added for EX055-EX058
///    (Morning Yoga's Sun Salutation/Downward Dog/Warrior I/Warrior II):
///    these have real Tier 1 ids that don't exist in the Tier 2 legacy
///    catalog, so without this branch they resolved to nothing — a
///    blank thumbnail — even though a real approved image exists.
///
/// Still correctly returns null (clean text treatment, never a
/// substitute) for exercises with no verified image in either tier —
/// e.g. Tree Pose/Savasana, which are genuinely not yet approved.
String? resolvePoseAssetPath(WorkoutExercise exercise, {required int step}) {
  if (exercise.poseAssetPath != null) return exercise.poseAssetPath;
  final catalogId = exercise.catalogId;
  if (catalogId == null) return null;
  if (exercise.hasVerifiedImages) {
    final catalogExercise = exerciseById(catalogId);
    if (catalogExercise != null) {
      final tier2Asset = exercisePoseAssetPath(catalogExercise, step: step);
      if (tier2Asset != null) return tier2Asset;
    }
  }
  final tier1Exercise = routinePlayerExerciseById(catalogId);
  if (tier1Exercise != null &&
      step >= 1 &&
      step <= tier1Exercise.poses.length) {
    return tier1Exercise.poses[step - 1].approvedAsset;
  }
  return null;
}

/// The 32-series pose-display box (368:3185). HARD RULE: only the real,
/// approved, downloaded Figma pose image may appear here — never an
/// emoji, icon, or invented substitute. [step] selects which of the 6
/// real sequence images to show (advances during active playback for
/// sequence-type exercises); exercises with no verified image for the
/// current step fall back to a clean text treatment (name only,
/// no glyph) instead of a fake substitute.
class PoseDisplayBox extends StatelessWidget {
  const PoseDisplayBox({
    super.key,
    required this.exercise,
    this.height = 260,
    this.step = 1,
  });

  final WorkoutExercise exercise;
  final double height;
  final int step;

  @override
  Widget build(BuildContext context) {
    final assetPath = resolvePoseAssetPath(exercise, step: step);
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.cardStart, AppColors.cardEnd],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      padding: EdgeInsets.all(assetPath == null ? 24 : 0),
      child: assetPath != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                assetPath,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  if (kDebugMode) {
                    debugPrint(
                      'PoseDisplayBox: asset failed to load: $assetPath ($error)',
                    );
                  }
                  return Center(
                    child: Text(
                      exercise.title,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.cardTitle.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            )
          : Center(
              child: Text(
                exercise.title,
                textAlign: TextAlign.center,
                style: AppTextStyles.cardTitle.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
    );
  }
}

/// The Header-Bar pattern shared by Rest (32d), Up Next (32e), and
/// Workout Summary (33b) — title/subtitle on the left (with an optional
/// back button), a decorative 3-dot menu on the right (non-functional in
/// Figma — no menu contents are designed, so it stays a static icon).
class WorkoutHeaderBar extends StatelessWidget {
  const WorkoutHeaderBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          if (onBack != null) ...[
            Semantics(
              button: true,
              label: 'Back',
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: onBack,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const AppIcon('chevron-left', size: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTextStyles.screenTitle.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTextStyles.subtitle.copyWith(fontSize: 13),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const AppIcon('more-vertical', size: 20),
          ),
        ],
      ),
    );
  }
}
