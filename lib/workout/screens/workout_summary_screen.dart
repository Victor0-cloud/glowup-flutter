import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/gradient_background.dart';
import '../models/workout_models.dart';
import '../widgets/workout_widgets.dart';

/// 33b_workout_summary (368:3506). Figma's mock shows fabricated
/// heart-rate/form-score numbers (127 BPM, "9.5/10 Form") — this app has
/// no heart-rate sensor or camera-based form analysis, so those specific
/// numbers are NOT reproduced (would be fake data presented as measured).
/// Everything that IS real — which exercises ran, whether each was
/// skipped, and real elapsed time — comes straight from the completed
/// session.
class WorkoutSummaryScreen extends StatefulWidget {
  const WorkoutSummaryScreen({
    super.key,
    required this.result,
    required this.onBack,
    required this.onDone,
  });

  final WorkoutSessionResult result;
  final VoidCallback onBack;
  final VoidCallback onDone;

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen> {
  int _rating = 0;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final totalMinutes = (result.totalDuration.inSeconds / 60).ceil().clamp(
      1,
      999,
    );

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
                      title: 'Workout Summary',
                      onBack: widget.onBack,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF251B4F),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Total Duration',
                                        style: AppTextStyles.caption.copyWith(
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        '$totalMinutes min',
                                        style: AppTextStyles.screenTitle
                                            .copyWith(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Exercises Done',
                                        style: AppTextStyles.caption.copyWith(
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        '${result.completedCount}/${result.exerciseResults.length}',
                                        style: const TextStyle(
                                          color: AppColors.ctaStart,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
                                  'award',
                                  size: 16,
                                  color: AppColors.gold,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${result.workout.title} complete — nice work!',
                                    style: AppTextStyles.captionBold.copyWith(
                                      color: AppColors.gold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EXERCISE BREAKDOWN',
                            style: AppTextStyles.captionBold.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 10),
                          for (
                            var i = 0;
                            i < result.exerciseResults.length;
                            i++
                          ) ...[
                            _ExerciseSummaryRow(
                              result: result.exerciseResults[i],
                            ),
                            if (i != result.exerciseResults.length - 1)
                              const SizedBox(height: 10),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Rate this Workout',
                      style: AppTextStyles.captionBold.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 1; i <= 5; i++)
                          Semantics(
                            button: true,
                            label: '$i star${i == 1 ? '' : 's'}',
                            child: InkWell(
                              onTap: () => setState(() => _rating = i),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  i <= _rating ? Icons.star : Icons.star_border,
                                  color: AppColors.gold,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
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
                  onTap: widget.onDone,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.center,
                    child: const Text(
                      'Done',
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

class _ExerciseSummaryRow extends StatelessWidget {
  const _ExerciseSummaryRow({required this.result});

  final ExerciseResult result;

  @override
  Widget build(BuildContext context) {
    final minutes = result.elapsedSeconds ~/ 60;
    final seconds = result.elapsedSeconds % 60;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF181436),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.exercise.title,
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                    ),
                    Text(
                      '$minutes:${seconds.toString().padLeft(2, '0')} min',
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  result.skipped ? 'Skipped' : 'Completed',
                  style: TextStyle(
                    color: result.skipped
                        ? AppColors.textSecondary
                        : AppColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          // AI Coach reflection saved right after this exercise (currently
          // only Legs Up Wall/Reclined Butterfly) — see
          // `ExerciseReflectionCard`/`WorkoutSessionController.saveExerciseNote`.
          // Null for every exercise without a reflection prompt, so this
          // never appears for EX001-EX065.
          if (result.note != null) ...[
            const SizedBox(height: 8),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.07)),
            const SizedBox(height: 8),
            Text(
              'AI Coach note: ${result.note}',
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
