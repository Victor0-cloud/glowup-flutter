/// Explicit, configurable bounds every Tier 2 decision must load within —
/// the amendment's stated initial defaults. Nothing in `AdaptationEngine`
/// may load more than this, regardless of how much history a user has
/// accumulated.
class ContextBounds {
  const ContextBounds({
    this.maxEventsPerDecision = 200,
    this.maxLookbackDays = 30,
    this.maxActivePatterns = 20,
  });

  final int maxEventsPerDecision;
  final int maxLookbackDays;
  final int maxActivePatterns;
}

const kDefaultContextBounds = ContextBounds();
