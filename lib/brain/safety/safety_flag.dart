import '../../workout/models/workout_completion_record.dart' show PainSeverity;

enum SafetyFlagStatus { active, cleared, expired }

/// A deterministic, testable safety constraint derived from one or more
/// `painReported` events for the same exercise. Safety flags always take
/// priority over performance/progression decisions in Tier 2 — see
/// `AdaptationEngine`. Scoped to [exerciseId] rather than a generalized
/// body area: this app has no body-area-to-exercise map today, so
/// generalizing a flag across other exercises hitting the same body area
/// would risk over- or under-blocking without real evidence — a documented
/// scope limit, not an oversight.
class SafetyFlag {
  const SafetyFlag({
    required this.id,
    required this.userId,
    required this.exerciseId,
    this.bodyArea,
    required this.severity,
    required this.status,
    required this.sourceEventIds,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
  });

  final String id;
  final String userId;
  final String exerciseId;
  final String? bodyArea;
  final PainSeverity severity;
  final SafetyFlagStatus status;

  /// Every `painReported` event that contributed to this flag — the
  /// traceable evidence a "Why this?" explanation and any audit must be
  /// able to point back to.
  final List<String> sourceEventIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime expiresAt;

  bool isActiveAt(DateTime now) =>
      status == SafetyFlagStatus.active && now.isBefore(expiresAt);

  SafetyFlag copyWith({
    PainSeverity? severity,
    SafetyFlagStatus? status,
    List<String>? sourceEventIds,
    DateTime? updatedAt,
    DateTime? expiresAt,
  }) {
    return SafetyFlag(
      id: id,
      userId: userId,
      exerciseId: exerciseId,
      bodyArea: bodyArea,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      sourceEventIds: sourceEventIds ?? this.sourceEventIds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'exerciseId': exerciseId,
    if (bodyArea != null) 'bodyArea': bodyArea,
    'severity': severity.name,
    'status': status.name,
    'sourceEventIds': sourceEventIds,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
  };

  factory SafetyFlag.fromJson(Map<String, dynamic> j) => SafetyFlag(
    id: j['id'] as String,
    userId: j['userId'] as String,
    exerciseId: j['exerciseId'] as String,
    bodyArea: j['bodyArea'] as String?,
    severity: PainSeverity.values.byName(j['severity'] as String),
    status: SafetyFlagStatus.values.byName(j['status'] as String),
    sourceEventIds: (j['sourceEventIds'] as List).cast<String>(),
    createdAt: DateTime.parse(j['createdAt'] as String),
    updatedAt: DateTime.parse(j['updatedAt'] as String),
    expiresAt: DateTime.parse(j['expiresAt'] as String),
  );
}
