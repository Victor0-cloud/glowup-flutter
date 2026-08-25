import '../events/learning_event.dart' show EventModule;
import 'typed_action.dart';

enum RecommendationOutcomeStatus {
  shown,
  accepted,
  dismissed,
  modified,
  completed,
  abandoned,
  helpful,
  notHelpful,
}

/// A stored Tier 2 decision — the only thing Tier 3 is ever allowed to
/// turn into natural language, and the only thing a "Why this?" surface
/// ever reads from. Every field here is either a fact Tier 2 computed
/// deterministically or a trace back to the evidence that justified it —
/// never hidden chain-of-thought.
class CoachRecommendation {
  const CoachRecommendation({
    required this.id,
    required this.userId,
    required this.action,
    required this.targetModule,
    required this.targetEntityId,
    required this.reasonCodes,
    required this.evidenceEventIds,
    required this.safetyDecision,
    required this.confidence,
    required this.ruleVersion,
    this.modelVersion,
    required this.createdAt,
    required this.expiresAt,
    this.explanation,
    this.outcomeStatus,
    this.outcomeUpdatedAt,
  });

  final String id;
  final String userId;
  final TypedActionType action;
  final EventModule targetModule;
  final String targetEntityId;

  /// Short structured codes (e.g. `'safety_flag_severe_pain'`,
  /// `'pattern_too_hard_repeated'`) — never free text.
  final List<String> reasonCodes;
  final List<String> evidenceEventIds;
  final SafetyDecision safetyDecision;

  /// 0.0-1.0. 1.0 for a hard deterministic safety rule; a pattern's
  /// [LearnedPattern.confidence] when the decision was pattern-driven.
  final double confidence;

  /// Version of the deterministic rule set that produced this decision —
  /// bump whenever `AdaptationEngine`'s rules change, so old stored
  /// decisions stay auditable against the rules that actually produced
  /// them.
  final int ruleVersion;

  /// Set only if a Tier 3 model call (not a template) ever produces
  /// [explanation] — always null while Tier 3 runs in template-only mode.
  final String? modelVersion;
  final DateTime createdAt;
  final DateTime expiresAt;

  /// Filled in by Tier 3 — a grounded 1-2 sentence explanation, or null
  /// until requested.
  final String? explanation;
  final RecommendationOutcomeStatus? outcomeStatus;
  final DateTime? outcomeUpdatedAt;

  CoachRecommendation copyWith({
    String? explanation,
    RecommendationOutcomeStatus? outcomeStatus,
    DateTime? outcomeUpdatedAt,
  }) {
    return CoachRecommendation(
      id: id,
      userId: userId,
      action: action,
      targetModule: targetModule,
      targetEntityId: targetEntityId,
      reasonCodes: reasonCodes,
      evidenceEventIds: evidenceEventIds,
      safetyDecision: safetyDecision,
      confidence: confidence,
      ruleVersion: ruleVersion,
      modelVersion: modelVersion,
      createdAt: createdAt,
      expiresAt: expiresAt,
      explanation: explanation ?? this.explanation,
      outcomeStatus: outcomeStatus ?? this.outcomeStatus,
      outcomeUpdatedAt: outcomeUpdatedAt ?? this.outcomeUpdatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'action': action.name,
    'targetModule': targetModule.name,
    'targetEntityId': targetEntityId,
    'reasonCodes': reasonCodes,
    'evidenceEventIds': evidenceEventIds,
    'safetyDecision': safetyDecision.name,
    'confidence': confidence,
    'ruleVersion': ruleVersion,
    if (modelVersion != null) 'modelVersion': modelVersion,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    if (explanation != null) 'explanation': explanation,
    if (outcomeStatus != null) 'outcomeStatus': outcomeStatus!.name,
    if (outcomeUpdatedAt != null)
      'outcomeUpdatedAt': outcomeUpdatedAt!.toIso8601String(),
  };

  factory CoachRecommendation.fromJson(Map<String, dynamic> j) =>
      CoachRecommendation(
        id: j['id'] as String,
        userId: j['userId'] as String,
        action: TypedActionType.values.byName(j['action'] as String),
        targetModule: EventModule.values.byName(j['targetModule'] as String),
        targetEntityId: j['targetEntityId'] as String,
        reasonCodes: (j['reasonCodes'] as List).cast<String>(),
        evidenceEventIds: (j['evidenceEventIds'] as List).cast<String>(),
        safetyDecision: SafetyDecision.values.byName(
          j['safetyDecision'] as String,
        ),
        confidence: (j['confidence'] as num).toDouble(),
        ruleVersion: j['ruleVersion'] as int,
        modelVersion: j['modelVersion'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        expiresAt: DateTime.parse(j['expiresAt'] as String),
        explanation: j['explanation'] as String?,
        outcomeStatus: j['outcomeStatus'] == null
            ? null
            : RecommendationOutcomeStatus.values.byName(
                j['outcomeStatus'] as String,
              ),
        outcomeUpdatedAt: j['outcomeUpdatedAt'] == null
            ? null
            : DateTime.parse(j['outcomeUpdatedAt'] as String),
      );
}
