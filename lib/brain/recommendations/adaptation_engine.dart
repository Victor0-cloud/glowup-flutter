import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workout/models/workout_completion_record.dart'
    show WorkoutCompletionRecord;
import '../events/learning_event.dart' show EventModule;
import '../events/learning_event_controller.dart';
import '../patterns/learned_pattern_controller.dart';
import '../safety/safety_flag_controller.dart';
import '../safety/safety_rules.dart' show requiresSafetyPause;
import 'coach_recommendation.dart';
import 'coach_recommendation_controller.dart';
import 'context_bounds.dart';
import 'typed_action.dart';

/// Bump whenever the rules in [AdaptationEngine.decideForExercise] change,
/// so a stored decision stays auditable against the exact rule version
/// that produced it.
const kAdaptationRuleVersion = 1;

/// How long a stored decision stays valid before it's considered stale and
/// due for re-evaluation next time this exercise is a decision target.
const _kRecommendationValidity = Duration(hours: 24);

/// Tier 2 — the deterministic decision engine. Runs only on demand (a user
/// opening an exercise/workout, never per-event), never calls an AI
/// provider (nothing in this file or its imports can reach one), and must
/// be able to select and store a complete typed decision on its own. Tier
/// 3 may only turn whatever this selects into text — it can never see this
/// file's decision logic or override its output.
class AdaptationEngine {
  const AdaptationEngine(this._ref);

  final Ref _ref;

  static const _userId = WorkoutCompletionRecord.localProfileId;

  /// Steps 1-10 of the amendment's Tier 2 pipeline, scoped to one exercise.
  /// Returns the stored [CoachRecommendation], or null if the deterministic
  /// rules selected "keep plan unchanged" (a real, valid outcome — not
  /// every call produces a recommendation record).
  Future<CoachRecommendation?> decideForExercise({
    required String exerciseId,
    String? workoutId,
    ContextBounds bounds = kDefaultContextBounds,
  }) async {
    // Step 1: confirm the (local) authenticated user — trivial today, but
    // every stored record still carries a real userId so nothing needs to
    // be re-migrated once real auth exists.
    const userId = _userId;

    // Every controller this method reads self-initializes asynchronously
    // (SharedPreferences.getInstance()). Awaiting `ready` here closes the
    // same race already fixed once for `WorkoutHistoryController`/
    // `BatchScheduler`: without it, a caller that constructs this engine
    // and calls it in the very first frame a controller exists (e.g.
    // `WorkoutDetailScreen` opening for the first time this session) would
    // read `activeFlagFor`/`activeFor` before the underlying store had
    // finished loading and wrongly conclude "no safety flag, no pattern" —
    // a false negative on exactly the safety-critical path this exists
    // for.
    final eventController = _ref.read(learningEventControllerProvider.notifier);
    final safetyController = _ref.read(safetyFlagControllerProvider.notifier);
    final patternController = _ref.read(
      learnedPatternControllerProvider.notifier,
    );
    await eventController.ready;
    await safetyController.ready;
    await patternController.ready;

    // Step 2-3: load only bounded, relevant context — never the complete
    // history. This call alone proves context loading is bounded: it can
    // never return more than `bounds.maxEventsPerDecision` events or reach
    // further back than `bounds.maxLookbackDays`, regardless of how much
    // history this profile has accumulated.
    eventController.boundedFor(
      userId: userId,
      limit: bounds.maxEventsPerDecision,
      lookbackDays: bounds.maxLookbackDays,
    );

    // Step 4: goals/preferences aren't modeled yet (first slice is safety
    // + pattern driven only) — active patterns and safety constraints are.
    final safetyFlag = safetyController.activeFlagFor(exerciseId);
    final activePatterns = patternController
        .activeFor(limit: bounds.maxActivePatterns)
        .where((p) => p.subjectId == exerciseId)
        .toList();

    // Step 5-6: deterministic safety/eligibility rules, safety first,
    // always prioritized over any pattern-driven suggestion.
    TypedActionType? action;
    SafetyDecision safetyDecision = SafetyDecision.none;
    List<String> reasonCodes = const [];
    List<String> evidenceEventIds = const [];
    double confidence = 1.0;

    if (safetyFlag != null && requiresSafetyPause(safetyFlag)) {
      action = TypedActionType.triggerSafetyPause;
      safetyDecision = SafetyDecision.pause;
      reasonCodes = const ['safety_flag_severe_pain'];
      evidenceEventIds = safetyFlag.sourceEventIds;
      confidence = 1.0;
    } else if (safetyFlag != null) {
      action = TypedActionType.reduceDifficulty;
      safetyDecision = SafetyDecision.advisory;
      reasonCodes = const ['safety_flag_pain_reported'];
      evidenceEventIds = safetyFlag.sourceEventIds;
      confidence = 1.0;
    } else {
      final tooHard = activePatterns
          .where((p) => p.patternType == 'tooHardRepeated')
          .toList();
      final skipped = activePatterns
          .where((p) => p.patternType == 'consistentlySkipped')
          .toList();
      if (tooHard.isNotEmpty) {
        final pattern = tooHard.first;
        action = TypedActionType.reduceDifficulty;
        reasonCodes = const ['pattern_too_hard_repeated'];
        evidenceEventIds = pattern.supportingEventIds;
        confidence = pattern.confidence;
      } else if (skipped.isNotEmpty) {
        final pattern = skipped.first;
        action = TypedActionType.askFollowUpQuestion;
        reasonCodes = const ['pattern_consistently_skipped'];
        evidenceEventIds = pattern.supportingEventIds;
        confidence = pattern.confidence;
      }
    }

    // Step 8: "no change" is a real, valid decision — nothing is stored.
    if (action == null) return null;

    // Step 9-10: store the decision with reason codes, evidence, safety
    // result, rule version and confidence — a Tier 3 explanation is
    // attached later, on demand, never inline here.
    final now = DateTime.now();
    final recommendation = CoachRecommendation(
      id: 'rec_${now.microsecondsSinceEpoch}',
      userId: userId,
      action: action,
      targetModule: EventModule.workout,
      targetEntityId: exerciseId,
      reasonCodes: reasonCodes,
      evidenceEventIds: evidenceEventIds,
      safetyDecision: safetyDecision,
      confidence: confidence,
      ruleVersion: kAdaptationRuleVersion,
      createdAt: now,
      expiresAt: now.add(_kRecommendationValidity),
    );
    final recommendationController = _ref.read(
      coachRecommendationControllerProvider.notifier,
    );
    await recommendationController.ready;
    return recommendationController.store(recommendation);
  }
}

final adaptationEngineProvider = Provider<AdaptationEngine>(
  (ref) => AdaptationEngine(ref),
);
