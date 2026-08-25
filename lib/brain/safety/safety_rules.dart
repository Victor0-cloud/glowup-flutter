import '../../workout/models/workout_completion_record.dart' show PainSeverity;
import 'safety_flag.dart';

/// How long a fresh safety flag stays active before it needs new evidence
/// to renew — configurable, not hardcoded inline at every call site.
const kSafetyFlagValidity = Duration(days: 14);

int _severityRank(PainSeverity s) => switch (s) {
  PainSeverity.mild => 1,
  PainSeverity.moderate => 2,
  PainSeverity.severe => 3,
};

PainSeverity _maxSeverity(PainSeverity a, PainSeverity b) =>
    _severityRank(a) >= _severityRank(b) ? a : b;

/// Tier 1, pure and deterministic — no AI provider, no network, and it
/// must keep working exactly the same whether or not one is ever
/// connected. Given a new `painReported` event's details and any existing
/// active flag for the same exercise, decides what the stored [SafetyFlag]
/// should become: a new flag, or an escalated version of the existing one
/// (higher severity wins, validity extended, evidence appended).
SafetyFlag deriveSafetyFlagFromPainReport({
  required String userId,
  required String exerciseId,
  String? bodyArea,
  required PainSeverity severity,
  required String sourceEventId,
  required DateTime now,
  SafetyFlag? existingActiveFlag,
  required String Function() newId,
}) {
  if (existingActiveFlag == null) {
    return SafetyFlag(
      id: newId(),
      userId: userId,
      exerciseId: exerciseId,
      bodyArea: bodyArea,
      severity: severity,
      status: SafetyFlagStatus.active,
      sourceEventIds: [sourceEventId],
      createdAt: now,
      updatedAt: now,
      expiresAt: now.add(kSafetyFlagValidity),
    );
  }
  return existingActiveFlag.copyWith(
    severity: _maxSeverity(existingActiveFlag.severity, severity),
    sourceEventIds: [...existingActiveFlag.sourceEventIds, sourceEventId],
    updatedAt: now,
    expiresAt: now.add(kSafetyFlagValidity),
  );
}

/// Explicit user- or rule-driven clear — the deterministic dismissal path
/// required alongside pattern correction/dismissal. Always available
/// whether or not an AI provider exists.
SafetyFlag clearSafetyFlag(SafetyFlag flag, {required DateTime now}) {
  return flag.copyWith(status: SafetyFlagStatus.cleared, updatedAt: now);
}

/// Tier 2 reads this — never Tier 3/4 — to decide whether an exercise
/// needs a safety-driven typed action. Severe pain always pauses;
/// mild/moderate still surfaces (so the Coach can explain and offer a
/// reduced-difficulty path) but doesn't hard-block by itself.
bool requiresSafetyPause(SafetyFlag flag) =>
    flag.severity == PainSeverity.severe;
