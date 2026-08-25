import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../models/workout_models.dart';
import '../state/workout_controller.dart';
import '../widgets/workout_widgets.dart';

/// 32e_up_next (368:3432).
class WorkoutUpNextScreen extends ConsumerWidget {
  const WorkoutUpNextScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(workoutSessionControllerProvider);
    if (session == null || session.phase != WorkoutPhase.upNext) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: GradientBackground(child: Container()),
      );
    }
    final controller = ref.read(workoutSessionControllerProvider.notifier);
    final exercise = session.currentExercise;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    WorkoutHeaderBar(
                      title: 'Up Next',
                      subtitle: 'Prepare yourself',
                      onBack: onBack,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181436),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Text(
                        'EXERCISE ${session.exerciseIndex + 1} OF ${session.workout.exercises.length}',
                        style: AppTextStyles.captionBold.copyWith(
                          color: AppColors.gold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: PoseDisplayBox(exercise: exercise, height: 240),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      exercise.title,
                      style: AppTextStyles.screenTitle.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Duration: ${exercise.formattedDuration}',
                      style: const TextStyle(
                        color: AppColors.ctaStart,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF181436),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const AppIcon('sparkles-sm', size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'AI COACH TIP',
                                  style: AppTextStyles.captionBold.copyWith(
                                    color: AppColors.gold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Focus on your breath and controlled form — quality over speed keeps every rep effective.',
                              style: AppTextStyles.subtitle.copyWith(
                                fontSize: 14,
                                height: 20 / 14,
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
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  RoutineGradientButton(
                    label: "I'm Ready",
                    onPressed: controller.confirmReadyForNext,
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    button: true,
                    label: 'Skip Exercise',
                    child: InkWell(
                      onTap: controller.skipUpNextExercise,
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
