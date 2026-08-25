import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/ambient_glow.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../models/workout_models.dart';
import '../state/workout_controller.dart';

/// 33_workout_complete (368:3468).
class WorkoutCompleteScreen extends ConsumerWidget {
  const WorkoutCompleteScreen({
    super.key,
    required this.onBackToHome,
    required this.onViewSummary,
  });

  final VoidCallback onBackToHome;
  final VoidCallback onViewSummary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(workoutSessionControllerProvider);
    if (session == null || session.phase != WorkoutPhase.complete) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: GradientBackground(child: Container()),
      );
    }
    final completedCount = session.exerciseElapsedSeconds.keys
        .where((id) => !session.skippedExerciseIds.contains(id))
        .length;
    final durationMinutes =
        (DateTime.now().difference(session.startedAt).inSeconds / 60)
            .ceil()
            .clamp(1, 999);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned(
                      top: 40,
                      child: AmbientGlow(color: AppColors.ctaStart, size: 300),
                    ),
                    Column(
                      children: [
                        const SizedBox(height: 40),
                        Container(
                          width: 140,
                          height: 140,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/glow_up/illustrations/workout-complete-celebration.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '🎉 Workout Complete!',
                          style: AppTextStyles.screenTitle.copyWith(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "You smashed today's targets",
                          style: AppTextStyles.subtitle.copyWith(fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.12),
                            border: Border.all(color: AppColors.gold),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const AppIcon(
                                'award',
                                size: 20,
                                color: AppColors.gold,
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  'Glow Score Impact: +5 points',
                                  style: AppTextStyles.captionBold.copyWith(
                                    color: AppColors.gold,
                                    fontSize: 18,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              _StatCard(
                                value: '$durationMinutes min',
                                label: 'Duration',
                              ),
                              const SizedBox(width: 12),
                              _StatCard(
                                value: '${session.workout.calories}',
                                label: 'Calories',
                              ),
                              const SizedBox(width: 12),
                              _StatCard(
                                value:
                                    '$completedCount/${session.workout.exercises.length}',
                                label: 'Exercises',
                              ),
                            ],
                          ),
                        ),
                      ],
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
                    children: [
                      Expanded(
                        child: Material(
                          color: const Color(0xFF251B4F),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () =>
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Sharing isn\'t connected yet.',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                ),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: Text(
                                'Share Summary',
                                style: AppTextStyles.captionBold.copyWith(
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Material(
                          color: const Color(0xFF251B4F),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: onViewSummary,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: Text(
                                'View Summary',
                                style: AppTextStyles.captionBold.copyWith(
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RoutineGradientButton(
                    label: 'Back to Home',
                    onPressed: onBackToHome,
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

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF251B4F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTextStyles.screenTitle.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: AppTextStyles.caption.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
