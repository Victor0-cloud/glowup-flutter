/// What role a pose plays in an exercise's movement sequence — drives both
/// which poses the ACTIVE loop cycles through and which ones only appear
/// once (setup/finish), per the Phase 1 spec's requirement that the pose
/// counter and displayed image/instruction always agree.
enum PosePurpose {
  setup,
  active,
  transition,
  hold,
  returnPhase,
  switchSide,
  finish,
}

/// One verified pose in an [ExerciseDefinition]'s real Figma sequence.
/// [approvedAsset] is only ever a real, downloaded, audited Figma image —
/// null means "not verified yet," which callers must render as an
/// unresolved/clean-text state, never a substitute.
class PoseDefinition {
  const PoseDefinition({
    required this.poseId,
    required this.order,
    required this.label,
    required this.instruction,
    required this.approvedAsset,
    required this.purpose,
    this.phaseSeconds,
    this.voiceCue,
    this.cuesOnlyVoiceCue,
  });

  final String poseId;
  final int order; // 1-indexed position in the real Figma sequence
  final String label;
  final String instruction;
  final String? approvedAsset;
  final PosePurpose purpose;

  /// Explicit hold time for this pose within one movement cycle (breathing
  /// exercises need real inhale/hold/exhale pacing, not an even split).
  /// Null means "split the loop cycle evenly across all poses."
  final double? phaseSeconds;

  /// Coach On text spoken every time this pose becomes current — only read
  /// when [ExerciseDefinition.phaseSyncedVoice] is true (e.g. Deep
  /// Breathing's "Relax." / "Breathe in slowly through your nose."). Unlike
  /// [VoiceScript.formCues], this repeats on every cycle, not just once per
  /// exercise occurrence. Null for every non-phase-synced exercise.
  final String? voiceCue;

  /// Cues Only equivalent of [voiceCue] — shorter, e.g. "Breathe in."
  /// Null means this specific phase entry stays silent in Cues Only mode
  /// (not every frame needs its own short cue).
  final String? cuesOnlyVoiceCue;
}
