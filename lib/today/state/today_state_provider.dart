import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../brain/brain_context.dart';
import '../../core/tod/tod_period.dart';
import '../../onboarding/models/onboarding_profile.dart' show GoalLabel;
import '../../routines/state/routines_controller.dart';
import '../../water/data/water_repository.dart';
import '../../water/state/water_controller.dart';
import '../models/today_models.dart';
import '../theme/today_variant_config.dart';

/// Assembles [TodayState] from the resolved [TodPeriod] plus whatever the
/// Brain currently knows (the completed [BrainContext] built from
/// onboarding). This is the one place Today's widgets should read from —
/// none of them should touch [brainContextProvider] or onboarding models
/// directly, which is what keeps the dashboard data-driven instead of
/// hardcoded per widget.
final todayStateProvider = Provider<TodayState?>((ref) {
  final brain = ref.watch(brainContextProvider);
  if (brain == null) return null;

  final period = ref.watch(currentTodPeriodProvider);
  final variant = TodayVariantConfig.byPeriod[period]!;

  // Up Next now comes from real Routines state (the Brain-visible featured
  // routine for this period) rather than being fixed per variant — falls
  // back to the approved static copy only if no routine exists yet for
  // this period, so the system is never permanently anchored to one
  // hardcoded plan.
  ref.watch(routinesControllerProvider);
  final featuredRoutine = ref
      .read(routinesControllerProvider.notifier)
      .featuredFor(period);
  final plan = featuredRoutine == null
      ? DailyPlan(title: variant.planTitle, subtitle: variant.planSubtitle)
      : DailyPlan(
          title:
              '${featuredRoutine.title} — ${featuredRoutine.totalMinutes} min',
          subtitle: 'Scheduled for ${featuredRoutine.schedule.formattedTime}',
        );

  // Real durable water data once the WaterController has loaded; falls
  // back to the approved static 0/8 seed only for the brief AsyncLoading
  // window at startup (never fabricates a mid-range number).
  final waterState = ref.watch(waterControllerProvider).valueOrNull;
  final waterDone = waterState?.todayTotal ?? 0;
  final waterGoal = waterState?.goalMl ?? WaterRepository.defaultGoalMl;

  return TodayState(
    period: period,
    greetingName: brain.greetingName,
    // Placeholder score/progress numbers until Workout/Mood/Journal report
    // real data and a real Glow Score engine exists — see
    // GlowScoreSummary's doc comment for the documented future inputs.
    glowScore: const GlowScoreSummary(
      score: 72,
      message:
          "You're doing fantastic today! Keep up the momentum to reach your peak.",
    ),
    plan: plan,
    progress: [
      const QuickActionStatus(
        metric: ProgressMetric.workouts,
        label: 'Workouts',
        done: 2,
        total: 3,
        unit: 'done',
      ),
      QuickActionStatus(
        metric: ProgressMetric.water,
        label: 'Water Intake',
        done: waterDone,
        total: waterGoal,
        unit: 'ml',
      ),
      const QuickActionStatus(
        metric: ProgressMetric.steps,
        label: 'Daily Steps',
        done: 6.2,
        total: 10,
        unit: 'step',
      ),
    ],
    // Proves the restored 07-13 onboarding data actually reaches Today
    // through the one centralized BrainContext, not a second/competing
    // store: once a real goal was chosen on 07_goals, Today's tip
    // reflects it; otherwise the approved static per-variant copy is
    // used unchanged (never fabricated goal data).
    coachTip: brain.primaryGoal == null
        ? BrainInsight(message: variant.coachTip, source: 'figma_static')
        : BrainInsight(
            message:
                "Today's focus: ${brain.primaryGoal!.label.toLowerCase()}. ${variant.coachTip}",
            source: 'onboarding_goals',
          ),
  );
});
