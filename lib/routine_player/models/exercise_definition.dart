import 'pose_definition.dart';

/// Which LAYOUT STRATEGY [MovementDisplay] uses for an exercise's visual
/// container — not the exact ratio itself (see
/// [ExerciseDefinition.visualAspectRatio] for that; different portrait
/// exercises can have different real ratios, e.g. Lunges 600x1220 vs.
/// Squat 400x640, so the ratio is never bucketed/shared by orientation).
enum ExerciseVisualOrientation {
  /// Container is height-driven and centered — a tall image does not try
  /// to fill the full available width (which would make it absurdly
  /// tall on a wide screen).
  portrait,

  /// Container uses most of the available width; height follows the
  /// real ratio.
  landscape,

  /// Also height-driven and centered (behaves like portrait layout-wise).
  square,
}

/// How the ACTIVE-phase movement demonstration cycles through [poses].
enum LoopMode {
  /// Continuously cycles through every pose in order for the whole
  /// exercise duration (Squat, Lunges, Push-Ups — "the demonstration loops
  /// continuously during ACTIVE").
  continuousLoop,

  /// Cycles through each pose for its own [PoseDefinition.phaseSeconds]
  /// (Deep Breathing — inhale/hold/exhale need real pacing, not an even
  /// split).
  timedCycle,

  /// Plays the setup/transition poses once, then holds on the pose marked
  /// [PosePurpose.hold] for the remainder of the exercise, only advancing
  /// to any [PosePurpose.finish] poses in the final few seconds (Plank —
  /// "do not repeatedly animate out of the hold").
  holdAfterSetup,

  /// Plays [poses] forward, then backward excluding both ends, before
  /// repeating — 01->02->03->04->05->06->05->04->03->02->(01...), never
  /// duplicating frame 1 or the last frame at the turnaround. A true
  /// mirror-image reverse; NOT what every exercise's loop needs (see
  /// [customSequence] for one that skips frames on the way back).
  /// Requires at least 3 poses. See [currentPoseFor]'s `reversibleCycle` case.
  reversibleCycle,

  /// Plays an explicit, exercise-authored pose order from
  /// [ExerciseDefinition.customLoopOrder] — for loops that are neither a
  /// clean forward wrap nor a full mirror-reverse (Dead Bug V2:
  /// 01->02->03->04->05->06->04->01->repeat, which returns only as far as
  /// frame 4 before jumping back to frame 1, since both are tabletop
  /// positions and the jump reads as seamless). Exists so one exercise's
  /// unusual loop never has to bend [reversibleCycle]'s semantics for
  /// every other exercise that relies on its true-mirror behavior.
  customSequence,

  /// Plays every [PosePurpose.setup] pose once (summing to
  /// [ExerciseDefinition.loopCycleSeconds]), then repeats the *remaining*
  /// poses — each for its own [PoseDefinition.phaseSeconds] — for however
  /// much of [ExerciseDefinition.durationSeconds] is left (Box Breathing:
  /// a one-time SETTLE frame, then the real 4-4-4-4 inhale/hold/exhale/
  /// hold breathing cycle repeating until the exercise's own duration
  /// timer ends it — never a fixed whole-number-of-cycles requirement,
  /// since 60s isn't an exact multiple of the approved 16s cycle). Unlike
  /// [timedCycle] (which restarts the *whole* pose list, settle frame
  /// included, every lap — Deep Breathing's accepted shape), the settle
  /// frame here is shown exactly once, matching the approved
  /// `breathPattern.cycleSeconds` precisely instead of inflating it.
  timedCycleAfterSetup,
}

/// Spoken-coach content for one exercise. Every field is plain, short,
/// beginner-facing text — no invented claims (no calories/heart-rate/etc).
class VoiceScript {
  const VoiceScript({
    required this.intro,
    required this.benefit,
    required this.setupInstruction,
    this.formCues = const [],
    this.finishCue = 'Done.',
    this.switchSideCue,
    this.quarterCue,
  });

  final String intro; // "Next: Squats."
  final String
  benefit; // "Squats strengthen your legs and support lower-body stability."
  final String
  setupInstruction; // first pose's instruction, spoken before the countdown
  final List<String>
  formCues; // said at most once each, spaced out during ACTIVE
  final String finishCue;

  /// Spoken at ~25% elapsed, for exercises long enough to warrant an
  /// early form reminder before the halfway cue (e.g. Plank). Null for
  /// exercises that don't need one.
  final String? quarterCue;

  /// Spoken at the halfway point instead of the generic "Halfway there."
  /// cue, for bilateral exercises (Lunges) that need the user to actually
  /// switch legs — e.g. "Halfway there. Switch sides." Null for every
  /// non-bilateral exercise.
  final String? switchSideCue;
}

/// A left/right frame animation for a bilateral exercise (currently only
/// Lunges). The first half of [ExerciseDefinition.durationSeconds] cycles
/// through [left], the second half through [right] — real, distinct,
/// individually-verified Figma frames for each side (never a mirrored/
/// flipped copy of the other side). See [bilateralPoseFor].
class BilateralFrameSequence {
  const BilateralFrameSequence({
    required this.left,
    required this.right,
    this.frameDurationMs = 220,
    this.bottomHoldMultiplier = 1.6,
  });

  final List<PoseDefinition> left;
  final List<PoseDefinition> right;

  /// Base time each transitional frame is shown, in ms (Section 3:
  /// "approximately 180-250ms per transitional frame").
  final int frameDurationMs;

  /// Multiplier applied to the frame whose purpose is [PosePurpose.active]
  /// (the "bottom" position) — held slightly longer than transitional
  /// frames for a more natural-looking movement (Section 3).
  final double bottomHoldMultiplier;
}

/// One exercise's complete, verified definition — the single source of
/// truth every RoutinePlayer screen reads from (Prepare, Countdown,
/// Active, Rest preview). No screen resolves exercise imagery on its own.
class ExerciseDefinition {
  const ExerciseDefinition({
    required this.id,
    required this.displayName,
    required this.category,
    required this.playbackType,
    required this.bodyAreas,
    required this.benefitShort,
    required this.durationSeconds,
    this.reps,
    this.restSeconds = 30,
    required this.poses,
    required this.loopMode,
    this.loopCycleSeconds = 4,
    required this.voiceScript,
    this.bilateralFrames,
    this.visualOrientation = ExerciseVisualOrientation.square,
    this.visualAspectRatio = 1.0,
    this.phaseSyncedVoice = false,
    this.crossfadeFrames = true,
    this.customLoopOrder,
    this.thumbnailFrameOrder = 1,
    this.previewAssetPath,
    this.previewAspectRatio,
  }) : assert(
         loopMode != LoopMode.customSequence || customLoopOrder != null,
         'LoopMode.customSequence requires customLoopOrder',
       );

  final String id;
  final String displayName;
  final String category;
  final String playbackType;
  final List<String> bodyAreas;
  final String benefitShort;
  final int durationSeconds;
  final int? reps;
  final int restSeconds;
  final List<PoseDefinition> poses;
  final LoopMode loopMode;

  /// Which layout strategy [MovementDisplay] uses. Defaults to square
  /// (the original Exercise Sequence Library frames' actual shape);
  /// Lunges/Plank/Squat declare their own real strategy explicitly.
  final ExerciseVisualOrientation visualOrientation;

  /// The exact width/height of this exercise's real approved asset —
  /// e.g. 400/640 for Squat, 600/1220 for Lunges, 600/400 for Plank.
  /// Never bucketed/shared across exercises — two portrait exercises can
  /// (and do) have different real ratios.
  final double visualAspectRatio;

  /// How long one full pass through [poses] takes, for [LoopMode.continuousLoop].
  final double loopCycleSeconds;

  final VoiceScript voiceScript;

  /// When true, ACTIVE-phase voice is driven by each [PoseDefinition]'s own
  /// [PoseDefinition.voiceCue]/[PoseDefinition.cuesOnlyVoiceCue] — spoken
  /// once per pose-entry, repeating every cycle (Deep Breathing's "Relax." /
  /// "Breathe in..." / "Hold." / "Breathe out..." synced to each breathing
  /// phase). The generic once-per-exercise cues (quarter/halfway/time-
  /// remaining/finish countdown — tuned for workout-style exercises) are
  /// suppressed for these exercises since an abrupt "3... 2... 1... Done"
  /// mid-breath would break the calm pacing. False for every workout-style
  /// exercise (Squat/Lunges/Pushups/Plank), which keep the original cues.
  final bool phaseSyncedVoice;

  /// When false, [MovementDisplay] replaces frames instantly (no
  /// fade-through-transparent) — a rhythmic movement like Jumping Jack must
  /// never show two overlapping semi-transparent bodies mid-crossfade. True
  /// (the default) keeps every other exercise's existing brief crossfade.
  final bool crossfadeFrames;

  /// 1-indexed [PoseDefinition.order] used for the routine-card list-row
  /// thumbnail specifically (see `_ExerciseThumbnail` in
  /// workout_widgets.dart) — defaults to 1 (the true first frame) for
  /// every exercise. Only overridden for exercises whose approved
  /// thumbnail is a later "peak" frame that reads better as a small icon
  /// than the neutral starting position (Knee-to-Chest/Supine Twist use
  /// their held-stretch frame, order 3). Never affects the Get Ready
  /// preview or the live Active sequence — those always show the real
  /// first pose / current step, unaffected by this.
  final int thumbnailFrameOrder;

  /// Set only for Lunges — when present, this (not [poses]/[loopMode])
  /// drives the ACTIVE-phase movement display. See [bilateralPoseFor].
  final BilateralFrameSequence? bilateralFrames;

  /// Explicit pose-`order` sequence for [LoopMode.customSequence] — e.g.
  /// `[1, 2, 3, 4, 5, 6, 4, 1]` for Dead Bug V2. Required (and only used)
  /// when [loopMode] is [LoopMode.customSequence]; null for every other
  /// exercise, which keep deriving their loop shape from [loopMode] alone.
  final List<int>? customLoopOrder;

  /// A dedicated wide "sequence preview" image (a filmstrip composite of
  /// all six approved frames, not any single pose) shown on RoutinePlayer's
  /// REST/Up Next card instead of [firstPose] — see [previewPose]. Null
  /// for every exercise with no separately-approved preview asset (the
  /// default, existing behavior: Up Next falls back to the real
  /// [firstPose] frame, unchanged). Never used during the live ACTIVE
  /// animation, which always cycles the real per-step [poses] regardless
  /// of this field.
  final String? previewAssetPath;

  /// The real width/height ratio of [previewAssetPath] — always wide
  /// (every approved preview so far is a landscape filmstrip), required
  /// alongside [previewAssetPath] so the Up Next card never squishes it
  /// into the exercise's own (usually portrait) [visualAspectRatio].
  final double? previewAspectRatio;

  /// A per-session duration override — every other field (poses, voice,
  /// asset paths, category) stays identical to the shared registry
  /// definition. Used only by routines that opt in via
  /// `Workout.useCatalogDurations` (e.g. Pre-Swim) so one routine can play
  /// a shared exercise (e.g. EX049 Figure Four Stretch, also used by
  /// Recovery Flow) at its own approved duration without changing that
  /// exercise's duration anywhere else.
  ExerciseDefinition copyWith({int? durationSeconds}) => ExerciseDefinition(
    id: id,
    displayName: displayName,
    category: category,
    playbackType: playbackType,
    bodyAreas: bodyAreas,
    benefitShort: benefitShort,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    reps: reps,
    restSeconds: restSeconds,
    poses: poses,
    loopMode: loopMode,
    loopCycleSeconds: loopCycleSeconds,
    voiceScript: voiceScript,
    bilateralFrames: bilateralFrames,
    visualOrientation: visualOrientation,
    visualAspectRatio: visualAspectRatio,
    phaseSyncedVoice: phaseSyncedVoice,
    crossfadeFrames: crossfadeFrames,
    customLoopOrder: customLoopOrder,
    thumbnailFrameOrder: thumbnailFrameOrder,
    previewAssetPath: previewAssetPath,
    previewAspectRatio: previewAspectRatio,
  );

  /// The pose shown during PREPARE/COUNTDOWN, before movement starts —
  /// left side's frame 1 for bilateral exercises, so the user sees the
  /// real starting position without any cycling (Section 6).
  PoseDefinition get firstPose => bilateralFrames?.left.first ?? poses.first;

  /// The image shown on RoutinePlayer's REST/Up Next card specifically —
  /// [previewAssetPath] when this exercise has one (wrapped in a
  /// synthetic [PoseDefinition] so the existing `MovementDisplay(pose:
  /// ...)` call site needs no new parameter), otherwise exactly
  /// [firstPose], unchanged from before this field existed.
  PoseDefinition get previewPose {
    final preview = previewAssetPath;
    if (preview == null) return firstPose;
    return PoseDefinition(
      poseId: '${id}_preview',
      order: 0,
      label: firstPose.label,
      instruction: firstPose.instruction,
      approvedAsset: preview,
      purpose: firstPose.purpose,
    );
  }

  PoseDefinition get holdPose => poses.firstWhere(
    (p) => p.purpose == PosePurpose.hold,
    orElse: () => poses.last,
  );
  List<PoseDefinition> get finishPoses =>
      poses.where((p) => p.purpose == PosePurpose.finish).toList();
}
