import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../brain/events/learning_event.dart';
import '../../brain/events/learning_event_controller.dart';
import '../../brain/expression/generative_expression_service.dart';
import '../../brain/reactive/reactive_event_processor.dart';
import '../../brain/recommendations/adaptation_engine.dart';
import '../../brain/recommendations/coach_recommendation.dart';
import '../../brain/recommendations/coach_recommendation_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../models/workout_completion_record.dart' show WorkoutCompletionRecord;
import '../models/workout_models.dart';
import '../widgets/adaptive_advisory_card.dart';
import '../widgets/workout_widgets.dart';

/// 32_workout_detail (368:3059). A [ConsumerStatefulWidget] (not
/// [StatelessWidget]) because opening this screen is the real Tier 2
/// "adaptive surface" trigger point (see the amendment: "Trigger: On
/// demand when the user requests or opens an adaptive surface") — it
/// checks once, on mount, whether any exercise in [workout] has an active
/// safety flag or pattern, and if so surfaces the resulting Tier 2
/// decision through a Tier 3 explanation. Advisory only — never blocks
/// "Start Workout" itself.
class WorkoutDetailScreen extends ConsumerStatefulWidget {
  const WorkoutDetailScreen({
    super.key,
    required this.workout,
    required this.onBack,
    required this.onStart,
  });

  final Workout workout;
  final VoidCallback onBack;
  final VoidCallback onStart;

  @override
  ConsumerState<WorkoutDetailScreen> createState() =>
      _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends ConsumerState<WorkoutDetailScreen> {
  CoachRecommendation? _recommendation;
  String? _explanation;
  bool _checkStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAdvisory());
  }

  Future<void> _checkAdvisory() async {
    if (_checkStarted) return;
    _checkStarted = true;

    final engine = ref.read(adaptationEngineProvider);
    CoachRecommendation? found;
    for (final exercise in widget.workout.exercises) {
      final exerciseId = exercise.catalogId;
      if (exerciseId == null) continue;
      final rec = await engine.decideForExercise(
        exerciseId: exerciseId,
        workoutId: widget.workout.id,
      );
      if (rec != null) {
        found = rec;
        break;
      }
    }
    if (found == null) return;
    if (!mounted) return;

    final expression = ref.read(generativeExpressionServiceProvider);
    final result = await expression.explain(
      action: found.action,
      reasonCodes: found.reasonCodes,
    );
    if (!mounted) return;

    await ref
        .read(coachRecommendationControllerProvider.notifier)
        .attachExplanation(found.id, result.text);
    await _logOutcome(found.id, LearningEventType.recommendationShown);
    await ref
        .read(coachRecommendationControllerProvider.notifier)
        .recordOutcome(found.id, RecommendationOutcomeStatus.shown);

    if (!mounted) return;
    setState(() {
      _recommendation = found;
      _explanation = result.text;
    });
  }

  Future<void> _logOutcome(
    String recommendationId,
    LearningEventType type,
  ) async {
    final events = ref.read(learningEventControllerProvider.notifier);
    final reactive = ref.read(reactiveEventProcessorProvider);
    final event = LearningEvent.recommendationOutcome(
      id: '${type.name}_$recommendationId',
      userId: WorkoutCompletionRecord.localProfileId,
      type: type,
      recommendationId: recommendationId,
      occurredAt: DateTime.now(),
    );
    final saved = await events.ingest(event);
    if (saved != null) await reactive.process(saved);
  }

  Future<void> _respond(RecommendationOutcomeStatus status) async {
    final rec = _recommendation;
    if (rec == null) return;
    final type = status == RecommendationOutcomeStatus.accepted
        ? LearningEventType.recommendationAccepted
        : LearningEventType.recommendationDismissed;
    await _logOutcome(rec.id, type);
    await ref
        .read(coachRecommendationControllerProvider.notifier)
        .recordOutcome(rec.id, status);
    if (!mounted) return;
    setState(() {
      _recommendation = null;
      _explanation = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 24, top: 12),
                      child: Semantics(
                        button: true,
                        label: 'Back',
                        child: Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: widget.onBack,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.07),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: AppIcon('chevron-left', size: 16),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        height: 160,
                        margin: const EdgeInsets.only(top: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            widget.workout.heroAssetPath,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              if (kDebugMode) {
                                debugPrint(
                                  'WorkoutDetailScreen: hero asset failed to load: ${widget.workout.heroAssetPath} ($error)',
                                );
                              }
                              return const _HeroFallback();
                            },
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.workout.title,
                            style: AppTextStyles.screenTitle.copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.workout.subtitle,
                            style: AppTextStyles.subtitle.copyWith(
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              WorkoutStatPill(
                                emoji: '⏱',
                                label: '${widget.workout.totalMinutes} min',
                              ),
                              const SizedBox(width: 8),
                              WorkoutStatPill(
                                emoji: '💎',
                                label: widget.workout.difficulty.label,
                              ),
                              const SizedBox(width: 8),
                              WorkoutStatPill(
                                emoji: '🔥',
                                label: '${widget.workout.calories} cal',
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
                              Text(
                                'EQUIPMENT:',
                                style: AppTextStyles.captionBold.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.purple,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.workout.equipment,
                                  style: AppTextStyles.captionBold.copyWith(
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'EXERCISES (${widget.workout.exercises.length})',
                            style: AppTextStyles.captionBold.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (
                            var i = 0;
                            i < widget.workout.exercises.length;
                            i++
                          ) ...[
                            ExerciseListRow(
                              exercise: widget.workout.exercises[i],
                            ),
                            if (i != widget.workout.exercises.length - 1)
                              const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                    if (_recommendation != null && _explanation != null) ...[
                      const SizedBox(height: 8),
                      AdaptiveAdvisoryCard(
                        safetyDecision: _recommendation!.safetyDecision,
                        explanation: _explanation!,
                        onAccept: () =>
                            _respond(RecommendationOutcomeStatus.accepted),
                        onDismiss: () =>
                            _respond(RecommendationOutcomeStatus.dismissed),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: RoutineGradientButton(
                label: 'Start Workout',
                onPressed: widget.onStart,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown in place of [Workout.heroAssetPath] when that asset fails to
/// load — a clean branded placeholder (app gradient + sun mascot), never
/// Flutter's red/broken-image error box. The hero is decorative context,
/// not a required RoutinePlayer production asset, so degrading it
/// gracefully is correct; RoutinePlayer's own verified pose art
/// deliberately does not get this treatment (see movement_display.dart).
class _HeroFallback extends StatelessWidget {
  const _HeroFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('workout_hero_fallback'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.cardStart, AppColors.cardEnd],
        ),
      ),
      alignment: Alignment.center,
      child: const AppMascot(size: 56),
    );
  }
}
