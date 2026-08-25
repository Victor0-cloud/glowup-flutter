import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/gradient_background.dart';
import '../models/exercise_models.dart';
import '../models/workout_models.dart';
import '../state/workout_controller.dart';
import '../widgets/workout_widgets.dart';

String _timerSubLabel(ExercisePlaybackType? type) => switch (type) {
  ExercisePlaybackType.reps => 'REPS PACE',
  ExercisePlaybackType.hold => 'HOLD',
  ExercisePlaybackType.breathing => 'BREATHE',
  ExercisePlaybackType.sequenceLoop => 'REPEAT',
  ExercisePlaybackType.sideSequence => 'PER SIDE',
  ExercisePlaybackType.timer || null => 'SECS',
};

/// 32c_workout_active (368:3170).
class WorkoutActiveScreen extends ConsumerWidget {
  const WorkoutActiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(workoutSessionControllerProvider);
    if (session == null || session.phase != WorkoutPhase.active) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: GradientBackground(child: Container()),
      );
    }
    final controller = ref.read(workoutSessionControllerProvider.notifier);
    final exercise = session.currentExercise;
    final elapsedFraction =
        1 - (session.remainingSeconds / exercise.durationSeconds);
    final stepCount = exercise.steps.length;
    // 1-indexed position in the real 6-step Figma sequence, advancing as the
    // exercise's timer elapses — drives both the caption below and which
    // real pose image PoseDisplayBox shows.
    final currentStepIndex = stepCount == 0
        ? 1
        : (elapsedFraction * stepCount).clamp(0, stepCount - 1).floor() + 1;
    final currentStep = stepCount == 0
        ? null
        : exercise.steps[currentStepIndex - 1];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  exercise.title,
                                  style: AppTextStyles.cardTitle.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Pose ${session.exerciseIndex + 1} of ${session.workout.exercises.length}',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.gold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: LinearProgressIndicator(
                              value: session.workoutProgress,
                              minHeight: 6,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.07,
                              ),
                              valueColor: const AlwaysStoppedAnimation(
                                AppColors.gold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: PoseDisplayBox(
                        exercise: exercise,
                        step: currentStepIndex,
                      ),
                    ),
                    if (currentStep != null) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            Text(
                              currentStep.label,
                              style: AppTextStyles.captionBold.copyWith(
                                color: AppColors.gold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentStep.instruction,
                              style: AppTextStyles.subtitle.copyWith(
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (exercise.playbackType == ExercisePlaybackType.reps &&
                        exercise.reps != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Target: ${exercise.reps} reps',
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                    ],
                    if (exercise.hasSwitchSide) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          elapsedFraction < 0.5
                              ? '↔ Switch sides halfway'
                              : '↔ Now on the other side',
                          style: AppTextStyles.captionBold.copyWith(
                            color: AppColors.lavenderAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    WorkoutTimerRing(
                      progress: elapsedFraction,
                      size: 110,
                      strokeWidth: 8,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${session.remainingSeconds}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            _timerSubLabel(exercise.playbackType),
                            style: AppTextStyles.caption.copyWith(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RoundIconButton(
                        icon: 'chevron-left',
                        onTap: session.exerciseIndex == 0
                            ? null
                            : controller.previousExercise,
                        semanticLabel: 'Previous exercise',
                      ),
                      const SizedBox(width: 40),
                      Semantics(
                        button: true,
                        label: session.isPaused ? 'Resume' : 'Pause',
                        child: Material(
                          color: AppColors.gold,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: controller.togglePause,
                            child: SizedBox(
                              width: 72,
                              height: 72,
                              // Figma only designs the "Pause" state (368:3197)
                              // with a real exported icon; there's no resume
                              // artwork since the mock never shows a paused
                              // player, so the resume state falls back to a
                              // platform play glyph instead of inventing one.
                              child: session.isPaused
                                  ? const Icon(
                                      Icons.play_arrow,
                                      color: Color(0xFF0A0B1E),
                                      size: 28,
                                    )
                                  : const AppIcon(
                                      'pause',
                                      size: 24,
                                      color: Color(0xFF0A0B1E),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                      _RoundIconButton(
                        icon: 'chevron-right',
                        onTap: controller.nextExercise,
                        semanticLabel: 'Next exercise',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    button: true,
                    label: 'Skip Exercise',
                    child: InkWell(
                      onTap: controller.skipCurrentExercise,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'SKIP EXERCISE',
                          style: AppTextStyles.captionBold.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  final String icon;
  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: Material(
          color: const Color(0xFF181436),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(child: AppIcon(icon, size: 20)),
            ),
          ),
        ),
      ),
    );
  }
}
