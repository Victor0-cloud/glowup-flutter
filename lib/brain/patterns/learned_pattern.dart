enum PatternStatus { candidate, active, dismissed, expired }

/// A recurring, evidence-backed relationship the deterministic detector has
/// noticed — e.g. "this exercise repeatedly gets rated Too Hard." Never
/// created directly from a single event: [PatternStatus.candidate] is the
/// only status a brand-new pattern can start in, and only Tier 4's
/// promotion job (never Tier 1) may move it to [PatternStatus.active].
class LearnedPattern {
  const LearnedPattern({
    required this.id,
    required this.userId,
    required this.patternType,
    required this.subjectId,
    required this.summary,
    required this.supportingEventIds,
    required this.contradictingEventIds,
    required this.confidence,
    required this.observationCount,
    required this.firstObservedAt,
    required this.lastObservedAt,
    required this.status,
    required this.reviewAt,
  });

  final String id;
  final String userId;

  /// e.g. `'tooHardRepeated'`, `'painRepeated'`, `'consistentlySkipped'`.
  final String patternType;

  /// What the pattern is about — an exercise id in this slice.
  final String subjectId;

  /// Deterministically generated from [patternType]/[subjectId]/evidence —
  /// never free text from a generative model (see `PatternDetector`).
  final String summary;

  final List<String> supportingEventIds;
  final List<String> contradictingEventIds;

  /// 0.0-1.0, recalculated deterministically on every new piece of
  /// evidence — see `PatternDetector.recalculateConfidence`.
  final double confidence;
  final int observationCount;
  final DateTime firstObservedAt;
  final DateTime lastObservedAt;
  final PatternStatus status;
  final DateTime reviewAt;

  LearnedPattern copyWith({
    List<String>? supportingEventIds,
    List<String>? contradictingEventIds,
    double? confidence,
    int? observationCount,
    DateTime? lastObservedAt,
    PatternStatus? status,
    DateTime? reviewAt,
    String? summary,
  }) {
    return LearnedPattern(
      id: id,
      userId: userId,
      patternType: patternType,
      subjectId: subjectId,
      summary: summary ?? this.summary,
      supportingEventIds: supportingEventIds ?? this.supportingEventIds,
      contradictingEventIds:
          contradictingEventIds ?? this.contradictingEventIds,
      confidence: confidence ?? this.confidence,
      observationCount: observationCount ?? this.observationCount,
      firstObservedAt: firstObservedAt,
      lastObservedAt: lastObservedAt ?? this.lastObservedAt,
      status: status ?? this.status,
      reviewAt: reviewAt ?? this.reviewAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'patternType': patternType,
    'subjectId': subjectId,
    'summary': summary,
    'supportingEventIds': supportingEventIds,
    'contradictingEventIds': contradictingEventIds,
    'confidence': confidence,
    'observationCount': observationCount,
    'firstObservedAt': firstObservedAt.toIso8601String(),
    'lastObservedAt': lastObservedAt.toIso8601String(),
    'status': status.name,
    'reviewAt': reviewAt.toIso8601String(),
  };

  factory LearnedPattern.fromJson(Map<String, dynamic> j) => LearnedPattern(
    id: j['id'] as String,
    userId: j['userId'] as String,
    patternType: j['patternType'] as String,
    subjectId: j['subjectId'] as String,
    summary: j['summary'] as String,
    supportingEventIds: (j['supportingEventIds'] as List).cast<String>(),
    contradictingEventIds: (j['contradictingEventIds'] as List).cast<String>(),
    confidence: (j['confidence'] as num).toDouble(),
    observationCount: j['observationCount'] as int,
    firstObservedAt: DateTime.parse(j['firstObservedAt'] as String),
    lastObservedAt: DateTime.parse(j['lastObservedAt'] as String),
    status: PatternStatus.values.byName(j['status'] as String),
    reviewAt: DateTime.parse(j['reviewAt'] as String),
  );
}
