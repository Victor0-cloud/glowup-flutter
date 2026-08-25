import 'learned_pattern.dart';

/// How many supporting observations a candidate needs before Tier 4 may
/// promote it to active — configurable, not hardcoded per call site.
/// "One event must not become a permanent learned pattern," so this must
/// be >= 2.
const kPatternPromotionThreshold = 2;

/// The minimum confidence Tier 4 also requires alongside the observation
/// threshold before promoting.
const kPatternConfidenceFloor = 0.6;

/// How long a still-candidate pattern is kept around before it's expired
/// for lack of further evidence.
const kPatternCandidateTtl = Duration(days: 60);

/// Pure, deterministic — Tier 1 calls this on every relevant event to
/// record evidence; it never promotes a pattern by itself (see
/// `kPatternPromotionThreshold`'s doc and `PatternPromotionJob`, which is
/// Tier 4 only). No AI provider is reachable from this file.
class PatternDetector {
  const PatternDetector();

  /// Increments evidence for (patternType, subjectId) — creates a new
  /// [PatternStatus.candidate] if none exists yet, otherwise appends
  /// evidence to the existing candidate/active pattern and recalculates
  /// confidence. Always returns a pattern whose status is unchanged by
  /// this call alone (promotion is Tier 4's job, not this one's).
  LearnedPattern recordEvidence({
    required LearnedPattern? existing,
    required String userId,
    required String patternType,
    required String subjectId,
    required String summary,
    required String eventId,
    required bool supports,
    required DateTime now,
    required String Function() newId,
  }) {
    if (existing == null) {
      final pattern = LearnedPattern(
        id: newId(),
        userId: userId,
        patternType: patternType,
        subjectId: subjectId,
        summary: summary,
        supportingEventIds: supports ? [eventId] : [],
        contradictingEventIds: supports ? [] : [eventId],
        confidence: supports ? 1.0 : 0.0,
        observationCount: 1,
        firstObservedAt: now,
        lastObservedAt: now,
        status: PatternStatus.candidate,
        reviewAt: now.add(kPatternCandidateTtl),
      );
      return pattern;
    }

    final supporting = supports
        ? [...existing.supportingEventIds, eventId]
        : existing.supportingEventIds;
    final contradicting = supports
        ? existing.contradictingEventIds
        : [...existing.contradictingEventIds, eventId];
    return existing.copyWith(
      supportingEventIds: supporting,
      contradictingEventIds: contradicting,
      confidence: recalculateConfidence(
        supporting.length,
        contradicting.length,
      ),
      observationCount: existing.observationCount + 1,
      lastObservedAt: now,
      summary: summary,
    );
  }

  /// Simple, explainable, deterministic: confidence is the supporting
  /// share of all evidence — contradicting evidence pulls it down
  /// immediately rather than needing a separate decay pass.
  double recalculateConfidence(int supportingCount, int contradictingCount) {
    final total = supportingCount + contradictingCount;
    if (total == 0) return 0;
    return supportingCount / total;
  }

  /// Tier 4 only — decides whether a still-candidate pattern has earned
  /// promotion to active.
  bool shouldPromote(LearnedPattern pattern) {
    return pattern.status == PatternStatus.candidate &&
        pattern.observationCount >= kPatternPromotionThreshold &&
        pattern.confidence >= kPatternConfidenceFloor;
  }

  /// Tier 4 only — a stale candidate with no promotion and no recent
  /// evidence expires rather than lingering forever.
  bool shouldExpire(LearnedPattern pattern, DateTime now) {
    return pattern.status == PatternStatus.candidate &&
        now.isAfter(pattern.reviewAt);
  }
}
