import 'dart:convert';

import '../../workout/models/workout_completion_record.dart'
    show PainDetails, PainSeverity, WorkoutFeeling;

/// Every module a future event can be attributed to. Extending this list is
/// how a new wellness module "connects later without changing the central
/// Brain" — nothing else in Tier 0/1/2 needs to change when a module is
/// added here.
enum EventModule {
  workout,
  water,
  mood,
  energy,
  journal,
  nutrition,
  sleep,
  recovery,
  mobility,
  swimming,
  hydration,
  foodScan,
  meditation,
  breathing,
  progress,
  facialScan,
  personalCare,
  connectedHealth,
  cycle,
  shop,
  walking,
}

/// The canonical, versioned learning-event types (first slice: only the 16
/// explicitly specified). Adding a 17th type means adding one enum value +
/// one [kEventTypeSchemas] entry + one payload mapping — never a change to
/// the ingestion/reactive/decision pipelines themselves.
enum LearningEventType {
  exerciseStarted,
  exerciseCompleted,
  exerciseSkipped,
  exerciseStoppedEarly,
  exerciseRepeated,
  exerciseReplaced,
  exerciseFeedbackSubmitted,
  painReported,
  workoutCompleted,
  sessionFeedbackSubmitted,
  recommendationShown,
  recommendationAccepted,
  recommendationDismissed,
  recommendationModified,
  recommendationCompleted,
  planModified,

  /// A 17th type, additive only — see the enum's own doc comment. Fired
  /// once per real water-log mutation (add or remove), never once per
  /// rapid/duplicate tap (Tier 0 idempotency + the water screen's own
  /// dedup guard prevent that) and never inside a loop over entries.
  /// Carries the *current day's aggregate* (total/goal/count), not just
  /// the single entry that changed — Tier 1 upserts this into one
  /// [CurrentStateEntry] per day, so however many of these fire in a day,
  /// "today's hydration state" is always exactly one deterministic
  /// snapshot, never one-record-per-sip.
  hydrationLogged,

  /// 18th type — fired when the user asks the contextual "Ask Coach about
  /// this exercise" question. Tier 0 ingest/record only; the answer itself
  /// is rendered client-side from approved exercise data (see
  /// `ExerciseCoachAnswerService`), so this event never triggers or
  /// represents an AI call — it exists purely as a durable record of what
  /// was asked, never the answer text.
  exerciseQuestionAsked,

  /// 19th type — a meal confirmed after the Food Scan photo-review flow
  /// (manual entry over a captured/selected photo, since no automatic
  /// detection is connected in this build — see `FoodAnalysisProvider`).
  foodScanConfirmed,

  /// 20th type — a meal confirmed with no photo at all (pure manual
  /// entry). Kept distinct from [foodScanConfirmed] so provenance
  /// (photo-assisted vs. typed) is never lost.
  mealManuallyConfirmed,

  /// 21st type — a Facial Scan wellness check-in confirmed (manual
  /// check-in, with or without a saved photo — see
  /// `FacialWellnessAnalysisProvider`). Never a diagnosis.
  facialCheckInConfirmed,

  /// 22nd type — records that the user deleted a stored scan image/result
  /// (Food or Facial Scan). Never carries the deleted content itself.
  scanDataDeleted,

  /// 23rd type — a period start or end date logged. Tier 1 upserts a
  /// deterministic current-cycle-phase snapshot; never itself a
  /// recommendation, prediction claim, or medical/contraceptive advice.
  periodLogged,

  /// 24th type — one day's optional flow/symptoms/mood/energy/sleep/note
  /// entry. Kept separate from [periodLogged] since a day can be logged
  /// with no period boundary changing.
  cycleDayLogged,

  /// 25th type — a Glow Shop Scanner product confirmed and saved to the
  /// product library (from a barcode lookup, a label-photo analysis, or
  /// fully manual entry — see [ProductDataSource]). Never fired for an
  /// unconfirmed lookup result.
  productScanConfirmed,

  /// 26th type — a saved product added to a grocery or fitness/wellness
  /// list. Carries only category/list-type/quantity, never a price (see
  /// [ProductAddedToListPayload]).
  productAddedToList,

  /// 27th type — a list item marked purchased. Carries the spent amount
  /// and currency actually entered by the user — never inferred, never a
  /// barcode-database price.
  productPurchased,

  /// 28th type — one day's mood check-in (level + optional reasons/energy/
  /// stress). Kept separate from [cycleDayLogged] since Mood Check-In has
  /// no dependency on Period & Cycle being enabled at all.
  moodCheckedIn,

  /// 29th type — a Period & Cycle Daily Notebook entry (PC07), fired only
  /// when the woman explicitly turned on "Let Glow Up Brain use this
  /// note" for that specific entry. Kept separate from [cycleDayLogged]
  /// (symptom/energy/mood tracking) since the notebook is a distinct,
  /// separately-consented record type per the approved data contract.
  notebookEntryLogged,

  /// 30th type — an intentional in-app walk session started (Section 9 of
  /// the standalone Walking & Steps feature). Never fired for ambient
  /// daily step accumulation — only a real "Start Walk" tap.
  walkStarted,

  /// 31st type — a walk session finished (paused/resumed transitions are
  /// local-only UI state, never their own event). Carries the session's
  /// own real duration/steps/distance — never the phone's whole-day step
  /// total, which is [dailyStepsSnapshot]'s job.
  walkCompleted,

  /// 32nd type — a bounded daily aggregate (like [hydrationLogged]): the
  /// current day's real cumulative step count as of the moment this event
  /// was built. Never one event per individual step — see the module's
  /// own "do not create one Brain event for every step" requirement.
  dailyStepsSnapshot,

  /// 33rd type — fired at most once per calendar day, the first time that
  /// day's step count reaches the user's goal.
  stepGoalReached,
}

enum EventSource { explicit, behavioral, imported, inferred }

/// What an event's content is allowed to be used for. `deviceLocal` is the
/// only scope that exists in practice today (this app has no network path
/// at all) — `aiExpressionEligible` is reserved for the day Tier 3 gets a
/// real provider and marks which validated slots may ever leave the device
/// as part of a bounded prompt. Free-text fields (e.g. a journal/reflection
/// note) must never carry `aiExpressionEligible` without explicit user
/// confirmation at capture time — see [EventTypeSchema.requiredConsent].
enum ConsentScope { deviceLocal, aiExpressionEligible }

enum RetentionPolicy {
  /// Kept in full for the hot window, then eligible to be rolled into an
  /// aggregate record once out of window (Tier 4) — unless referenced by an
  /// active pattern or stored recommendation, in which case it is preserved
  /// regardless of age (see `LearningEventRepository.isProtected`).
  hotWindowThenAggregate,

  /// Never auto-rolled-up; safety evidence follows its own longer floor.
  safetyExtended,
}

enum SamplingPolicy {
  /// Every occurrence becomes an event.
  always,

  /// High-frequency/low-signal occurrences are expected to be pre-aggregated
  /// by the emitting module before this event type is ever constructed
  /// (e.g. a daily hydration rollup) — this event type itself still always
  /// ingests whatever it's given, the rollup discipline lives upstream.
  moduleAggregated,
}

/// Per-event-type governance, declared once and read everywhere (Tier 0
/// payload-size validation, Tier 1 safety/pattern eligibility, Tier 4
/// retention) — this is what keeps [LearningEvent.payload] from becoming an
/// unrestricted dumping ground: every type's shape, size ceiling and
/// consent requirement is fixed data, not ad hoc per call site.
class EventTypeSchema {
  const EventTypeSchema({
    required this.type,
    required this.maxPayloadBytes,
    required this.retention,
    required this.sampling,
    required this.requiredConsent,
    required this.affectsSafety,
    required this.contributesToPatternEvidence,
  });

  final LearningEventType type;
  final int maxPayloadBytes;
  final RetentionPolicy retention;
  final SamplingPolicy sampling;
  final ConsentScope requiredConsent;
  final bool affectsSafety;
  final bool contributesToPatternEvidence;
}

const kEventTypeSchemas = <LearningEventType, EventTypeSchema>{
  LearningEventType.exerciseStarted: EventTypeSchema(
    type: LearningEventType.exerciseStarted,
    maxPayloadBytes: 1024,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: false,
  ),
  LearningEventType.exerciseCompleted: EventTypeSchema(
    type: LearningEventType.exerciseCompleted,
    maxPayloadBytes: 1024,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: true,
  ),
  LearningEventType.exerciseSkipped: EventTypeSchema(
    type: LearningEventType.exerciseSkipped,
    maxPayloadBytes: 1024,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: true,
  ),
  LearningEventType.exerciseStoppedEarly: EventTypeSchema(
    type: LearningEventType.exerciseStoppedEarly,
    maxPayloadBytes: 1024,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: true,
  ),
  LearningEventType.exerciseRepeated: EventTypeSchema(
    type: LearningEventType.exerciseRepeated,
    maxPayloadBytes: 1024,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: true,
  ),
  LearningEventType.exerciseReplaced: EventTypeSchema(
    type: LearningEventType.exerciseReplaced,
    maxPayloadBytes: 1024,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: true,
  ),
  LearningEventType.exerciseFeedbackSubmitted: EventTypeSchema(
    type: LearningEventType.exerciseFeedbackSubmitted,
    maxPayloadBytes: 2048,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: true,
  ),
  LearningEventType.painReported: EventTypeSchema(
    type: LearningEventType.painReported,
    maxPayloadBytes: 2048,
    retention: RetentionPolicy.safetyExtended,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: true,
    contributesToPatternEvidence: true,
  ),
  LearningEventType.workoutCompleted: EventTypeSchema(
    type: LearningEventType.workoutCompleted,
    maxPayloadBytes: 2048,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: true,
  ),
  LearningEventType.sessionFeedbackSubmitted: EventTypeSchema(
    type: LearningEventType.sessionFeedbackSubmitted,
    maxPayloadBytes: 2048,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: true,
  ),
  LearningEventType.recommendationShown: EventTypeSchema(
    type: LearningEventType.recommendationShown,
    maxPayloadBytes: 512,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: false,
  ),
  LearningEventType.recommendationAccepted: EventTypeSchema(
    type: LearningEventType.recommendationAccepted,
    maxPayloadBytes: 512,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: true,
  ),
  LearningEventType.recommendationDismissed: EventTypeSchema(
    type: LearningEventType.recommendationDismissed,
    maxPayloadBytes: 512,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: true,
  ),
  LearningEventType.recommendationModified: EventTypeSchema(
    type: LearningEventType.recommendationModified,
    maxPayloadBytes: 512,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: true,
  ),
  LearningEventType.recommendationCompleted: EventTypeSchema(
    type: LearningEventType.recommendationCompleted,
    maxPayloadBytes: 512,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: true,
  ),
  LearningEventType.planModified: EventTypeSchema(
    type: LearningEventType.planModified,
    maxPayloadBytes: 1024,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: false,
  ),
  LearningEventType.hydrationLogged: EventTypeSchema(
    type: LearningEventType.hydrationLogged,
    maxPayloadBytes: 256,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    // A sustained hydration shortfall is a real, evidence-worthy signal
    // for a future "hydration adherence" pattern (Tier 1 evidence
    // increment, Tier 4 promotion) — same shape as exerciseCompleted.
    contributesToPatternEvidence: true,
  ),
  LearningEventType.exerciseQuestionAsked: EventTypeSchema(
    type: LearningEventType.exerciseQuestionAsked,
    maxPayloadBytes: 1024,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: false,
  ),
  LearningEventType.foodScanConfirmed: EventTypeSchema(
    type: LearningEventType.foodScanConfirmed,
    maxPayloadBytes: 2048,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: true,
  ),
  LearningEventType.mealManuallyConfirmed: EventTypeSchema(
    type: LearningEventType.mealManuallyConfirmed,
    maxPayloadBytes: 2048,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: true,
  ),
  LearningEventType.facialCheckInConfirmed: EventTypeSchema(
    type: LearningEventType.facialCheckInConfirmed,
    maxPayloadBytes: 1024,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: true,
  ),
  LearningEventType.scanDataDeleted: EventTypeSchema(
    type: LearningEventType.scanDataDeleted,
    maxPayloadBytes: 512,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: false,
  ),
  LearningEventType.periodLogged: EventTypeSchema(
    type: LearningEventType.periodLogged,
    maxPayloadBytes: 256,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: true,
  ),
  LearningEventType.cycleDayLogged: EventTypeSchema(
    type: LearningEventType.cycleDayLogged,
    maxPayloadBytes: 1024,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: true,
  ),
  LearningEventType.productScanConfirmed: EventTypeSchema(
    type: LearningEventType.productScanConfirmed,
    maxPayloadBytes: 1024,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: true,
  ),
  LearningEventType.productAddedToList: EventTypeSchema(
    type: LearningEventType.productAddedToList,
    maxPayloadBytes: 512,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: true,
  ),
  LearningEventType.productPurchased: EventTypeSchema(
    type: LearningEventType.productPurchased,
    maxPayloadBytes: 512,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: true,
  ),
  LearningEventType.moodCheckedIn: EventTypeSchema(
    type: LearningEventType.moodCheckedIn,
    maxPayloadBytes: 512,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: true,
  ),
  LearningEventType.notebookEntryLogged: EventTypeSchema(
    type: LearningEventType.notebookEntryLogged,
    maxPayloadBytes: 256,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: true,
  ),
  LearningEventType.walkStarted: EventTypeSchema(
    type: LearningEventType.walkStarted,
    maxPayloadBytes: 512,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: false,
  ),
  LearningEventType.walkCompleted: EventTypeSchema(
    type: LearningEventType.walkCompleted,
    maxPayloadBytes: 1024,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    // Structured duration/steps/distance/pace only, never free text — the
    // Coach needs this to answer "what was my last walk" truthfully, the
    // same reasoning already applied to workoutCompleted.
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: true,
  ),
  LearningEventType.dailyStepsSnapshot: EventTypeSchema(
    type: LearningEventType.dailyStepsSnapshot,
    maxPayloadBytes: 256,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.moduleAggregated,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: true,
  ),
  LearningEventType.stepGoalReached: EventTypeSchema(
    type: LearningEventType.stepGoalReached,
    maxPayloadBytes: 256,
    retention: RetentionPolicy.hotWindowThenAggregate,
    sampling: SamplingPolicy.always,
    requiredConsent: ConsentScope.deviceLocal,
    affectsSafety: false,
    contributesToPatternEvidence: true,
  ),
};

/// Base type for every event's typed payload. Concrete subclasses are the
/// only way to construct a payload — there is no generic "put whatever you
/// want in this map" constructor anywhere in this file.
abstract class EventPayload {
  const EventPayload();
  Map<String, dynamic> toJson();
}

/// exerciseStarted / exerciseCompleted / exerciseSkipped /
/// exerciseStoppedEarly / exerciseRepeated / exerciseReplaced.
class ExerciseLifecyclePayload extends EventPayload {
  const ExerciseLifecyclePayload({
    required this.exerciseId,
    this.workoutId,
    this.replacementExerciseId,
    this.reasonCode,
    this.exerciseName,
    this.category,
  });

  final String exerciseId;
  final String? workoutId;

  /// Only meaningful for [LearningEventType.exerciseReplaced].
  final String? replacementExerciseId;

  /// A short, structured code (e.g. `'user_skip'`, `'time_constraint'`) —
  /// never free text, so this never becomes a personal-data dumping ground.
  final String? reasonCode;

  /// [ExerciseDefinition.displayName] at the moment this event fired —
  /// additive, optional (older serialized events never had it). Without
  /// this, only an opaque id ever reaches the Coach Brain, which is why
  /// it previously couldn't answer "what exercise did I just do."
  final String? exerciseName;

  /// [ExerciseDefinition.category] — a short string, never free text.
  final String? category;

  factory ExerciseLifecyclePayload.fromJson(Map<String, dynamic> j) =>
      ExerciseLifecyclePayload(
        exerciseId: j['exerciseId'] as String,
        workoutId: j['workoutId'] as String?,
        replacementExerciseId: j['replacementExerciseId'] as String?,
        reasonCode: j['reasonCode'] as String?,
        exerciseName: j['exerciseName'] as String?,
        category: j['category'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    if (workoutId != null) 'workoutId': workoutId,
    if (replacementExerciseId != null)
      'replacementExerciseId': replacementExerciseId,
    if (reasonCode != null) 'reasonCode': reasonCode,
    if (exerciseName != null) 'exerciseName': exerciseName,
    if (category != null) 'category': category,
  };
}

/// exerciseFeedbackSubmitted / sessionFeedbackSubmitted. Reuses
/// [WorkoutFeeling] (already the real, shipped rating type behind
/// `PostWorkoutFeedbackCard`) instead of inventing a parallel rating enum.
class FeedbackPayload extends EventPayload {
  const FeedbackPayload({
    required this.feeling,
    this.exerciseId,
    this.note,
    this.chips = const [],
  });

  final WorkoutFeeling feeling;

  /// Null for session-level feedback.
  final String? exerciseId;
  final String? note;

  /// Selected fixed-vocabulary feedback chips (e.g. "Form felt unclear") —
  /// additive field, defaults to empty so every pre-existing serialized
  /// event (which never had this key) still parses unchanged.
  final List<String> chips;

  factory FeedbackPayload.fromJson(Map<String, dynamic> j) => FeedbackPayload(
    feeling: WorkoutFeeling.values.byName(j['feeling'] as String),
    exerciseId: j['exerciseId'] as String?,
    note: j['note'] as String?,
    chips: (j['chips'] as List?)?.cast<String>() ?? const [],
  );

  @override
  Map<String, dynamic> toJson() => {
    'feeling': feeling.name,
    if (exerciseId != null) 'exerciseId': exerciseId,
    if (note != null) 'note': note,
    if (chips.isNotEmpty) 'chips': chips,
  };
}

/// painReported — always its own event, never folded into general
/// feedback. Reuses [PainDetails] (already shipped behind the Workout
/// Module's Pain/Discomfort follow-up) rather than a second pain model.
class PainReportPayload extends EventPayload {
  const PainReportPayload({
    required this.details,
    this.exerciseId,
    this.wantsToStop = false,
    this.wantsToReplace = false,
  });

  final PainDetails details;
  final String? exerciseId;
  final bool wantsToStop;
  final bool wantsToReplace;

  factory PainReportPayload.fromJson(Map<String, dynamic> j) =>
      PainReportPayload(
        details: PainDetails.fromJson(j['details'] as Map<String, dynamic>),
        exerciseId: j['exerciseId'] as String?,
        wantsToStop: j['wantsToStop'] as bool? ?? false,
        wantsToReplace: j['wantsToReplace'] as bool? ?? false,
      );

  @override
  Map<String, dynamic> toJson() => {
    'details': details.toJson(),
    if (exerciseId != null) 'exerciseId': exerciseId,
    'wantsToStop': wantsToStop,
    'wantsToReplace': wantsToReplace,
  };
}

/// workoutCompleted.
class WorkoutCompletedPayload extends EventPayload {
  const WorkoutCompletedPayload({
    required this.workoutId,
    required this.totalDurationSeconds,
    required this.completedExerciseIds,
    required this.skippedExerciseIds,
    this.workoutName,
    this.category,
  });

  final String workoutId;
  final int totalDurationSeconds;
  final List<String> completedExerciseIds;
  final List<String> skippedExerciseIds;

  /// [WorkoutCompletionRecord.workoutName] — additive, optional (older
  /// serialized events never had it). Without this, only an opaque id
  /// ever reaches the Coach Brain.
  final String? workoutName;

  /// [Workout.category.name] — a short enum-name string, never free text.
  final String? category;

  factory WorkoutCompletedPayload.fromJson(Map<String, dynamic> j) =>
      WorkoutCompletedPayload(
        workoutId: j['workoutId'] as String,
        totalDurationSeconds: j['totalDurationSeconds'] as int,
        completedExerciseIds: (j['completedExerciseIds'] as List)
            .cast<String>(),
        skippedExerciseIds: (j['skippedExerciseIds'] as List).cast<String>(),
        workoutName: j['workoutName'] as String?,
        category: j['category'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
    'workoutId': workoutId,
    'totalDurationSeconds': totalDurationSeconds,
    'completedExerciseIds': completedExerciseIds,
    'skippedExerciseIds': skippedExerciseIds,
    if (workoutName != null) 'workoutName': workoutName,
    if (category != null) 'category': category,
  };
}

/// recommendationShown / Accepted / Dismissed / Modified / Completed.
class RecommendationOutcomePayload extends EventPayload {
  const RecommendationOutcomePayload({
    required this.recommendationId,
    this.note,
  });

  final String recommendationId;
  final String? note;

  factory RecommendationOutcomePayload.fromJson(Map<String, dynamic> j) =>
      RecommendationOutcomePayload(
        recommendationId: j['recommendationId'] as String,
        note: j['note'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
    'recommendationId': recommendationId,
    if (note != null) 'note': note,
  };
}

/// hydrationLogged — the *current day's aggregate*, not the individual
/// entry. [totalMl]/[goalMl]/[entryCount] are always the day's numbers as
/// of the moment this event was built, so a single stored event is always
/// self-sufficient (no need to replay every entry to know where the day
/// stood).
class HydrationAggregatePayload extends EventPayload {
  const HydrationAggregatePayload({
    required this.dateKey,
    required this.totalMl,
    required this.goalMl,
    required this.entryCount,
  });

  /// Local calendar date this aggregate is for, `yyyy-MM-dd` — the same
  /// key [ReactiveEventProcessor] uses for the day's [CurrentStateEntry].
  final String dateKey;
  final double totalMl;
  final double goalMl;
  final int entryCount;

  factory HydrationAggregatePayload.fromJson(Map<String, dynamic> j) =>
      HydrationAggregatePayload(
        dateKey: j['dateKey'] as String,
        totalMl: (j['totalMl'] as num).toDouble(),
        goalMl: (j['goalMl'] as num).toDouble(),
        entryCount: j['entryCount'] as int,
      );

  @override
  Map<String, dynamic> toJson() => {
    'dateKey': dateKey,
    'totalMl': totalMl,
    'goalMl': goalMl,
    'entryCount': entryCount,
  };
}

/// exerciseQuestionAsked — records that a question was asked and which
/// bounded exercise it was about, never the answer text and never
/// anything beyond this one exercise's approved data.
class ExerciseQuestionPayload extends EventPayload {
  const ExerciseQuestionPayload({
    required this.exerciseId,
    required this.questionCode,
    this.freeTextQuestion,
  });

  final String exerciseId;

  /// A short structured code identifying which example question (or
  /// `'freeText'`) was asked — never the full Coach answer.
  final String questionCode;

  /// The user's own typed question, if they used the free-text field
  /// instead of a suggested chip.
  final String? freeTextQuestion;

  factory ExerciseQuestionPayload.fromJson(Map<String, dynamic> j) =>
      ExerciseQuestionPayload(
        exerciseId: j['exerciseId'] as String,
        questionCode: j['questionCode'] as String,
        freeTextQuestion: j['freeTextQuestion'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'questionCode': questionCode,
    if (freeTextQuestion != null) 'freeTextQuestion': freeTextQuestion,
  };
}

/// foodScanConfirmed / mealManuallyConfirmed — the user-confirmed meal
/// only. There is no AI detection connected in this build, so every item
/// here was directly typed or edited by the user before Save — never a
/// model's raw guess.
class MealConfirmedPayload extends EventPayload {
  const MealConfirmedPayload({
    required this.mealId,
    required this.itemLabels,
    this.estimatedCalories,
    this.hadPhoto = false,
    this.note,
  });

  final String mealId;

  /// User-entered/edited food item names.
  final List<String> itemLabels;

  /// User-entered estimate only, always labeled as an estimate in the UI.
  final int? estimatedCalories;
  final bool hadPhoto;
  final String? note;

  factory MealConfirmedPayload.fromJson(Map<String, dynamic> j) =>
      MealConfirmedPayload(
        mealId: j['mealId'] as String,
        itemLabels: (j['itemLabels'] as List).cast<String>(),
        estimatedCalories: j['estimatedCalories'] as int?,
        hadPhoto: j['hadPhoto'] as bool? ?? false,
        note: j['note'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
    'mealId': mealId,
    'itemLabels': itemLabels,
    if (estimatedCalories != null) 'estimatedCalories': estimatedCalories,
    'hadPhoto': hadPhoto,
    if (note != null) 'note': note,
  };
}

/// facialCheckInConfirmed — confirmed structured observations only. Never
/// the image itself, never a diagnostic label, never a generated score.
class FacialCheckInPayload extends EventPayload {
  const FacialCheckInPayload({
    required this.checkInId,
    required this.selfReportedAreas,
    this.hadPhoto = false,
    this.note,
  });

  final String checkInId;

  /// User-selected areas of self-reported focus (e.g. `'hydration'`,
  /// `'redness'`) — plain structured labels, never a diagnosis.
  final List<String> selfReportedAreas;
  final bool hadPhoto;
  final String? note;

  factory FacialCheckInPayload.fromJson(Map<String, dynamic> j) =>
      FacialCheckInPayload(
        checkInId: j['checkInId'] as String,
        selfReportedAreas: (j['selfReportedAreas'] as List).cast<String>(),
        hadPhoto: j['hadPhoto'] as bool? ?? false,
        note: j['note'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
    'checkInId': checkInId,
    'selfReportedAreas': selfReportedAreas,
    'hadPhoto': hadPhoto,
    if (note != null) 'note': note,
  };
}

/// scanDataDeleted — records only that a deletion happened, never the
/// deleted content.
class ScanDataDeletedPayload extends EventPayload {
  const ScanDataDeletedPayload({required this.scanKind, required this.scanId});

  /// `'food'` or `'facial'`.
  final String scanKind;
  final String scanId;

  factory ScanDataDeletedPayload.fromJson(Map<String, dynamic> j) =>
      ScanDataDeletedPayload(
        scanKind: j['scanKind'] as String,
        scanId: j['scanId'] as String,
      );

  @override
  Map<String, dynamic> toJson() => {'scanKind': scanKind, 'scanId': scanId};
}

/// periodLogged — a period boundary only (start or end date). Never a
/// prediction, never medical/contraceptive advice.
class PeriodLoggedPayload extends EventPayload {
  const PeriodLoggedPayload({
    required this.periodId,
    required this.kind,
    required this.dateKey,
  });

  final String periodId;

  /// `'start'` or `'end'`.
  final String kind;

  /// Local calendar date, `yyyy-MM-dd`.
  final String dateKey;

  factory PeriodLoggedPayload.fromJson(Map<String, dynamic> j) =>
      PeriodLoggedPayload(
        periodId: j['periodId'] as String,
        kind: j['kind'] as String,
        dateKey: j['dateKey'] as String,
      );

  @override
  Map<String, dynamic> toJson() => {
    'periodId': periodId,
    'kind': kind,
    'dateKey': dateKey,
  };
}

/// cycleDayLogged — one day's optional self-reported fields. Every field
/// is exactly what the user entered, never inferred.
class CycleDayPayload extends EventPayload {
  const CycleDayPayload({
    required this.dateKey,
    this.flow,
    this.symptoms = const [],
    this.mood,
    this.energyLevel,
    this.sleepQuality,
    this.hasNote = false,
  });

  final String dateKey;
  final String? flow;
  final List<String> symptoms;
  final String? mood;
  final int? energyLevel;
  final int? sleepQuality;

  /// Whether a private note was attached — never the note text itself
  /// (kept device-local only, never placed in a Brain event payload).
  final bool hasNote;

  factory CycleDayPayload.fromJson(Map<String, dynamic> j) => CycleDayPayload(
    dateKey: j['dateKey'] as String,
    flow: j['flow'] as String?,
    symptoms: (j['symptoms'] as List?)?.cast<String>() ?? const [],
    mood: j['mood'] as String?,
    energyLevel: j['energyLevel'] as int?,
    sleepQuality: j['sleepQuality'] as int?,
    hasNote: j['hasNote'] as bool? ?? false,
  );

  @override
  Map<String, dynamic> toJson() => {
    'dateKey': dateKey,
    if (flow != null) 'flow': flow,
    if (symptoms.isNotEmpty) 'symptoms': symptoms,
    if (mood != null) 'mood': mood,
    if (energyLevel != null) 'energyLevel': energyLevel,
    if (sleepQuality != null) 'sleepQuality': sleepQuality,
    'hasNote': hasNote,
  };
}

/// productScanConfirmed — a Glow Shop Scanner product confirmed and saved.
/// Carries only category/data-source metadata, never the full product
/// record (name/brand/nutrition/etc. stay in `ShopRepository` only).
class ProductScanConfirmedPayload extends EventPayload {
  const ProductScanConfirmedPayload({
    required this.productId,
    required this.category,
    required this.dataSource,
    this.hadPhoto = false,
  });

  final String productId;

  /// [ProductCategory.name] — `'food'`, `'supplement'`, `'equipment'`,
  /// `'activewear'`, or `'skincare'`.
  final String category;

  /// [ProductDataSource.name] — `'barcode'`, `'labelPhoto'`, or `'manual'`.
  final String dataSource;
  final bool hadPhoto;

  factory ProductScanConfirmedPayload.fromJson(Map<String, dynamic> j) =>
      ProductScanConfirmedPayload(
        productId: j['productId'] as String,
        category: j['category'] as String,
        dataSource: j['dataSource'] as String,
        hadPhoto: j['hadPhoto'] as bool? ?? false,
      );

  @override
  Map<String, dynamic> toJson() => {
    'productId': productId,
    'category': category,
    'dataSource': dataSource,
    'hadPhoto': hadPhoto,
  };
}

/// productAddedToList — never carries a price (a price is a per-list-item
/// detail entered later/separately, not part of "was this added").
class ProductAddedToListPayload extends EventPayload {
  const ProductAddedToListPayload({
    required this.listItemId,
    required this.listType,
    required this.category,
    required this.quantity,
  });

  final String listItemId;

  /// `'grocery'` or `'fitness'`.
  final String listType;
  final String category;
  final int quantity;

  factory ProductAddedToListPayload.fromJson(Map<String, dynamic> j) =>
      ProductAddedToListPayload(
        listItemId: j['listItemId'] as String,
        listType: j['listType'] as String,
        category: j['category'] as String,
        quantity: j['quantity'] as int,
      );

  @override
  Map<String, dynamic> toJson() => {
    'listItemId': listItemId,
    'listType': listType,
    'category': category,
    'quantity': quantity,
  };
}

/// productPurchased — the amount/currency actually entered by the user for
/// this line item, never a barcode-database or estimated price.
class ProductPurchasedPayload extends EventPayload {
  const ProductPurchasedPayload({
    required this.listItemId,
    required this.listType,
    this.amount,
    this.currencyCode,
  });

  final String listItemId;
  final String listType;
  final double? amount;
  final String? currencyCode;

  factory ProductPurchasedPayload.fromJson(Map<String, dynamic> j) =>
      ProductPurchasedPayload(
        listItemId: j['listItemId'] as String,
        listType: j['listType'] as String,
        amount: (j['amount'] as num?)?.toDouble(),
        currencyCode: j['currencyCode'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
    'listItemId': listItemId,
    'listType': listType,
    if (amount != null) 'amount': amount,
    if (currencyCode != null) 'currencyCode': currencyCode,
  };
}

/// moodCheckedIn — one day's self-reported mood level plus optional
/// structured reasons/energy/stress. Every field is exactly what the user
/// selected, never inferred, never a diagnosis.
class MoodCheckInPayload extends EventPayload {
  const MoodCheckInPayload({
    required this.dateKey,
    required this.level,
    this.reasons = const [],
    this.energyLevel,
    this.stressLevel,
    this.hasNote = false,
  });

  final String dateKey;

  /// [MoodLevel.name] — never a free-text value.
  final String level;
  final List<String> reasons;
  final int? energyLevel;
  final int? stressLevel;

  /// Whether a private note was attached — never the note text itself
  /// (kept device-local only, never placed in a Brain event payload).
  final bool hasNote;

  factory MoodCheckInPayload.fromJson(Map<String, dynamic> j) =>
      MoodCheckInPayload(
        dateKey: j['dateKey'] as String,
        level: j['level'] as String,
        reasons: (j['reasons'] as List?)?.cast<String>() ?? const [],
        energyLevel: j['energyLevel'] as int?,
        stressLevel: j['stressLevel'] as int?,
        hasNote: j['hasNote'] as bool? ?? false,
      );

  @override
  Map<String, dynamic> toJson() => {
    'dateKey': dateKey,
    'level': level,
    if (reasons.isNotEmpty) 'reasons': reasons,
    if (energyLevel != null) 'energyLevel': energyLevel,
    if (stressLevel != null) 'stressLevel': stressLevel,
    'hasNote': hasNote,
  };
}

/// notebookEntryLogged — a Daily Notebook entry the woman explicitly
/// consented to sharing with the Brain for this specific entry. Never
/// carries the note text, only the feeling and whether a note existed.
class NotebookEntryPayload extends EventPayload {
  const NotebookEntryPayload({
    required this.dateKey,
    this.feeling,
    this.hasNote = false,
  });

  final String dateKey;

  /// [Feeling.name] — never a free-text value.
  final String? feeling;

  /// Whether a private note was attached — never the note text itself.
  final bool hasNote;

  factory NotebookEntryPayload.fromJson(Map<String, dynamic> j) =>
      NotebookEntryPayload(
        dateKey: j['dateKey'] as String,
        feeling: j['feeling'] as String?,
        hasNote: j['hasNote'] as bool? ?? false,
      );

  @override
  Map<String, dynamic> toJson() => {
    'dateKey': dateKey,
    if (feeling != null) 'feeling': feeling,
    'hasNote': hasNote,
  };
}

/// walkStarted — records that an intentional in-app walk began. Carries
/// only the session id and, if the user picked a duration-preset routine,
/// which one and its target duration — never a step/distance promise made
/// in advance (see the module's "never promise a specific step count"
/// rule).
class WalkStartedPayload extends EventPayload {
  const WalkStartedPayload({
    required this.walkId,
    this.routineId,
    this.targetDurationSeconds,
  });

  final String walkId;

  /// One of the fixed duration-preset routine ids (e.g. `'walk_10min'`),
  /// or null for an open-ended walk with no chosen target.
  final String? routineId;
  final int? targetDurationSeconds;

  factory WalkStartedPayload.fromJson(Map<String, dynamic> j) =>
      WalkStartedPayload(
        walkId: j['walkId'] as String,
        routineId: j['routineId'] as String?,
        targetDurationSeconds: j['targetDurationSeconds'] as int?,
      );

  @override
  Map<String, dynamic> toJson() => {
    'walkId': walkId,
    if (routineId != null) 'routineId': routineId,
    if (targetDurationSeconds != null)
      'targetDurationSeconds': targetDurationSeconds,
  };
}

/// walkCompleted — the session's own real, measured stats. [steps] and
/// [distanceMeters] are null (never fabricated) when the underlying
/// sensor/GPS wasn't available for that session (e.g. desktop dev with no
/// step sensor) — an honest partial record, never a guessed number.
class WalkCompletedPayload extends EventPayload {
  const WalkCompletedPayload({
    required this.walkId,
    required this.durationSeconds,
    this.steps,
    this.distanceMeters,
    this.averagePaceSecondsPerKm,
    this.routineId,
  });

  final String walkId;
  final int durationSeconds;
  final int? steps;
  final double? distanceMeters;
  final double? averagePaceSecondsPerKm;
  final String? routineId;

  factory WalkCompletedPayload.fromJson(Map<String, dynamic> j) =>
      WalkCompletedPayload(
        walkId: j['walkId'] as String,
        durationSeconds: j['durationSeconds'] as int,
        steps: j['steps'] as int?,
        distanceMeters: (j['distanceMeters'] as num?)?.toDouble(),
        averagePaceSecondsPerKm: (j['averagePaceSecondsPerKm'] as num?)
            ?.toDouble(),
        routineId: j['routineId'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
    'walkId': walkId,
    'durationSeconds': durationSeconds,
    if (steps != null) 'steps': steps,
    if (distanceMeters != null) 'distanceMeters': distanceMeters,
    if (averagePaceSecondsPerKm != null)
      'averagePaceSecondsPerKm': averagePaceSecondsPerKm,
    if (routineId != null) 'routineId': routineId,
  };
}

/// dailyStepsSnapshot — the *current day's aggregate* (same "one snapshot
/// per day, not one per step" discipline as [HydrationAggregatePayload]).
/// [source] records which real step source produced this count (e.g.
/// `'pedometer'`) — never fabricated when unsupported (no event is built
/// at all in that case; see `WalkingController`).
class DailyStepsSnapshotPayload extends EventPayload {
  const DailyStepsSnapshotPayload({
    required this.dateKey,
    required this.steps,
    required this.goal,
    required this.source,
  });

  final String dateKey;
  final int steps;
  final int goal;
  final String source;

  factory DailyStepsSnapshotPayload.fromJson(Map<String, dynamic> j) =>
      DailyStepsSnapshotPayload(
        dateKey: j['dateKey'] as String,
        steps: j['steps'] as int,
        goal: j['goal'] as int,
        source: j['source'] as String,
      );

  @override
  Map<String, dynamic> toJson() => {
    'dateKey': dateKey,
    'steps': steps,
    'goal': goal,
    'source': source,
  };
}

/// stepGoalReached — fired at most once per calendar day (see
/// `WalkingController`'s own dedup-by-dateKey guard).
class StepGoalReachedPayload extends EventPayload {
  const StepGoalReachedPayload({
    required this.dateKey,
    required this.steps,
    required this.goal,
  });

  final String dateKey;
  final int steps;
  final int goal;

  factory StepGoalReachedPayload.fromJson(Map<String, dynamic> j) =>
      StepGoalReachedPayload(
        dateKey: j['dateKey'] as String,
        steps: j['steps'] as int,
        goal: j['goal'] as int,
      );

  @override
  Map<String, dynamic> toJson() => {
    'dateKey': dateKey,
    'steps': steps,
    'goal': goal,
  };
}

/// planModified.
class PlanModifiedPayload extends EventPayload {
  const PlanModifiedPayload({required this.descriptionCode, this.workoutId});

  /// A short structured code, e.g. `'exercise_swapped'` — not free text.
  final String descriptionCode;
  final String? workoutId;

  factory PlanModifiedPayload.fromJson(Map<String, dynamic> j) =>
      PlanModifiedPayload(
        descriptionCode: j['descriptionCode'] as String,
        workoutId: j['workoutId'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
    'descriptionCode': descriptionCode,
    if (workoutId != null) 'workoutId': workoutId,
  };
}

EventPayload _payloadFromJson(LearningEventType type, Map<String, dynamic> j) {
  switch (type) {
    case LearningEventType.exerciseStarted:
    case LearningEventType.exerciseCompleted:
    case LearningEventType.exerciseSkipped:
    case LearningEventType.exerciseStoppedEarly:
    case LearningEventType.exerciseRepeated:
    case LearningEventType.exerciseReplaced:
      return ExerciseLifecyclePayload.fromJson(j);
    case LearningEventType.exerciseFeedbackSubmitted:
    case LearningEventType.sessionFeedbackSubmitted:
      return FeedbackPayload.fromJson(j);
    case LearningEventType.painReported:
      return PainReportPayload.fromJson(j);
    case LearningEventType.workoutCompleted:
      return WorkoutCompletedPayload.fromJson(j);
    case LearningEventType.recommendationShown:
    case LearningEventType.recommendationAccepted:
    case LearningEventType.recommendationDismissed:
    case LearningEventType.recommendationModified:
    case LearningEventType.recommendationCompleted:
      return RecommendationOutcomePayload.fromJson(j);
    case LearningEventType.planModified:
      return PlanModifiedPayload.fromJson(j);
    case LearningEventType.hydrationLogged:
      return HydrationAggregatePayload.fromJson(j);
    case LearningEventType.exerciseQuestionAsked:
      return ExerciseQuestionPayload.fromJson(j);
    case LearningEventType.foodScanConfirmed:
    case LearningEventType.mealManuallyConfirmed:
      return MealConfirmedPayload.fromJson(j);
    case LearningEventType.facialCheckInConfirmed:
      return FacialCheckInPayload.fromJson(j);
    case LearningEventType.scanDataDeleted:
      return ScanDataDeletedPayload.fromJson(j);
    case LearningEventType.periodLogged:
      return PeriodLoggedPayload.fromJson(j);
    case LearningEventType.cycleDayLogged:
      return CycleDayPayload.fromJson(j);
    case LearningEventType.productScanConfirmed:
      return ProductScanConfirmedPayload.fromJson(j);
    case LearningEventType.productAddedToList:
      return ProductAddedToListPayload.fromJson(j);
    case LearningEventType.productPurchased:
      return ProductPurchasedPayload.fromJson(j);
    case LearningEventType.moodCheckedIn:
      return MoodCheckInPayload.fromJson(j);
    case LearningEventType.notebookEntryLogged:
      return NotebookEntryPayload.fromJson(j);
    case LearningEventType.walkStarted:
      return WalkStartedPayload.fromJson(j);
    case LearningEventType.walkCompleted:
      return WalkCompletedPayload.fromJson(j);
    case LearningEventType.dailyStepsSnapshot:
      return DailyStepsSnapshotPayload.fromJson(j);
    case LearningEventType.stepGoalReached:
      return StepGoalReachedPayload.fromJson(j);
  }
}

/// The canonical learning-event record. Append-only by convention (nothing
/// in this codebase exposes an update-in-place path — see
/// [LearningEventRepository]); a correction is made by writing a new event
/// with [supersedesEventId] pointing at the one it corrects, never by
/// mutating history.
///
/// `id` doubles as the idempotency key: since this app has no server to
/// assign a separate canonical id, the client-generated id *is* the
/// canonical id, and [LearningEventRepository.add] dedups on it exactly the
/// way `WorkoutHistoryRepository`/`WaterRepository` already do.
class LearningEvent {
  const LearningEvent({
    required this.id,
    required this.userId,
    required this.type,
    required this.module,
    required this.entityType,
    required this.entityId,
    this.sessionId,
    required this.occurredAt,
    required this.source,
    required this.payload,
    this.intensity,
    this.safetySeverity,
    this.schemaVersion = 1,
    this.consentScope = ConsentScope.deviceLocal,
    required this.createdAt,
    this.supersedesEventId,
  });

  final String id;
  final String userId;
  final LearningEventType type;
  final EventModule module;
  final String entityType;
  final String entityId;
  final String? sessionId;
  final DateTime occurredAt;
  final EventSource source;
  final EventPayload payload;
  final double? intensity;

  /// Only ever set on a `painReported` event today; reuses [PainDetails]'s
  /// severity type rather than a duplicate.
  final PainSeverity? safetySeverity;
  final int schemaVersion;
  final ConsentScope consentScope;
  final DateTime createdAt;

  /// Non-null only on a correction event.
  final String? supersedesEventId;

  EventTypeSchema get schema => kEventTypeSchemas[type]!;

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'type': type.name,
    'module': module.name,
    'entityType': entityType,
    'entityId': entityId,
    if (sessionId != null) 'sessionId': sessionId,
    'occurredAt': occurredAt.toIso8601String(),
    'source': source.name,
    'payload': payload.toJson(),
    if (intensity != null) 'intensity': intensity,
    if (safetySeverity != null) 'safetySeverity': safetySeverity!.name,
    'schemaVersion': schemaVersion,
    'consentScope': consentScope.name,
    'createdAt': createdAt.toIso8601String(),
    if (supersedesEventId != null) 'supersedesEventId': supersedesEventId,
  };

  factory LearningEvent.fromJson(Map<String, dynamic> j) {
    final type = LearningEventType.values.byName(j['type'] as String);
    return LearningEvent(
      id: j['id'] as String,
      userId: j['userId'] as String,
      type: type,
      module: EventModule.values.byName(j['module'] as String),
      entityType: j['entityType'] as String,
      entityId: j['entityId'] as String,
      sessionId: j['sessionId'] as String?,
      occurredAt: DateTime.parse(j['occurredAt'] as String),
      source: EventSource.values.byName(j['source'] as String),
      payload: _payloadFromJson(type, j['payload'] as Map<String, dynamic>),
      intensity: (j['intensity'] as num?)?.toDouble(),
      safetySeverity: j['safetySeverity'] == null
          ? null
          : PainSeverity.values.byName(j['safetySeverity'] as String),
      schemaVersion: j['schemaVersion'] as int? ?? 1,
      consentScope: ConsentScope.values.byName(
        j['consentScope'] as String? ?? ConsentScope.deviceLocal.name,
      ),
      createdAt: DateTime.parse(j['createdAt'] as String),
      supersedesEventId: j['supersedesEventId'] as String?,
    );
  }

  /// Bytes the payload alone would take on the wire — what
  /// [EventTypeSchema.maxPayloadBytes] is measured against.
  int get payloadByteLength => utf8.encode(jsonEncode(payload.toJson())).length;

  // Ergonomic, validated constructors — each one pairs the correct
  // [LearningEventType] with the correct payload shape, so a call site can
  // never construct a mismatched pair the way a bare `LearningEvent(...)`
  // call could.

  static LearningEvent exerciseLifecycle({
    required String id,
    required String userId,
    required LearningEventType type,
    required String exerciseId,
    String? workoutId,
    String? replacementExerciseId,
    String? reasonCode,
    String? sessionId,
    EventSource source = EventSource.behavioral,
    required DateTime occurredAt,
    String? exerciseName,
    String? category,
    // Additive, defaults to the base class's own deviceLocal default —
    // every existing call site is unaffected. Only the exerciseCompleted
    // call site opts this in today — see
    // RoutinePlayerController._finishActiveExercise.
    ConsentScope consentScope = ConsentScope.deviceLocal,
  }) {
    assert(
      const {
        LearningEventType.exerciseStarted,
        LearningEventType.exerciseCompleted,
        LearningEventType.exerciseSkipped,
        LearningEventType.exerciseStoppedEarly,
        LearningEventType.exerciseRepeated,
        LearningEventType.exerciseReplaced,
      }.contains(type),
    );
    return LearningEvent(
      id: id,
      userId: userId,
      type: type,
      module: EventModule.workout,
      entityType: 'exercise',
      entityId: exerciseId,
      sessionId: sessionId,
      occurredAt: occurredAt,
      source: source,
      payload: ExerciseLifecyclePayload(
        exerciseId: exerciseId,
        workoutId: workoutId,
        replacementExerciseId: replacementExerciseId,
        reasonCode: reasonCode,
        exerciseName: exerciseName,
        category: category,
      ),
      consentScope: consentScope,
      createdAt: DateTime.now(),
    );
  }

  static LearningEvent exerciseFeedback({
    required String id,
    required String userId,
    required String exerciseId,
    required WorkoutFeeling feeling,
    String? note,
    List<String> chips = const [],
    String? sessionId,
    required DateTime occurredAt,
  }) {
    return LearningEvent(
      id: id,
      userId: userId,
      type: LearningEventType.exerciseFeedbackSubmitted,
      module: EventModule.workout,
      entityType: 'exercise',
      entityId: exerciseId,
      sessionId: sessionId,
      occurredAt: occurredAt,
      source: EventSource.explicit,
      payload: FeedbackPayload(
        feeling: feeling,
        exerciseId: exerciseId,
        note: note,
        chips: chips,
      ),
      createdAt: DateTime.now(),
    );
  }

  static LearningEvent sessionFeedback({
    required String id,
    required String userId,
    required String workoutId,
    required WorkoutFeeling feeling,
    String? note,
    String? sessionId,
    required DateTime occurredAt,
  }) {
    return LearningEvent(
      id: id,
      userId: userId,
      type: LearningEventType.sessionFeedbackSubmitted,
      module: EventModule.workout,
      entityType: 'workout',
      entityId: workoutId,
      sessionId: sessionId,
      occurredAt: occurredAt,
      source: EventSource.explicit,
      payload: FeedbackPayload(feeling: feeling, note: note),
      createdAt: DateTime.now(),
    );
  }

  static LearningEvent painReport({
    required String id,
    required String userId,
    required PainDetails details,
    String? exerciseId,
    bool wantsToStop = false,
    bool wantsToReplace = false,
    String? sessionId,
    required DateTime occurredAt,
  }) {
    return LearningEvent(
      id: id,
      userId: userId,
      type: LearningEventType.painReported,
      module: EventModule.workout,
      entityType: exerciseId != null ? 'exercise' : 'session',
      entityId: exerciseId ?? sessionId ?? 'unknown',
      sessionId: sessionId,
      occurredAt: occurredAt,
      source: EventSource.explicit,
      payload: PainReportPayload(
        details: details,
        exerciseId: exerciseId,
        wantsToStop: wantsToStop,
        wantsToReplace: wantsToReplace,
      ),
      safetySeverity: details.severity,
      createdAt: DateTime.now(),
    );
  }

  static LearningEvent workoutCompleted({
    required String id,
    required String userId,
    required String workoutId,
    required int totalDurationSeconds,
    required List<String> completedExerciseIds,
    required List<String> skippedExerciseIds,
    String? sessionId,
    required DateTime occurredAt,
    String? workoutName,
    String? category,
    // Additive, defaults to the base class's own deviceLocal default —
    // every existing call site is unaffected. This payload
    // (WorkoutCompletedPayload) is entirely structured ids/counts/duration/
    // names, never free text, so it's one of the types this build
    // explicitly opts into aiExpressionEligible — see
    // `WorkoutHistoryController._syncBrainEvent`.
    ConsentScope consentScope = ConsentScope.deviceLocal,
  }) {
    return LearningEvent(
      id: id,
      userId: userId,
      type: LearningEventType.workoutCompleted,
      module: EventModule.workout,
      entityType: 'workout',
      entityId: workoutId,
      sessionId: sessionId,
      occurredAt: occurredAt,
      source: EventSource.behavioral,
      payload: WorkoutCompletedPayload(
        workoutId: workoutId,
        totalDurationSeconds: totalDurationSeconds,
        completedExerciseIds: completedExerciseIds,
        skippedExerciseIds: skippedExerciseIds,
        workoutName: workoutName,
        category: category,
      ),
      consentScope: consentScope,
      createdAt: DateTime.now(),
    );
  }

  static LearningEvent recommendationOutcome({
    required String id,
    required String userId,
    required LearningEventType type,
    required String recommendationId,
    String? note,
    required DateTime occurredAt,
  }) {
    assert(
      const {
        LearningEventType.recommendationShown,
        LearningEventType.recommendationAccepted,
        LearningEventType.recommendationDismissed,
        LearningEventType.recommendationModified,
        LearningEventType.recommendationCompleted,
      }.contains(type),
    );
    return LearningEvent(
      id: id,
      userId: userId,
      type: type,
      module: EventModule.workout,
      entityType: 'recommendation',
      entityId: recommendationId,
      occurredAt: occurredAt,
      source: EventSource.behavioral,
      payload: RecommendationOutcomePayload(
        recommendationId: recommendationId,
        note: note,
      ),
      createdAt: DateTime.now(),
    );
  }

  static LearningEvent hydrationLogged({
    required String id,
    required String userId,
    required String dateKey,
    required double totalMl,
    required double goalMl,
    required int entryCount,
    required DateTime occurredAt,
  }) {
    return LearningEvent(
      id: id,
      userId: userId,
      type: LearningEventType.hydrationLogged,
      module: EventModule.water,
      entityType: 'day',
      entityId: dateKey,
      occurredAt: occurredAt,
      source: EventSource.behavioral,
      payload: HydrationAggregatePayload(
        dateKey: dateKey,
        totalMl: totalMl,
        goalMl: goalMl,
        entryCount: entryCount,
      ),
      createdAt: DateTime.now(),
    );
  }

  static LearningEvent exerciseQuestionAsked({
    required String id,
    required String userId,
    required String exerciseId,
    required String questionCode,
    String? freeTextQuestion,
    String? sessionId,
    required DateTime occurredAt,
  }) {
    return LearningEvent(
      id: id,
      userId: userId,
      type: LearningEventType.exerciseQuestionAsked,
      module: EventModule.workout,
      entityType: 'exercise',
      entityId: exerciseId,
      sessionId: sessionId,
      occurredAt: occurredAt,
      source: EventSource.explicit,
      payload: ExerciseQuestionPayload(
        exerciseId: exerciseId,
        questionCode: questionCode,
        freeTextQuestion: freeTextQuestion,
      ),
      createdAt: DateTime.now(),
    );
  }

  /// Builds either a [LearningEventType.foodScanConfirmed] or
  /// [LearningEventType.mealManuallyConfirmed] event depending on
  /// [hadPhoto] — the two types share this one factory since they share
  /// every field except provenance.
  static LearningEvent mealConfirmed({
    required String id,
    required String userId,
    required String mealId,
    required List<String> itemLabels,
    int? estimatedCalories,
    bool hadPhoto = false,
    String? note,
    required DateTime occurredAt,
  }) {
    return LearningEvent(
      id: id,
      userId: userId,
      type: hadPhoto
          ? LearningEventType.foodScanConfirmed
          : LearningEventType.mealManuallyConfirmed,
      module: EventModule.foodScan,
      entityType: 'meal',
      entityId: mealId,
      occurredAt: occurredAt,
      source: EventSource.explicit,
      payload: MealConfirmedPayload(
        mealId: mealId,
        itemLabels: itemLabels,
        estimatedCalories: estimatedCalories,
        hadPhoto: hadPhoto,
        note: note,
      ),
      createdAt: DateTime.now(),
    );
  }

  static LearningEvent facialCheckInConfirmed({
    required String id,
    required String userId,
    required String checkInId,
    required List<String> selfReportedAreas,
    bool hadPhoto = false,
    String? note,
    required DateTime occurredAt,
  }) {
    return LearningEvent(
      id: id,
      userId: userId,
      type: LearningEventType.facialCheckInConfirmed,
      module: EventModule.facialScan,
      entityType: 'checkIn',
      entityId: checkInId,
      occurredAt: occurredAt,
      source: EventSource.explicit,
      payload: FacialCheckInPayload(
        checkInId: checkInId,
        selfReportedAreas: selfReportedAreas,
        hadPhoto: hadPhoto,
        note: note,
      ),
      createdAt: DateTime.now(),
    );
  }

  /// [scanKind] is `'food'`, `'facial'`, or `'product'`.
  static LearningEvent scanDataDeleted({
    required String id,
    required String userId,
    required String scanKind,
    required String scanId,
    required DateTime occurredAt,
  }) {
    return LearningEvent(
      id: id,
      userId: userId,
      type: LearningEventType.scanDataDeleted,
      module: scanKind == 'food'
          ? EventModule.foodScan
          : scanKind == 'product'
          ? EventModule.shop
          : EventModule.facialScan,
      entityType: 'scan',
      entityId: scanId,
      occurredAt: occurredAt,
      source: EventSource.explicit,
      payload: ScanDataDeletedPayload(scanKind: scanKind, scanId: scanId),
      createdAt: DateTime.now(),
    );
  }

  /// [kind] is `'start'` or `'end'`.
  static LearningEvent periodLogged({
    required String id,
    required String userId,
    required String periodId,
    required String kind,
    required String dateKey,
    required DateTime occurredAt,
  }) {
    return LearningEvent(
      id: id,
      userId: userId,
      type: LearningEventType.periodLogged,
      module: EventModule.cycle,
      entityType: 'period',
      entityId: periodId,
      occurredAt: occurredAt,
      source: EventSource.explicit,
      payload: PeriodLoggedPayload(
        periodId: periodId,
        kind: kind,
        dateKey: dateKey,
      ),
      createdAt: DateTime.now(),
    );
  }

  static LearningEvent cycleDayLogged({
    required String id,
    required String userId,
    required String dateKey,
    String? flow,
    List<String> symptoms = const [],
    String? mood,
    int? energyLevel,
    int? sleepQuality,
    bool hasNote = false,
    required DateTime occurredAt,
  }) {
    return LearningEvent(
      id: id,
      userId: userId,
      type: LearningEventType.cycleDayLogged,
      module: EventModule.cycle,
      entityType: 'day',
      entityId: dateKey,
      occurredAt: occurredAt,
      source: EventSource.explicit,
      payload: CycleDayPayload(
        dateKey: dateKey,
        flow: flow,
        symptoms: symptoms,
        mood: mood,
        energyLevel: energyLevel,
        sleepQuality: sleepQuality,
        hasNote: hasNote,
      ),
      createdAt: DateTime.now(),
    );
  }

  static LearningEvent productScanConfirmed({
    required String id,
    required String userId,
    required String productId,
    required String category,
    required String dataSource,
    bool hadPhoto = false,
    required DateTime occurredAt,
  }) {
    return LearningEvent(
      id: id,
      userId: userId,
      type: LearningEventType.productScanConfirmed,
      module: EventModule.shop,
      entityType: 'product',
      entityId: productId,
      occurredAt: occurredAt,
      source: EventSource.explicit,
      payload: ProductScanConfirmedPayload(
        productId: productId,
        category: category,
        dataSource: dataSource,
        hadPhoto: hadPhoto,
      ),
      createdAt: DateTime.now(),
    );
  }

  static LearningEvent productAddedToList({
    required String id,
    required String userId,
    required String listItemId,
    required String listType,
    required String category,
    required int quantity,
    required DateTime occurredAt,
  }) {
    return LearningEvent(
      id: id,
      userId: userId,
      type: LearningEventType.productAddedToList,
      module: EventModule.shop,
      entityType: 'listItem',
      entityId: listItemId,
      occurredAt: occurredAt,
      source: EventSource.explicit,
      payload: ProductAddedToListPayload(
        listItemId: listItemId,
        listType: listType,
        category: category,
        quantity: quantity,
      ),
      createdAt: DateTime.now(),
    );
  }

  static LearningEvent productPurchased({
    required String id,
    required String userId,
    required String listItemId,
    required String listType,
    double? amount,
    String? currencyCode,
    required DateTime occurredAt,
  }) {
    return LearningEvent(
      id: id,
      userId: userId,
      type: LearningEventType.productPurchased,
      module: EventModule.shop,
      entityType: 'listItem',
      entityId: listItemId,
      occurredAt: occurredAt,
      source: EventSource.explicit,
      payload: ProductPurchasedPayload(
        listItemId: listItemId,
        listType: listType,
        amount: amount,
        currencyCode: currencyCode,
      ),
      createdAt: DateTime.now(),
    );
  }

  static LearningEvent moodCheckedIn({
    required String id,
    required String userId,
    required String dateKey,
    required String level,
    List<String> reasons = const [],
    int? energyLevel,
    int? stressLevel,
    bool hasNote = false,
    required DateTime occurredAt,
  }) {
    return LearningEvent(
      id: id,
      userId: userId,
      type: LearningEventType.moodCheckedIn,
      module: EventModule.mood,
      entityType: 'day',
      entityId: dateKey,
      occurredAt: occurredAt,
      source: EventSource.explicit,
      payload: MoodCheckInPayload(
        dateKey: dateKey,
        level: level,
        reasons: reasons,
        energyLevel: energyLevel,
        stressLevel: stressLevel,
        hasNote: hasNote,
      ),
      createdAt: DateTime.now(),
    );
  }

  static LearningEvent notebookEntryLogged({
    required String id,
    required String userId,
    required String dateKey,
    String? feeling,
    bool hasNote = false,
    required DateTime occurredAt,
  }) {
    return LearningEvent(
      id: id,
      userId: userId,
      type: LearningEventType.notebookEntryLogged,
      module: EventModule.cycle,
      entityType: 'day',
      entityId: dateKey,
      occurredAt: occurredAt,
      source: EventSource.explicit,
      payload: NotebookEntryPayload(
        dateKey: dateKey,
        feeling: feeling,
        hasNote: hasNote,
      ),
      createdAt: DateTime.now(),
    );
  }

  static LearningEvent walkStarted({
    required String id,
    required String userId,
    required String walkId,
    String? routineId,
    int? targetDurationSeconds,
    required DateTime occurredAt,
  }) {
    return LearningEvent(
      id: id,
      userId: userId,
      type: LearningEventType.walkStarted,
      module: EventModule.walking,
      entityType: 'walk',
      entityId: walkId,
      occurredAt: occurredAt,
      source: EventSource.explicit,
      payload: WalkStartedPayload(
        walkId: walkId,
        routineId: routineId,
        targetDurationSeconds: targetDurationSeconds,
      ),
      createdAt: DateTime.now(),
    );
  }

  static LearningEvent walkCompleted({
    required String id,
    required String userId,
    required String walkId,
    required int durationSeconds,
    int? steps,
    double? distanceMeters,
    double? averagePaceSecondsPerKm,
    String? routineId,
    required DateTime occurredAt,
    // Additive, defaults to deviceLocal — the Coach only learns about a
    // completed walk once this is explicitly opted in, same pattern as
    // WorkoutHistoryController.workoutCompleted.
    ConsentScope consentScope = ConsentScope.deviceLocal,
  }) {
    return LearningEvent(
      id: id,
      userId: userId,
      type: LearningEventType.walkCompleted,
      module: EventModule.walking,
      entityType: 'walk',
      entityId: walkId,
      occurredAt: occurredAt,
      source: EventSource.behavioral,
      payload: WalkCompletedPayload(
        walkId: walkId,
        durationSeconds: durationSeconds,
        steps: steps,
        distanceMeters: distanceMeters,
        averagePaceSecondsPerKm: averagePaceSecondsPerKm,
        routineId: routineId,
      ),
      consentScope: consentScope,
      createdAt: DateTime.now(),
    );
  }

  static LearningEvent dailyStepsSnapshot({
    required String id,
    required String userId,
    required String dateKey,
    required int steps,
    required int goal,
    required String source,
    required DateTime occurredAt,
    ConsentScope consentScope = ConsentScope.deviceLocal,
  }) {
    return LearningEvent(
      id: id,
      userId: userId,
      type: LearningEventType.dailyStepsSnapshot,
      module: EventModule.walking,
      entityType: 'day',
      entityId: dateKey,
      occurredAt: occurredAt,
      source: EventSource.behavioral,
      payload: DailyStepsSnapshotPayload(
        dateKey: dateKey,
        steps: steps,
        goal: goal,
        source: source,
      ),
      consentScope: consentScope,
      createdAt: DateTime.now(),
    );
  }

  static LearningEvent stepGoalReached({
    required String id,
    required String userId,
    required String dateKey,
    required int steps,
    required int goal,
    required DateTime occurredAt,
    ConsentScope consentScope = ConsentScope.deviceLocal,
  }) {
    return LearningEvent(
      id: id,
      userId: userId,
      type: LearningEventType.stepGoalReached,
      module: EventModule.walking,
      entityType: 'day',
      entityId: dateKey,
      occurredAt: occurredAt,
      source: EventSource.behavioral,
      payload: StepGoalReachedPayload(dateKey: dateKey, steps: steps, goal: goal),
      consentScope: consentScope,
      createdAt: DateTime.now(),
    );
  }
}
