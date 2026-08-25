import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_background.dart';
import '../models/workout_models.dart';
import '../state/workout_controller.dart';
import '../widgets/workout_widgets.dart';

/// 32b_get_ready (368:3142). No decorative hero above the countdown ring —
/// the only art on this screen is the real current exercise's own first
/// pose ([PoseDisplayBox] below), resolved through the same shared
/// resolver every other exercise-preview surface uses. This screen
/// previously showed a time-of-day illustration sourced from the
/// dedicated Workout Session page (300:2), but every one of those 8
/// exported PNGs turned out to bake in a full unrelated mockup screen
/// (status bar, "GET READY! We're about to start!", a baked-in countdown
/// "3", "Squat 12 Reps" sample copy) rather than character-only art as
/// originally assumed — never usable here, so the reference was removed
/// rather than kept pointing at the wrong image. No back/cancel control
/// exists here in Figma (only "Skip"), so none is added.
class WorkoutGetReadyScreen extends ConsumerWidget {
  const WorkoutGetReadyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(workoutSessionControllerProvider);
    if (session == null || session.phase != WorkoutPhase.getReady) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: GradientBackground(child: Container()),
      );
    }
    final controller = ref.read(workoutSessionControllerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      'GET READY',
                      style: AppTextStyles.captionBold.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    WorkoutTimerRing(
                      progress:
                          1 - (session.remainingSeconds / kGetReadySeconds),
                      size: 160,
                      strokeWidth: 10,
                      child: Text(
                        '${session.remainingSeconds}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 72,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.cardStart, AppColors.cardEnd],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Column(
                          children: [
                            Text(
                              session.workout.title,
                              style: AppTextStyles.cardTitle.copyWith(
                                color: AppColors.gold,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.07),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'FIRST POSE',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            PoseDisplayBox(
                              exercise: session.currentExercise,
                              height: 160,
                              step: 1,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              session.currentExercise.title,
                              style: AppTextStyles.screenTitle.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Duration — ${session.currentExercise.formattedDuration}',
                              style: AppTextStyles.subtitle.copyWith(
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: controller.skipGetReady,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    alignment: Alignment.center,
                    child: Text('Skip', style: AppTextStyles.buttonLabel),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
