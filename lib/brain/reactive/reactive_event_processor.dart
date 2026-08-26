import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../events/learning_event.dart';
import '../patterns/learned_pattern_controller.dart';
import '../safety/safety_flag_controller.dart';
import '../state/current_state_controller.dart';
import '../state/current_state_entry.dart';

/// Tier 1 — runs synchronously right after a relevant event is accepted by
/// Tier 0. Everything this class does is pure/deterministic: updates
/// current-state snapshots, sets/escalates safety flags, and increments
/// pattern evidence. Nothing here imports anything from `lib/brain/
/// expression/` (Tier 3) or calls the adaptation engine (Tier 2) — by
/// construction, Tier 1 cannot reach an AI provider, and a pain event is
/// fully processed (safety flag set) whether or not Tier 2/3 ever run.
class ReactiveEventProcessor {
  const ReactiveEventProcessor(this._ref);

  final Ref _ref;

  /// How long a pain-driven current-state entry stays "current" before it
  /// stops being treated as fresh soreness — distinct from (and shorter
  /// than) the longer-lived safety flag itself.
  static const _sorenessCurrentStateTtl = Duration(hours: 48);

  Future<void> process(LearningEvent event) async {
    switch (event.type) {
      case LearningEventType.painReported:
        await _handlePainReported(event);
      case LearningEventType.exerciseFeedbackSubmitted:
        await _handleExerciseFeedback(event);
      case LearningEventType.exerciseSkipped:
        await _handlePatternEvidence(
          patternType: 'consistentlySkipped',
          subjectId: (event.payload as ExerciseLifecyclePayload).exerciseId,
          summary: 'This exercise has been skipped multiple times recently.',
          eventId: event.id,
          supports: true,
        );
      case LearningEventType.exerciseCompleted:
        await _handlePatternEvidence(
          patternType: 'consistentlySkipped',
          subjectId: (event.payload as ExerciseLifecyclePayload).exerciseId,
          summary: 'This exercise has been skipped multiple times recently.',
          eventId: event.id,
          supports: false,
        );
      case LearningEventType.hydrationLogged:
        await _handleHydrationLogged(event);
      case LearningEventType.foodScanConfirmed:
      case LearningEventType.mealManuallyConfirmed:
        await _handleMealConfirmed(event);
      case LearningEventType.facialCheckInConfirmed:
        await _handleFacialCheckIn(event);
      case LearningEventType.periodLogged:
        await _handlePeriodLogged(event);
      case LearningEventType.cycleDayLogged:
        await _handleCycleDayLogged(event);
      case LearningEventType.moodCheckedIn:
        await _handleMoodCheckedIn(event);
      case LearningEventType.notebookEntryLogged:
        await _handleNotebookEntryLogged(event);
      case LearningEventType.exerciseQuestionAsked:
      case LearningEventType.scanDataDeleted:
      case LearningEventType.productScanConfirmed:
      case LearningEventType.productAddedToList:
      case LearningEventType.productPurchased:
      case LearningEventType.exerciseStarted:
      case LearningEventType.exerciseStoppedEarly:
      case LearningEventType.exerciseRepeated:
      case LearningEventType.exerciseReplaced:
      case LearningEventType.workoutCompleted:
      case LearningEventType.sessionFeedbackSubmitted:
      case LearningEventType.recommendationShown:
      case LearningEventType.recommendationAccepted:
      case LearningEventType.recommendationDismissed:
      case LearningEventType.recommendationModified:
      case LearningEventType.recommendationCompleted:
      case LearningEventType.planModified:
      case LearningEventType.walkStarted:
      case LearningEventType.walkCompleted:
      case LearningEventType.dailyStepsSnapshot:
      case LearningEventType.stepGoalReached:
        // Ingested at Tier 0; no Tier 1 reactive processing defined for
        // these in this first slice (documented scope, not an omission —
        // see the Architecture Gap Report's first-slice list).
        return;
    }
  }

  /// However many `hydrationLogged` events fire for one calendar day, this
  /// always upserts the *same* [CurrentStateEntry] key (`setEntry` is an
  /// upsert by (userId, key) — see `CurrentStateRepository`), so "today's
  /// hydration state" collapses to exactly one deterministic snapshot per
  /// day no matter how many times the user adds or removes an entry.
  /// Expires at local midnight — the day's aggregate is only ever "current"
  /// for that one calendar day, matching the local-day-rollover behavior
  /// the Water Tracker itself already has (a new day starts its own total
  /// without deleting history).
  Future<void> _handleHydrationLogged(LearningEvent event) async {
    final payload = event.payload as HydrationAggregatePayload;
    final now = event.occurredAt;
    final localMidnight = DateTime(now.year, now.month, now.day + 1);
    await _ref
        .read(currentStateControllerProvider.notifier)
        .setEntry(
          CurrentStateEntry(
            userId: event.userId,
            key: 'hydration:${payload.dateKey}',
            value: '${payload.totalMl.round()}/${payload.goalMl.round()}',
            recordedAt: now,
            expiresAt: localMidnight,
            sourceEventId: event.id,
          ),
        );
  }

  Future<void> _handlePainReported(LearningEvent event) async {
    final payload = event.payload as PainReportPayload;
    final exerciseId = payload.exerciseId;
    if (exerciseId == null) return;
    final severity = event.safetySeverity;
    if (severity == null) return;

    final now = DateTime.now();
    await _ref
        .read(safetyFlagControllerProvider.notifier)
        .registerPainReport(
          exerciseId: exerciseId,
          bodyArea: payload.details.bodyArea,
          severity: severity,
          sourceEventId: event.id,
        );

    await _ref
        .read(currentStateControllerProvider.notifier)
        .setEntry(
          CurrentStateEntry(
            userId: event.userId,
            key: 'soreness:$exerciseId',
            value: severity.name,
            recordedAt: now,
            expiresAt: now.add(_sorenessCurrentStateTtl),
            sourceEventId: event.id,
          ),
        );

    await _handlePatternEvidence(
      patternType: 'painRepeated',
      subjectId: exerciseId,
      summary:
          'Pain or discomfort has been reported for this exercise more than once.',
      eventId: event.id,
      supports: true,
    );
  }

  /// Deterministic "last confirmed meal" snapshot — a real, bounded Coach
  /// signal (item count only, never nutrition values the app never
  /// computed) without needing to re-read the Food Scan repository from
  /// Tier 1. Expires after a day, matching how a "today" signal should
  /// age out.
  Future<void> _handleMealConfirmed(LearningEvent event) async {
    final payload = event.payload as MealConfirmedPayload;
    final now = event.occurredAt;
    await _ref
        .read(currentStateControllerProvider.notifier)
        .setEntry(
          CurrentStateEntry(
            userId: event.userId,
            key: 'nutrition:lastMeal',
            value:
                '${payload.itemLabels.length} item${payload.itemLabels.length == 1 ? '' : 's'} logged',
            recordedAt: now,
            expiresAt: now.add(const Duration(hours: 24)),
            sourceEventId: event.id,
          ),
        );
  }

  /// Deterministic "last check-in" snapshot — the user's own self-reported
  /// area labels only, never a generated score or diagnosis.
  Future<void> _handleFacialCheckIn(LearningEvent event) async {
    final payload = event.payload as FacialCheckInPayload;
    final now = event.occurredAt;
    await _ref
        .read(currentStateControllerProvider.notifier)
        .setEntry(
          CurrentStateEntry(
            userId: event.userId,
            key: 'personalCare:lastCheckIn',
            value: payload.selfReportedAreas.isEmpty
                ? 'checked in'
                : payload.selfReportedAreas.join(', '),
            recordedAt: now,
            expiresAt: now.add(const Duration(days: 7)),
            sourceEventId: event.id,
          ),
        );
  }

  /// Deterministic, bounded "is a period currently active" snapshot only
  /// — never a prediction, never medical/contraceptive advice. A `start`
  /// sets it; an `end` clears it. Any actual next-period *estimate* is
  /// computed client-side from stored period history (see
  /// `CycleController.estimatedNextPeriodStart`), not by the Brain.
  Future<void> _handlePeriodLogged(LearningEvent event) async {
    final payload = event.payload as PeriodLoggedPayload;
    final now = event.occurredAt;
    if (payload.kind == 'start') {
      await _ref
          .read(currentStateControllerProvider.notifier)
          .setEntry(
            CurrentStateEntry(
              userId: event.userId,
              key: 'cycle:periodActive',
              value: payload.dateKey,
              recordedAt: now,
              expiresAt: now.add(const Duration(days: 10)),
              sourceEventId: event.id,
            ),
          );
    } else {
      await _ref
          .read(currentStateControllerProvider.notifier)
          .setEntry(
            CurrentStateEntry(
              userId: event.userId,
              key: 'cycle:periodActive',
              value: 'false',
              recordedAt: now,
              expiresAt: now.add(const Duration(days: 1)),
              sourceEventId: event.id,
            ),
          );
    }
  }

  /// Deterministic "last logged cycle-day" snapshot — a real, bounded
  /// signal (symptom/mood/energy labels only, never a note's text) for an
  /// adaptive surface to *optionally* read later. Never itself triggers a
  /// recommendation or an AI call.
  Future<void> _handleCycleDayLogged(LearningEvent event) async {
    final payload = event.payload as CycleDayPayload;
    final now = event.occurredAt;
    final parts = [
      if (payload.flow != null) 'flow:${payload.flow}',
      if (payload.mood != null) 'mood:${payload.mood}',
      if (payload.energyLevel != null) 'energy:${payload.energyLevel}',
      if (payload.symptoms.isNotEmpty) 'symptoms:${payload.symptoms.join(",")}',
    ];
    await _ref
        .read(currentStateControllerProvider.notifier)
        .setEntry(
          CurrentStateEntry(
            userId: event.userId,
            key: 'cycle:lastDay',
            value: parts.isEmpty ? payload.dateKey : parts.join(';'),
            recordedAt: now,
            expiresAt: now.add(const Duration(days: 2)),
            sourceEventId: event.id,
          ),
        );
  }

  /// Deterministic "last logged mood" snapshot — level/reasons/energy/
  /// stress labels only, never a note's text, never a diagnosis. Never
  /// itself triggers a recommendation or an AI call.
  Future<void> _handleMoodCheckedIn(LearningEvent event) async {
    final payload = event.payload as MoodCheckInPayload;
    final now = event.occurredAt;
    final parts = [
      'level:${payload.level}',
      if (payload.reasons.isNotEmpty) 'reasons:${payload.reasons.join(",")}',
      if (payload.energyLevel != null) 'energy:${payload.energyLevel}',
      if (payload.stressLevel != null) 'stress:${payload.stressLevel}',
    ];
    await _ref
        .read(currentStateControllerProvider.notifier)
        .setEntry(
          CurrentStateEntry(
            userId: event.userId,
            key: 'mood:lastCheckIn',
            value: parts.join(';'),
            recordedAt: now,
            expiresAt: now.add(const Duration(days: 2)),
            sourceEventId: event.id,
          ),
        );
  }

  /// Deterministic "last notebook entry" snapshot — feeling label only,
  /// never the note text, never a diagnosis.
  Future<void> _handleNotebookEntryLogged(LearningEvent event) async {
    final payload = event.payload as NotebookEntryPayload;
    final now = event.occurredAt;
    await _ref
        .read(currentStateControllerProvider.notifier)
        .setEntry(
          CurrentStateEntry(
            userId: event.userId,
            key: 'cycle:lastNotebookEntry',
            value: payload.feeling ?? payload.dateKey,
            recordedAt: now,
            expiresAt: now.add(const Duration(days: 2)),
            sourceEventId: event.id,
          ),
        );
  }

  Future<void> _handleExerciseFeedback(LearningEvent event) async {
    final payload = event.payload as FeedbackPayload;
    final exerciseId = payload.exerciseId;
    if (exerciseId == null) return;
    await _handlePatternEvidence(
      patternType: 'tooHardRepeated',
      subjectId: exerciseId,
      summary: 'This exercise has repeatedly been rated Too Hard.',
      eventId: event.id,
      supports: payload.feeling.name == 'tooHard',
    );
  }

  Future<void> _handlePatternEvidence({
    required String patternType,
    required String subjectId,
    required String summary,
    required String eventId,
    required bool supports,
  }) async {
    await _ref
        .read(learnedPatternControllerProvider.notifier)
        .recordEvidence(
          patternType: patternType,
          subjectId: subjectId,
          summary: summary,
          eventId: eventId,
          supports: supports,
        );
  }
}

final reactiveEventProcessorProvider = Provider<ReactiveEventProcessor>(
  (ref) => ReactiveEventProcessor(ref),
);
