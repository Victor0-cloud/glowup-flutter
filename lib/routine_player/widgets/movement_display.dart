import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../models/exercise_definition.dart';
import '../models/pose_definition.dart';

/// Shows the current verified pose image for an exercise, inside a visual
/// container that ADAPTS to the exercise's real [aspectRatio] (its own
/// exact source-asset ratio — never bucketed/shared across exercises,
/// since two portrait exercises can have different real ratios) rather
/// than forcing every exercise into the same fixed-shape box:
///
/// - LANDSCAPE (Plank, 3:2): uses most of the available width; height
///   follows the real aspect ratio, so the athlete is large and no
///   oversized empty band appears above/below.
/// - PORTRAIT (Lunges 600x1220, Squat 400x640 — different ratios from
///   each other): height-driven and centered — a tall image does NOT try
///   to fill the full width (which would make it absurdly tall on a wide
///   screen); the container matches THIS exercise's own shape.
/// - SQUARE (everything else): also height-driven and centered.
///
/// In every case the actual pixels are shown via [BoxFit.contain] inside
/// that correctly-shaped box, so nothing is ever cropped or stretched —
/// "fill the container" means no wasted internal blank space, not
/// stretching/cropping the image to match an arbitrary fixed box
/// (Section "FILL THE CONTAINER" DEFINITION).
///
/// Frame changes use a brief crossfade (not an instant cut, not a heavy
/// fade that would make the body look ghosted) via [AnimatedSwitcher],
/// keyed by the pose's own id. [Image.asset]'s `gaplessPlayback` avoids a
/// blank flash between two already-precached frames.
///
/// If [pose].approvedAsset is null this renders the explicit
/// "UNVERIFIED EXERCISE ASSET" state — never a guess.
class MovementDisplay extends StatelessWidget {
  const MovementDisplay({
    super.key,
    required this.pose,
    this.orientation = ExerciseVisualOrientation.square,
    this.aspectRatio = 1.0,
    this.sizeBudget = 420,
    this.crossfade = true,
  });

  final PoseDefinition pose;
  final ExerciseVisualOrientation orientation;

  /// False for rhythmic movements (Jumping Jack) where a fade-through-
  /// transparent would show two overlapping semi-transparent bodies —
  /// frames replace instantly instead. True keeps the brief crossfade used
  /// by every other exercise.
  final bool crossfade;

  /// This exercise's own real width/height ratio — see
  /// [ExerciseDefinition.visualAspectRatio].
  final double aspectRatio;

  /// For landscape: the max width (height is capped at sizeBudget too, so
  /// the box never exceeds roughly sizeBudget × aspectRatio wide). For
  /// portrait/square: the container's height — width follows the ratio.
  final double sizeBudget;

  static const _crossfadeDuration = Duration(milliseconds: 90);

  /// Uniform inset applied to every frame before [BoxFit.contain] — a
  /// shared-player safety margin, not a per-exercise fix. Several approved
  /// source frames place content (raised hands, extended limbs) very
  /// close to their own canvas edge (documented at approval time, e.g.
  /// Dead Bug's QA notes: "fingertips are close to frame edge, visible but
  /// at boundary"); this margin keeps that content clear of the frame's
  /// rounded-corner clip and the container's own edge, without cropping,
  /// stretching, or altering a single source pixel — the full image still
  /// renders, just slightly smaller within its box.
  static const _safeContentPadding = EdgeInsets.all(18);

  /// Shared minimum landscape viewport shape — wider than any single
  /// approved landscape exercise's own real ratio (Dead Bug/Plank/Mountain
  /// Climbers are 600×400 = 1.5; Fire Hydrant is 576×432 ≈ 1.33), so the
  /// outer frame reserves extra horizontal safe area beyond what the
  /// source image itself needs. On screens wide enough for it to matter,
  /// this adds decorative side margin inside the SAME frame — it never
  /// changes the image's own rendered scale (height stays governed by
  /// [sizeBudget], same as before) and never crops/stretches a pixel.
  static const _minLandscapeViewportAspect = 1.7;

  @override
  Widget build(BuildContext context) {
    final aspect = aspectRatio;

    if (orientation == ExerciseVisualOrientation.landscape) {
      final viewportAspect = aspect > _minLandscapeViewportAspect
          ? aspect
          : _minLandscapeViewportAspect;
      // Outer viewport: the one shared, stable reference frame (gradient,
      // border, rounded corners, the ONLY clip boundary) — sized to the
      // wider viewport shape, height capped at sizeBudget same as before.
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: sizeBudget * viewportAspect,
            maxHeight: sizeBudget,
          ),
          child: AspectRatio(
            aspectRatio: viewportAspect,
            child: _viewport(
              context,
              // Inner content: the real image, at its own real aspect
              // ratio, centered within the wider outer viewport —
              // BoxFit.contain still governs the actual pixels; this only
              // adds side margin, it never rescales the athlete.
              child: Center(
                child: AspectRatio(aspectRatio: aspect, child: _frame(context)),
              ),
            ),
          ),
        ),
      );
    }

    // Portrait/square: height-driven and centered — do NOT stretch a tall
    // image to the full available width. Same shared outer-viewport frame,
    // sized to this exercise's own real ratio (no artificial widening —
    // only landscape exercises asked for extra horizontal safe area).
    return Center(
      child: SizedBox(
        height: sizeBudget,
        child: AspectRatio(
          aspectRatio: aspect,
          child: _viewport(context, child: _frame(context)),
        ),
      ),
    );
  }

  /// The one shared production viewport spec: fixed/stable shape (set by
  /// the caller's [AspectRatio]), centered content, and — critically — the
  /// ONLY place clipping happens. [_frame] (the actual image) is never
  /// separately clipped or independently resized; it always renders inside
  /// this same reference container.
  Widget _viewport(BuildContext context, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.cardStart, AppColors.cardEnd],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _frame(BuildContext context) {
    final asset = pose.approvedAsset;
    return AnimatedSwitcher(
      duration: crossfade ? _crossfadeDuration : Duration.zero,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      layoutBuilder: (currentChild, previousChildren) => Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [...previousChildren, ?currentChild],
      ),
      child: asset == null
          ? Center(
              key: ValueKey('missing_${pose.poseId}'),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'UNVERIFIED EXERCISE ASSET',
                      style: AppTextStyles.captionBold.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      pose.label,
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 18),
                    ),
                  ],
                ),
              ),
            )
          : Padding(
              key: ValueKey(pose.poseId),
              padding: _safeContentPadding,
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                gaplessPlayback: true,
              ),
            ),
    );
  }
}
