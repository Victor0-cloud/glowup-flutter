import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/gradient_background.dart';
import '../models/workout_models.dart';
import '../state/workout_controller.dart';
import '../widgets/exercise_reflection_card.dart';
import '../widgets/workout_widgets.dart';

/// 32d_rest_timer (368:3394).
class WorkoutRestScreen extends ConsumerWidget {
  const WorkoutRestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(workoutSessionControllerProvider);
    if (session == null || session.phase != WorkoutPhase.resting) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: GradientBackground(child: Container()),
      );
    }
    final controller = ref.read(workoutSessionControllerProvider.notifier);
    final completed = session.exerciseIndex > 0
        ? session.workout.exercises[session.exerciseIndex - 1]
        : null;
    final next = session.currentExercise;
    final elapsedFraction = 1 - (session.remainingSeconds / kRestSeconds);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    WorkoutHeaderBar(
                      title: 'Rest Period',
                      subtitle: completed == null
                          ? null
                          : '${completed.title.toLowerCase()} completed',
                    ),
                    const SizedBox(height: 24),
                    WorkoutTimerRing(
                      progress: elapsedFraction,
                      size: 180,
                      strokeWidth: 10,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${session.remainingSeconds}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'SECONDS',
                            style: AppTextStyles.captionBold.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (completed != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF10CD00,
                          ).withValues(alpha: 0.14),
                          border: Border.all(
                            color: const Color(
                              0xFF10CD00,
                            ).withValues(alpha: 0.5),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppIcon(
                              'check-circle',
                              size: 16,
                              color: Color(0xFF10CD00),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '${completed.title} Completed',
                                style: const TextStyle(
                                  color: Color(0xFF10CD00),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (completed != null &&
                        kExerciseReflectionConfigs.containsKey(
                          completed.catalogId,
                        )) ...[
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: ExerciseReflectionCard(
                          key: ValueKey('reflection_${completed.catalogId}'),
                          config:
                              kExerciseReflectionConfigs[completed.catalogId]!,
                          onSave: (summary) => controller.saveExerciseNote(
                            completed.id,
                            summary,
                          ),
                        ),
                      ),
                    ],
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'UP NEXT',
                              style: AppTextStyles.captionBold.copyWith(
                                color: AppColors.gold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            PoseDisplayBox(
                              exercise: next,
                              height: 140,
                              step: 1,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              next.title,
                              style: AppTextStyles.screenTitle.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.07),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const AppIcon(
                                  'clock',
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Duration — ${next.formattedDuration}',
                                  style: AppTextStyles.subtitle.copyWith(
                                    fontSize: 14,
                                  ),
                                ),
                              ],
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: controller.skipRest,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    child: const Text(
                      'Skip Rest (+0:30)',
                      style: TextStyle(
                        color: Color(0xFF0A0B1E),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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
