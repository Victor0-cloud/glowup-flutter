import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../brain/brain_context.dart';
import '../../core/tod/tod_period.dart';
import '../../cycle/state/cycle_controller.dart';
import '../../onboarding/models/onboarding_profile.dart';
import '../../routines/models/routine_models.dart';
import '../../routines/state/routines_controller.dart';
import '../../water/data/water_repository.dart';
import '../../water/state/water_controller.dart';
import '../../workout/models/workout_completion_record.dart';
import '../../workout/state/workout_history_controller.dart';

/// What the AI Coach currently knows, assembled from every module that has
/// shipped so far. Matches the Figma "AI Brain Data Flow" annotation on
/// 23a/23e: **SENDS →** conversation/intent signals out to the (future)
/// brain; **RECEIVES ←** context drawn from onboarding, Today's TOD state,
/// Routines adherence today, real completed-workout data, and — as of the
/// Period & Cycle integration pass — real cycle day/period dates and
/// today's Daily Check-In (mood/energy/pain/symptoms). Journal contributes
/// too, but server-side only (see `coach-chat/index.ts`'s bounded
/// `journal_entries` summary query) rather than through this class, since
/// journal content is already durably synced to Supabase and must never
/// leave the device as raw text. [pendingModules] documents what's left
/// (nutrition, sleep, skin, progress) — those modules aren't built yet, so
/// nothing here fabricates their data; they simply aren't in this context
/// until they exist. Each field was only ever added once its source
/// genuinely persists real data for this context to read — never marked
/// done for a hardcoded value or an unused field.
class CoachBrainContext {
  const CoachBrainContext({
    required this.greetingName,
    required this.period,
    required this.primaryGoal,
    required this.routinesScheduledToday,
    required this.routinesCompletedToday,
    required this.activeStreakCount,
    required this.recentWorkouts,
    required this.latestWorkoutFeeling,
    required this.hasRecentPainFlag,
    required this.frequentlySkippedExerciseIds,
    required this.todayWaterMl,
    required this.todayWaterGoalMl,
    this.currentCycleDay,
    this.latestPeriodStart,
    this.predictedNextPeriodStart,
    this.todayCycleMood,
    this.todayCycleEnergyLevel,
    this.todayCyclePainIntensity,
    this.todayCycleSymptoms = const [],
    this.cycleAwareSuggestionsEnabled,
  });

  final String greetingName;
  final TodPeriod period;
  final Goal? primaryGoal;
  final int routinesScheduledToday;
  final int routinesCompletedToday;
  final int activeStreakCount;

  /// Most recent completed workouts first, capped to a small window — real
  /// stored [WorkoutCompletionRecord]s, durably saved by
  /// [WorkoutHistoryController], never fabricated.
  final List<WorkoutCompletionRecord> recentWorkouts;

  /// The [WorkoutFeeling] from the most recent record that actually has
  /// feedback (a "Skip for Now" record is simply not the one this reads —
  /// it keeps scanning further back), so e.g. "Too Hard" -> reduce
  /// difficulty and "Too Easy" (especially repeated) -> progress can be
  /// driven off a real, current rating rather than a stale or missing one.
  final WorkoutFeeling? latestWorkoutFeeling;

  /// True if any recent workout carries a pain/discomfort flag — signals
  /// the Coach should avoid or modify the exercises involved, never
  /// diagnose the cause itself.
  final bool hasRecentPainFlag;

  /// Exercise ids skipped in 2 or more of the recent workouts — a real
  /// adherence signal, not a guess, for the Coach to consider swapping or
  /// easing.
  final List<String> frequentlySkippedExerciseIds;

  /// Real, durable water-log totals for today — see
  /// [WaterController]/[WaterRepository]. `water` was removed from
  /// [pendingModules] only once this genuinely reads persisted entries,
  /// never a hardcoded value.
  final double todayWaterMl;
  final double todayWaterGoalMl;

  /// Real Period & Cycle data — [CycleController]'s own [CycleState],
  /// never fabricated and never a phase/fertility label (see
  /// `cycle_home_screen.dart`'s own doc comment on that rule — "day N"
  /// only). All null when the user has no periods logged yet, which the
  /// Coach must state honestly rather than guess. `cycle` was removed
  /// from [pendingModules] only once these genuinely read persisted
  /// state.
  final int? currentCycleDay;
  final DateTime? latestPeriodStart;
  final DateTime? predictedNextPeriodStart;

  /// Today's Daily Check-In fields (PC05), if logged — the same real
  /// [CycleDayEntry] the Cycle Home screen itself reads via
  /// `state.dayEntryFor(today)`.
  final String? todayCycleMood;
  final int? todayCycleEnergyLevel;
  final int? todayCyclePainIntensity;
  final List<String> todayCycleSymptoms;

  /// [CycleSettings.cycleAwareSuggestions] — whether the user has opted
  /// into cycle-aware suggestions at all. Null only when Cycle tracking
  /// itself was never set up (no [CycleState] loaded yet).
  final bool? cycleAwareSuggestionsEnabled;

  static const pendingModules = ['nutrition', 'sleep', 'skin', 'progress'];

  /// The exact, bounded payload sent to the `coach-chat` Edge Function —
  /// only these named fields, never raw workout/journal/mood content or
  /// any field not already listed on this class. See
  /// `RemoteCoachBrainService` and `supabase/functions/coach-chat/`.
  ///
  /// `currentLocalDate`/`currentLocalDateTime`/`timezoneOffsetMinutes` are
  /// computed fresh from `DateTime.now()` right here, inside this method —
  /// deliberately NOT stored as constructor fields set once when the
  /// provider last rebuilt. `coachBrainContextProvider` is a plain
  /// (non-autoDispose, non-timer) Riverpod `Provider`: it only recomputes
  /// when a *watched* dependency invalidates, so a `DateTime.now()` read
  /// during `build()` could go stale if the chat screen sits open a while
  /// before the user actually sends a message. Computing it here instead —
  /// at the moment `toRequestJson()` is actually called for a real
  /// request — guarantees the server always gets the true current moment
  /// (see the Aug-27 date-bug fix this comment documents).
  Map<String, dynamic> toRequestJson() {
    final now = DateTime.now();
    return {
      'greetingName': greetingName,
      'period': period.name,
      'currentLocalDate': _isoLocalDate(now),
      'currentLocalDateTime': _isoLocalDateTimeWithOffset(now),
      'timezoneOffsetMinutes': now.timeZoneOffset.inMinutes,
    if (primaryGoal != null) 'primaryGoal': primaryGoal!.name,
    'routinesScheduledToday': routinesScheduledToday,
    'routinesCompletedToday': routinesCompletedToday,
    'activeStreakCount': activeStreakCount,
    'recentWorkoutCount': recentWorkouts.length,
    if (latestWorkoutFeeling != null)
      'latestWorkoutFeeling': latestWorkoutFeeling!.name,
    'hasRecentPainFlag': hasRecentPainFlag,
    'todayWaterMl': todayWaterMl,
    'todayWaterGoalMl': todayWaterGoalMl,
    if (cycleAwareSuggestionsEnabled != null)
      'cycleAwareSuggestionsEnabled': cycleAwareSuggestionsEnabled,
    if (currentCycleDay != null) 'currentCycleDay': currentCycleDay,
    if (latestPeriodStart != null)
      'latestPeriodStart': latestPeriodStart!.toIso8601String(),
    if (predictedNextPeriodStart != null)
      'predictedNextPeriodStart': predictedNextPeriodStart!.toIso8601String(),
    if (todayCycleMood != null) 'todayCycleMood': todayCycleMood,
    if (todayCycleEnergyLevel != null)
      'todayCycleEnergyLevel': todayCycleEnergyLevel,
    if (todayCyclePainIntensity != null)
      'todayCyclePainIntensity': todayCyclePainIntensity,
      if (todayCycleSymptoms.isNotEmpty)
        'todayCycleSymptoms': todayCycleSymptoms,
    };
  }

  static String _isoLocalDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  /// A real ISO-8601 datetime string WITH the local UTC offset (e.g.
  /// `2026-08-26T07:34:00-04:00`) — `DateTime.now().toIso8601String()`
  /// alone omits the offset entirely for a non-UTC DateTime, which is the
  /// core of why the server previously had no way to know what "local"
  /// even meant for this request.
  static String _isoLocalDateTimeWithOffset(DateTime dt) {
    final offset = dt.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final absOffset = offset.abs();
    final offsetHours = absOffset.inHours.toString().padLeft(2, '0');
    final offsetMinutes = (absOffset.inMinutes % 60).toString().padLeft(
      2,
      '0',
    );
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
    return '${_isoLocalDate(dt)}T$time$sign$offsetHours:$offsetMinutes';
  }
}

/// How many most-recent completed workouts feed the Coach's short-term
/// context — enough to spot a real pattern (e.g. "Too Hard" twice in a
/// row) without unboundedly growing the context as history accumulates.
const _kRecentWorkoutWindow = 10;

final coachBrainContextProvider = Provider<CoachBrainContext?>((ref) {
  final brain = ref.watch(brainContextProvider);
  if (brain == null) return null;

  final period = ref.watch(currentTodPeriodProvider);
  final routines = ref.watch(routinesControllerProvider);
  final today = DateTime.now();
  final todayWeekday = Weekday.values[today.weekday - 1];
  final scheduledToday = routines
      .where((r) => r.schedule.days.contains(todayWeekday))
      .toList();

  ref.watch(
    routineCompletionsControllerProvider,
  ); // subscribe so this recomputes on toggles
  final completionsNotifier = ref.read(
    routineCompletionsControllerProvider.notifier,
  );
  final completedToday = scheduledToday.where((r) {
    if (r.activities.isEmpty) return false;
    final completion = completionsNotifier.completionFor(r.id, today);
    return completion.completedActivityIds.length == r.activities.length;
  }).length;

  final workoutHistory =
      ref.watch(workoutHistoryControllerProvider).valueOrNull ?? const [];
  final recentWorkouts = workoutHistory.reversed
      .take(_kRecentWorkoutWindow)
      .toList();

  WorkoutFeeling? latestFeeling;
  for (final record in recentWorkouts) {
    if (record.feeling != null) {
      latestFeeling = record.feeling;
      break;
    }
  }

  final hasRecentPainFlag = recentWorkouts.any((r) => r.hasPainFlag);

  final skipCounts = <String, int>{};
  for (final record in recentWorkouts) {
    for (final id in record.skippedExerciseIds) {
      skipCounts[id] = (skipCounts[id] ?? 0) + 1;
    }
  }
  final frequentlySkipped = [
    for (final entry in skipCounts.entries)
      if (entry.value >= 2) entry.key,
  ];

  final waterState = ref.watch(waterControllerProvider).valueOrNull;

  final cycleState = ref.watch(cycleControllerProvider).valueOrNull;
  final todayCycleEntry = cycleState?.dayEntryFor(today);

  return CoachBrainContext(
    greetingName: brain.greetingName,
    period: period,
    primaryGoal: brain.primaryGoal,
    routinesScheduledToday: scheduledToday.length,
    routinesCompletedToday: completedToday,
    activeStreakCount: routines.where((r) => r.hasStreak).length,
    recentWorkouts: recentWorkouts,
    latestWorkoutFeeling: latestFeeling,
    hasRecentPainFlag: hasRecentPainFlag,
    frequentlySkippedExerciseIds: frequentlySkipped,
    todayWaterMl: waterState?.todayTotal ?? 0,
    todayWaterGoalMl: waterState?.goalMl ?? WaterRepository.defaultGoalMl,
    currentCycleDay: cycleState?.currentCycleDay(today),
    latestPeriodStart: cycleState?.mostRecentPeriod?.startDate,
    predictedNextPeriodStart: cycleState?.estimatedNextPeriodStart,
    todayCycleMood: todayCycleEntry?.mood,
    todayCycleEnergyLevel: todayCycleEntry?.energyLevel,
    todayCyclePainIntensity: todayCycleEntry?.painIntensity,
    todayCycleSymptoms: todayCycleEntry?.symptoms.toList() ?? const [],
    cycleAwareSuggestionsEnabled: cycleState?.settings.cycleAwareSuggestions,
  );
});
