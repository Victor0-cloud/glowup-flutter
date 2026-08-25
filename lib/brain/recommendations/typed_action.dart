/// The full typed-action vocabulary the Brain may ever produce. Only a
/// subset is actually selectable by `AdaptationEngine`'s rules in this
/// first slice (`keepPlanUnchanged`, `reduceDifficulty`,
/// `triggerSafetyPause`) — the rest exist so the registry doesn't need to
/// change shape when later modules/rules start selecting them. Generative
/// text (Tier 3) may only describe whichever of these Tier 2 already
/// selected; it can never invent or override one.
enum TypedActionType {
  keepPlanUnchanged,
  recommendRoutine,
  replaceExercise,
  shortenSession,
  extendSession,
  reduceDifficulty,
  increaseDifficulty,
  reduceReps,
  increaseReps,
  reduceIntensity,
  addWarmUp,
  addMobility,
  addRecovery,
  addBreathing,
  addHydrationGuidance,
  rescheduleActivity,
  askFollowUpQuestion,
  triggerSafetyPause,
  recommendProfessionalSupport,
}

/// What safety gate (if any) drove the decision — stored alongside the
/// typed action so a "Why this?" explanation and any audit can see exactly
/// why, without re-deriving it from raw events.
enum SafetyDecision { none, advisory, pause }
