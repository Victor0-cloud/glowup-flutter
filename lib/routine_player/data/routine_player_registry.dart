import '../models/exercise_definition.dart';
import '../models/pose_definition.dart';

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/deep_breathing/female/v2/EX001_F_0N_*.png`.
/// Uniform 277x265 (confirmed before use). Replaces the V1 illustrated set
/// below — this is a REPLACEMENT of EX001's implementation, not a new
/// exercise: same id, same slug, same Bedtime Meditation placement (first
/// exercise). The V1 asset directory is intentionally left in place/still
/// bundled in pubspec.yaml (not deleted) until this V2 replacement is
/// verified, per the explicit "do not delete legacy assets" instruction —
/// nothing in the registry resolves to it anymore, exactly as the old V1
/// definition below already didn't resolve to the even-older Tier 2
/// EX001/female/*.png photos.
///
/// Redesigned breathing cycle (was 1.0/2.0/2.0/2.0/2.5/2.5s = 12.0s with a
/// forced 2.0s HOLD phase): now 4s inhale (frames 1-3) + 6s exhale (frames
/// 4-6) = 10.0s cycle, six full cycles across the 60s exercise, NO hold —
/// forcing a breath hold is explicitly disallowed by the new spec. Weighted
/// (not an even 3-way split) within each phase, same non-even-split
/// convention as every other exercise: SETTLE briefer, the "full" frame
/// held slightly longer.
///
/// Voice: still phase-synced (this exercise remains the one legitimate use
/// of [ExerciseDefinition.phaseSyncedVoice] in the app — its phase
/// durations, ~1.2-2.1s each, are long enough for TTS to finish before the
/// next frame, unlike Sun Salutation's original attempt at the same
/// mechanism). Per the new spec, a cue speaks only once per inhale (frame
/// 2, INHALE_BEGIN) and once per exhale (frame 4, EXHALE_BEGIN) — every
/// other frame's [PoseDefinition.voiceCue] is deliberately null, so the
/// user rests in quiet between cues rather than hearing narration on
/// every single frame change. This is the single synchronized clock the
/// spec asks for: image, voice cue, phase label, and pause/resume all
/// already read from the same `RoutinePlayerState.activeElapsedMs` via
/// [currentPoseFor] — audited for a separate voice timer and found none;
/// unlike Sun Salutation, there was no real desync bug here to fix, only
/// the forced-hold/12s-cycle design that's been redesigned above.
///
/// NOT implemented (honest gaps, not silently dropped — flagged in the
/// implementation report): the "One last slow breath." cue for the final
/// (6th) cycle specifically — phaseSyncedVoice fires by pose-entry, not by
/// cycle count, so there's no existing mechanism to vary a cue on the last
/// repetition without new engine state; and the on-screen expanding/
/// contracting breath-circle indicator — a new UI widget, not registry
/// data, out of scope for this pass. AI Coach post-exercise feedback is
/// also not implemented — same reasoning as Savasana/EX060: it needs new
/// shared components (TellCoachPanel etc.) that don't exist yet.
String _deepBreathingV2Asset(String file) =>
    'assets/glow_up/exercises/deep_breathing/female/v2/EX001_F_$file.png';

final _deepBreathing = ExerciseDefinition(
  id: 'EX001',
  displayName: 'Deep Breathing',
  category: 'Bedtime',
  playbackType: 'BREATHING',
  bodyAreas: const ['Lungs', 'Nervous System'],
  benefitShort: 'Calms your body and mind before sleep.',
  durationSeconds: 60,
  poses: [
    PoseDefinition(
      poseId: 'deep_breathing_v2_01',
      order: 1,
      label: 'SETTLE',
      instruction: 'Sit comfortably and relax your shoulders.',
      approvedAsset: _deepBreathingV2Asset('01_SETTLE'),
      purpose: PosePurpose.setup,
      phaseSeconds: 1.2,
    ),
    PoseDefinition(
      poseId: 'deep_breathing_v2_02',
      order: 2,
      label: 'INHALE BEGIN',
      instruction: 'Begin breathing in slowly.',
      approvedAsset: _deepBreathingV2Asset('02_INHALE_BEGIN'),
      purpose: PosePurpose.transition,
      phaseSeconds: 1.3,
      voiceCue: 'Breathe in slowly through your nose.',
      cuesOnlyVoiceCue: 'Breathe in.',
    ),
    PoseDefinition(
      poseId: 'deep_breathing_v2_03',
      order: 3,
      label: 'INHALE FULL',
      instruction: 'Keep filling your lungs, gently.',
      approvedAsset: _deepBreathingV2Asset('03_INHALE_FULL'),
      purpose: PosePurpose.active,
      phaseSeconds: 1.5,
    ),
    PoseDefinition(
      poseId: 'deep_breathing_v2_04',
      order: 4,
      label: 'EXHALE BEGIN',
      instruction: 'Begin breathing out slowly.',
      approvedAsset: _deepBreathingV2Asset('04_EXHALE_BEGIN'),
      purpose: PosePurpose.transition,
      phaseSeconds: 1.9,
      voiceCue: 'Breathe out gently and let your body soften.',
      cuesOnlyVoiceCue: 'Breathe out.',
    ),
    PoseDefinition(
      poseId: 'deep_breathing_v2_05',
      order: 5,
      label: 'EXHALE FULL',
      instruction: 'Let the last of the breath go.',
      approvedAsset: _deepBreathingV2Asset('05_EXHALE_FULL'),
      purpose: PosePurpose.active,
      phaseSeconds: 2.1,
    ),
    PoseDefinition(
      poseId: 'deep_breathing_v2_06',
      order: 6,
      label: 'RESET',
      instruction: 'Rest here for a moment before the next breath.',
      approvedAsset: _deepBreathingV2Asset('06_RESET'),
      purpose: PosePurpose.transition,
      phaseSeconds: 2.0,
    ),
  ],
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.square,
  visualAspectRatio: 277 / 265, // real Deep Breathing V2 frames
  phaseSyncedVoice:
      true, // per-pose repeating breathing cues, not the generic workout countdown cues
  voiceScript: const VoiceScript(
    intro: 'Deep Breathing.',
    benefit: 'This helps calm your body and mind before rest.',
    setupInstruction:
        'Sit comfortably and relax your shoulders. Breathe comfortably without forcing the breath — '
        'return to normal breathing if you feel dizzy or uncomfortable.',
    finishCue: 'Let your breathing return to normal.',
  ),
);

/// Real, individually-exported (not manually cropped) V1 Squat frame —
/// Figma `wZpdIxyGJ3DDPVHtZtwQeC`, node `01_SQUAT > SQUAT_ANIMATION_ASSETS_V1
/// > FEMALE` (nodes 431:46-431:51). Portrait 400×600 (@2x 800×1280) — its
/// own real ratio, distinct from Lunges' 600x1220, never bucketed/shared.
/// Replaces the original static EX007/female/0N.png Exercise Sequence
/// Library set for the ACTIVE-phase animation.
String _squatV1Asset(String file) =>
    'assets/glow_up/exercises/squat/female/v1/squat_female_$file.png';

final _squat = ExerciseDefinition(
  id: 'EX007',
  displayName: 'Squat',
  category: 'Strength',
  playbackType: 'REPS',
  bodyAreas: const ['Legs', 'Glutes'],
  benefitShort: 'Squats strengthen your lower body and support your core.',
  durationSeconds: 45,
  reps: 15,
  poses: [
    PoseDefinition(
      poseId: 'squat_v1_01',
      order: 1,
      label: 'START',
      instruction: 'Stand with feet shoulder-width apart.',
      approvedAsset: _squatV1Asset('01_start'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.9,
    ),
    PoseDefinition(
      poseId: 'squat_v1_02',
      order: 2,
      label: 'BEGIN LOWER',
      instruction: 'Begin pushing your hips back.',
      approvedAsset: _squatV1Asset('02_begin_lower'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'squat_v1_03',
      order: 3,
      label: 'MID LOWER',
      instruction: 'Continue lowering with control.',
      approvedAsset: _squatV1Asset('03_mid_lower'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'squat_v1_04',
      order: 4,
      label: 'BOTTOM',
      instruction: 'Hold at the bottom of the squat.',
      approvedAsset: _squatV1Asset('04_bottom'),
      purpose: PosePurpose.active,
      phaseSeconds: 1.1,
    ),
    PoseDefinition(
      poseId: 'squat_v1_05',
      order: 5,
      label: 'BEGIN RISE',
      instruction: 'Drive through your heels to rise.',
      approvedAsset: _squatV1Asset('05_begin_rise'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'squat_v1_06',
      order: 6,
      label: 'RETURN STAND',
      instruction: 'Return to standing.',
      approvedAsset: _squatV1Asset('06_return_stand'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 1.1,
    ),
  ],
  // Weighted timed loop (not an even/fast split) — ~5.2s per full
  // standing->descending->bottom->rising->standing cycle, with the two
  // stable positions (BOTTOM, RETURN STAND) held longer than the
  // transitional frames, so it reads as a controlled demonstration rather
  // than a slideshow (matches the cadence approach already used for Plank).
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.portrait,
  visualAspectRatio:
      400 /
      640, // real Squat V1 frames, 400x640 (distinct from Lunges' 600x1220)
  voiceScript: const VoiceScript(
    intro: 'Next: Squats.',
    benefit: 'Squats strengthen your lower body and support your core.',
    setupInstruction: 'Stand with feet shoulder-width apart.',
    quarterCue: 'Keep your chest lifted and sit your hips back.',
    formCues: [
      'Keep your chest lifted and knees tracking with your feet.',
    ], // halfway addendum
    finishCue: 'Nice work.',
  ),
);

/// Real, individually-exported (not manually cropped) Figma frame for the
/// Lunge animation — file key `wZpdIxyGJ3DDPVHtZtwQeC`, node
/// `GLOW_UP_ANIMATION_ASSETS > LUNGES > FEMALE > LEFT/RIGHT`. Each frame
/// was fetched via `download_assets`' node `export` (which renders the
/// node's own flattened bounding box) rather than the raw embedded image
/// URL — the raw asset behind every frame is actually one shared
/// 1536×1024 reference sheet, so using it directly would have required
/// manually computing a CSS-percentage crop, exactly the kind of
/// independent repositioning the brief prohibited.
String _lungeAsset(String side, String file) =>
    'assets/glow_up/exercise_animations/lunges/female/$side/$file.png';

final _lungeLeftFrames = [
  PoseDefinition(
    poseId: 'lunge_left_01',
    order: 1,
    label: 'START',
    instruction: 'Stand tall with feet hip-width apart.',
    approvedAsset: _lungeAsset('left', '01_start'),
    purpose: PosePurpose.setup,
  ),
  PoseDefinition(
    poseId: 'lunge_left_02',
    order: 2,
    label: 'STEP FORWARD',
    instruction: 'Step forward with your left leg.',
    approvedAsset: _lungeAsset('left', '02_step_forward'),
    purpose: PosePurpose.transition,
  ),
  PoseDefinition(
    poseId: 'lunge_left_03',
    order: 3,
    label: 'LOWER',
    instruction: 'Lower your back knee toward the floor.',
    approvedAsset: _lungeAsset('left', '03_lower'),
    purpose: PosePurpose.transition,
  ),
  PoseDefinition(
    poseId: 'lunge_left_04',
    order: 4,
    label: 'BOTTOM',
    instruction: 'Hold the lunge position with control.',
    approvedAsset: _lungeAsset('left', '04_bottom'),
    purpose: PosePurpose.active,
  ),
  PoseDefinition(
    poseId: 'lunge_left_05',
    order: 5,
    label: 'PUSH UP',
    instruction: 'Push through your front heel to rise.',
    approvedAsset: _lungeAsset('left', '05_push_up'),
    purpose: PosePurpose.transition,
  ),
  PoseDefinition(
    poseId: 'lunge_left_06',
    order: 6,
    label: 'RETURN',
    instruction: 'Return to standing.',
    approvedAsset: _lungeAsset('left', '06_return'),
    purpose: PosePurpose.returnPhase,
  ),
];

final _lungeRightFrames = [
  PoseDefinition(
    poseId: 'lunge_right_01',
    order: 1,
    label: 'START',
    instruction: 'Stand tall with feet hip-width apart.',
    approvedAsset: _lungeAsset('right', '01_start'),
    purpose: PosePurpose.setup,
  ),
  PoseDefinition(
    poseId: 'lunge_right_02',
    order: 2,
    label: 'STEP FORWARD',
    instruction: 'Step forward with your right leg.',
    approvedAsset: _lungeAsset('right', '02_step_forward'),
    purpose: PosePurpose.transition,
  ),
  PoseDefinition(
    poseId: 'lunge_right_03',
    order: 3,
    label: 'LOWER',
    instruction: 'Lower your back knee toward the floor.',
    approvedAsset: _lungeAsset('right', '03_lower'),
    purpose: PosePurpose.transition,
  ),
  PoseDefinition(
    poseId: 'lunge_right_04',
    order: 4,
    label: 'BOTTOM',
    instruction: 'Hold the lunge position with control.',
    approvedAsset: _lungeAsset('right', '04_bottom'),
    purpose: PosePurpose.active,
  ),
  PoseDefinition(
    poseId: 'lunge_right_05',
    order: 5,
    label: 'PUSH UP',
    instruction: 'Push through your front heel to rise.',
    approvedAsset: _lungeAsset('right', '05_push_up'),
    purpose: PosePurpose.transition,
  ),
  PoseDefinition(
    poseId: 'lunge_right_06',
    order: 6,
    label: 'RETURN',
    instruction: 'Return to standing.',
    approvedAsset: _lungeAsset('right', '06_return'),
    purpose: PosePurpose.returnPhase,
  ),
];

final _lunges = ExerciseDefinition(
  id: 'EX008',
  displayName: 'Lunges',
  category: 'Strength',
  playbackType: 'SIDE_SEQUENCE',
  bodyAreas: const ['Legs', 'Glutes', 'Balance'],
  benefitShort: 'Lunges build lower-body strength and stability.',
  durationSeconds: 45,
  reps: 10,
  poses:
      _lungeLeftFrames, // used for step-count/order display; ACTIVE movement is driven by bilateralFrames below
  loopMode: LoopMode.continuousLoop,
  loopCycleSeconds: 5,
  bilateralFrames: BilateralFrameSequence(
    left: _lungeLeftFrames,
    right: _lungeRightFrames,
  ),
  visualOrientation: ExerciseVisualOrientation.portrait,
  visualAspectRatio:
      600 / 1220, // real Lunge V2 frames (distinct from Squat's 400x640)
  voiceScript: const VoiceScript(
    intro: 'Next: Lunges.',
    benefit:
        'Lunges strengthen your lower body and help build balance and stability.',
    setupInstruction: 'Stand tall with feet hip-width apart.',
    formCues: ['Keep your front knee over your ankle.'],
    finishCue: 'Great job.',
    switchSideCue: 'Halfway there. Switch sides.',
  ),
);

/// Real, individually-exported (not manually cropped) V1 Pushups frame —
/// Figma `wZpdIxyGJ3DDPVHtZtwQeC`, node `04_PUSHUPS > PUSHUP_ANIMATION_ASSETS_V1`
/// (nodes 440:4-440:9). Landscape 600×400 (@2x 1200×800) — its own real
/// ratio, kept as an explicit per-exercise value (not shared with Plank's
/// numerically-identical-but-separately-declared 3:2). The QA board's
/// reverse (6->5->4->3->2->1) row (nodes 440:45-440:50) is a design-time
/// smoothness preview only — never used as production frames; the real
/// animation is the forward six, repeating forward-only per the brief.
/// Replaces the old EX010/female/0N.png Exercise Sequence Library set.
///
/// Named "Pushups" (not "Push-Ups") throughout — display text AND every
/// voice string — per explicit instruction: the old hyphenated spelling
/// was being mispronounced by TTS.
String _pushupsV1Asset(String file) =>
    'assets/glow_up/exercises/pushups/female/v1/pushup_female_$file.png';

final _pushUps = ExerciseDefinition(
  id: 'EX010',
  displayName: 'Pushups',
  category: 'Strength',
  playbackType: 'REPS',
  bodyAreas: const ['Chest', 'Shoulders', 'Arms', 'Core'],
  benefitShort: 'Pushups strengthen your chest, shoulders, arms, and core.',
  durationSeconds: 40,
  reps: 12,
  poses: [
    PoseDefinition(
      poseId: 'pushups_v1_01',
      order: 1,
      label: 'START',
      instruction:
          'Start in a high plank. Keep your body in a straight line and brace your core.',
      approvedAsset: _pushupsV1Asset('01_start'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.5,
    ),
    PoseDefinition(
      poseId: 'pushups_v1_02',
      order: 2,
      label: 'BEGIN LOWER',
      instruction: 'Begin lowering with control.',
      approvedAsset: _pushupsV1Asset('02_begin_lower'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.5,
    ),
    PoseDefinition(
      poseId: 'pushups_v1_03',
      order: 3,
      label: 'MID LOWER',
      instruction: 'Continue lowering your chest.',
      approvedAsset: _pushupsV1Asset('03_mid_lower'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.5,
    ),
    PoseDefinition(
      poseId: 'pushups_v1_04',
      order: 4,
      label: 'BOTTOM',
      instruction: 'Chest just above the floor.',
      approvedAsset: _pushupsV1Asset('04_bottom'),
      purpose: PosePurpose.active,
      phaseSeconds: 0.5,
    ),
    PoseDefinition(
      poseId: 'pushups_v1_05',
      order: 5,
      label: 'BEGIN PUSH',
      instruction: 'Push back up with control.',
      approvedAsset: _pushupsV1Asset('05_begin_push'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.5,
    ),
    PoseDefinition(
      poseId: 'pushups_v1_06',
      order: 6,
      label: 'RETURN HIGH',
      instruction: 'Return to high plank.',
      approvedAsset: _pushupsV1Asset('06_return_high_plank'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.5,
    ),
  ],
  // Even 500ms/frame (within the requested 450-600ms QA range), forward-
  // only repeat (01->06->01...) — never the QA board's reverse preview
  // order. 3.0s per full cycle: controlled, not GIF-fast.
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.landscape,
  visualAspectRatio: 600 / 400, // real Pushups V1 frames
  voiceScript: const VoiceScript(
    intro: 'Pushups.',
    benefit: 'This exercise strengthens your chest, shoulders, arms, and core.',
    setupInstruction:
        'Start in a high plank. Keep your body in a straight line and brace your core.',
    // Fires once during ACTIVE (the quarter-cue mechanism) instead of
    // being appended to halfway — halfway stays exactly "Halfway there."
    // per the requested script, with no extra clause tacked on.
    quarterCue: 'Lower with control. Keep your core strong.',
    finishCue: 'Strong effort.',
  ),
);

/// Real, downloaded, individually-exported (not manually cropped) V2
/// Plank frame — Figma `wZpdIxyGJ3DDPVHtZtwQeC`, node
/// `GLOWUP_ROUTINE_ANIMATION_ASSETS_V2 > PLANK_ANIMATION_ASSETS_V2 >
/// FEMALE > STANDARD` (nodes 417:6-417:11). Landscape 600×400 (@2x
/// 1200×800) — deliberately separate from the old portrait V1 Plank set
/// (`PLANK_ANIMATION_ASSETS`, node 412:2) and from the original
/// EX011/female placeholder set, neither of which is used anymore.
String _plankV2Asset(String file) =>
    'assets/glow_up/exercises/plank/female/v2/plank_female_$file.png';

final _plank = ExerciseDefinition(
  id: 'EX011',
  displayName: 'Plank',
  category: 'Core',
  playbackType:
      'REPS', // continuous timed loop, not a static hold — see loopMode below
  bodyAreas: const ['Core', 'Shoulders'],
  benefitShort:
      'Plank strengthens your core and supports stability and posture.',
  durationSeconds: 30,
  poses: [
    PoseDefinition(
      poseId: 'plank_v2_01',
      order: 1,
      label: 'HIGH START',
      instruction: 'Start in a high plank with hands under your shoulders.',
      approvedAsset: _plankV2Asset('01_high_start'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'plank_v2_02',
      order: 2,
      label: 'BEGIN LOWER',
      instruction: 'Begin lowering with control.',
      approvedAsset: _plankV2Asset('02_begin_lower'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.55,
    ),
    PoseDefinition(
      poseId: 'plank_v2_03',
      order: 3,
      label: 'MID LOWER',
      instruction: 'Continue lowering onto your forearms.',
      approvedAsset: _plankV2Asset('03_mid_lower'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.55,
    ),
    PoseDefinition(
      poseId: 'plank_v2_04',
      order: 4,
      label: 'FOREARM PLANK',
      instruction: 'Hold a straight line from head to heels.',
      approvedAsset: _plankV2Asset('04_forearm_plank'),
      purpose: PosePurpose.active,
      phaseSeconds: 0.9,
    ),
    PoseDefinition(
      poseId: 'plank_v2_05',
      order: 5,
      label: 'BEGIN PUSH',
      instruction: 'Press back up with control.',
      approvedAsset: _plankV2Asset('05_begin_push'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.65,
    ),
    PoseDefinition(
      poseId: 'plank_v2_06',
      order: 6,
      label: 'RETURN HIGH',
      instruction: 'Return to the high plank position.',
      approvedAsset: _plankV2Asset('06_return_high'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.9,
    ),
  ],
  // Continuous 01->06->01 loop with per-frame weighted timing (not an
  // even split) — the two stable positions (04 forearm, 06 return high)
  // get perceptible holds while the transitional frames move faster.
  // ~4.25s per full cycle. See currentPoseFor's LoopMode.timedCycle.
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.landscape,
  visualAspectRatio: 3 / 2, // real Plank V2 frames, 600x400 / 1200x800
  voiceScript: const VoiceScript(
    intro: 'Next: Plank.',
    benefit: 'Plank strengthens your core and supports stability and posture.',
    setupInstruction:
        'Place your hands under your shoulders, extend your legs, and keep your body in a straight line.',
    quarterCue:
        'Keep your core engaged and maintain a straight line from your head to your heels.',
    formCues: [
      'Keep your hips level and breathe steadily.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Great work.',
  ),
);

/// Real, individually-exported (not manually cropped) V1 Jumping Jack
/// frame — Figma `wZpdIxyGJ3DDPVHtZtwQeC`, node `06_JUMPING_JACK >
/// JUMPING_JACK_ANIMATION_ASSETS_V1` (nodes 455:13-455:18). Portrait
/// 400×600 — its own real ratio, decoupled from every other exercise's.
/// The QA board's forward-sequence preview (nodes 455:23-455:28, identical
/// content to production) and its separate reversible-loop preview
/// (455:31-455:41, an explicit ping-pong 01->06->01 smoothness check) are
/// both design-time-only — production uses only the forward six, looping
/// 01->06->01->repeat, never the reversible pattern.
String _jumpingJackV1Asset(String file) =>
    'assets/glow_up/exercises/jumping_jack/female/v1/jumping_jack_female_$file.png';

/// Reuses id `EX009` — same convention as every other RoutinePlayer
/// exercise (EX001/007/008/010/011), whose ids deliberately mirror the same
/// real-world exercise's id in the separate legacy `lib/workout` catalog
/// (`EX009` = "Jumping Jacks" there too). RoutinePlayer does not import
/// that module; this is a from-scratch definition using only real,
/// individually-verified V1 frames.
final _jumpingJack = ExerciseDefinition(
  id: 'EX009',
  displayName: 'Jumping Jack',
  category: 'Cardio',
  playbackType: 'REPS',
  bodyAreas: const ['Full Body', 'Cardio'],
  benefitShort:
      'This full-body exercise gets your arms and legs moving together and helps raise your heart rate.',
  durationSeconds: 30,
  poses: [
    PoseDefinition(
      poseId: 'jumping_jack_v1_01',
      order: 1,
      label: 'START',
      instruction:
          'Stand tall with your feet together and your arms relaxed at your sides.',
      approvedAsset: _jumpingJackV1Asset('01_start'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.18,
    ),
    PoseDefinition(
      poseId: 'jumping_jack_v1_02',
      order: 2,
      label: 'OPENING',
      instruction: 'Jump your feet apart as your arms begin to rise.',
      approvedAsset: _jumpingJackV1Asset('02_opening'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.18,
    ),
    PoseDefinition(
      poseId: 'jumping_jack_v1_03',
      order: 3,
      label: 'FULL OPEN',
      instruction: 'Feet apart, arms fully overhead.',
      approvedAsset: _jumpingJackV1Asset('03_full_open'),
      purpose: PosePurpose.active,
      phaseSeconds: 0.22,
    ),
    PoseDefinition(
      poseId: 'jumping_jack_v1_04',
      order: 4,
      label: 'CLOSING',
      instruction: 'Bring your arms down as your legs return inward.',
      approvedAsset: _jumpingJackV1Asset('04_closing'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.18,
    ),
    PoseDefinition(
      poseId: 'jumping_jack_v1_05',
      order: 5,
      label: 'FEET TOGETHER',
      instruction: 'Feet together, arms back down.',
      approvedAsset: _jumpingJackV1Asset('05_feet_together'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.18,
    ),
    PoseDefinition(
      poseId: 'jumping_jack_v1_06',
      order: 6,
      label: 'READY',
      instruction: 'Stable, upright, ready position.',
      approvedAsset: _jumpingJackV1Asset('06_ready'),
      purpose: PosePurpose.finish,
      phaseSeconds: 0.16,
    ),
  ],
  // Weighted 180/180/220/180/180/160ms per frame (never an even split) =
  // 1.10s per complete visual cycle — a rhythmic movement, not a slow
  // held-pose demonstration like Squat/Plank. ~27 cycles across the 30s
  // exercise. See currentPoseFor's LoopMode.timedCycle.
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.portrait,
  visualAspectRatio: 400 / 600, // real Jumping Jack V1 frames
  // Rhythmic movement: two overlapping semi-transparent bodies mid-crossfade
  // would look wrong — frames replace instantly instead (Section 12).
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: 'Next: Jumping Jack.',
    benefit:
        'This full-body exercise gets your arms and legs moving together and helps raise your heart rate.',
    setupInstruction:
        'Stand tall with your feet together and your arms relaxed at your sides.',
    quarterCue: 'Keep a steady rhythm.',
    formCues: [
      'Land softly and keep your core engaged.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Done.',
  ),
);

/// Real, individually-exported (not manually cropped) V1 Glute Bridge
/// frame — Figma `wZpdIxyGJ3DDPVHtZtwQeC`, node `07_GLUTE_BRIDGE >
/// GLUTE_BRIDGE_ANIMATION_ASSETS_V1` (nodes 465:13-465:18). Landscape
/// 600×400 — its own real ratio, kept as an explicit per-exercise value
/// (not shared with Plank's numerically-identical-but-separately-declared
/// 3:2). The QA board's forward-sequence preview (465:23-465:28, identical
/// content to production) and its separate reversible-loop preview
/// (465:31-465:37, an explicit 01->02->03->04->03->02->01 smoothness check)
/// are both design-time-only — production uses only the forward six,
/// looping 01->06->01->repeat, never the reversible pattern.
String _gluteBridgeV1Asset(String file) =>
    'assets/glow_up/exercises/glute_bridge/female/v1/glute_bridge_female_$file.png';

/// Reuses id `EX018` — same convention as every other RoutinePlayer
/// exercise, whose ids deliberately mirror the same real-world exercise's
/// id in the separate legacy `lib/workout` catalog (`EX018` = "Glute
/// Bridge" there too). RoutinePlayer does not import that module; this is a
/// from-scratch definition using only real, individually-verified V1 frames.
final _gluteBridge = ExerciseDefinition(
  id: 'EX018',
  displayName: 'Glute Bridge',
  category: 'Strength',
  playbackType: 'REPS',
  bodyAreas: const ['Glutes', 'Hamstrings', 'Core'],
  benefitShort: 'Glute bridges strengthen your glutes, hamstrings, and core.',
  durationSeconds: 40,
  poses: [
    PoseDefinition(
      poseId: 'glute_bridge_v1_01',
      order: 1,
      label: 'START',
      instruction: 'Lie on your back with your knees bent and feet flat.',
      approvedAsset: _gluteBridgeV1Asset('01_start'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'glute_bridge_v1_02',
      order: 2,
      label: 'ENGAGE',
      instruction: 'Engage your core and squeeze your glutes.',
      approvedAsset: _gluteBridgeV1Asset('02_engage'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'glute_bridge_v1_03',
      order: 3,
      label: 'LIFT',
      instruction: 'Lift your hips toward the ceiling.',
      approvedAsset: _gluteBridgeV1Asset('03_lift'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'glute_bridge_v1_04',
      order: 4,
      label: 'TOP',
      instruction: 'Squeeze at the top.',
      approvedAsset: _gluteBridgeV1Asset('04_top'),
      purpose: PosePurpose.active,
      phaseSeconds: 1.1,
    ),
    PoseDefinition(
      poseId: 'glute_bridge_v1_05',
      order: 5,
      label: 'LOWER',
      instruction: 'Lower with control.',
      approvedAsset: _gluteBridgeV1Asset('05_lower'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'glute_bridge_v1_06',
      order: 6,
      label: 'RETURN',
      instruction: 'Return to the starting position.',
      approvedAsset: _gluteBridgeV1Asset('06_return'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.7,
    ),
  ],
  // Weighted 700/700/700/1100/700/700ms per frame (never an even split) —
  // TOP held ~1.6x longer than a transitional frame so the glute-squeeze
  // position is visible, matching Squat/Plank's hold convention. 4.6s per
  // full cycle: smooth and controlled, not a fast GIF.
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.landscape,
  visualAspectRatio: 600 / 400, // real Glute Bridge V1 frames
  voiceScript: const VoiceScript(
    intro: 'Next: Glute Bridge.',
    benefit: 'Glute bridges strengthen your glutes, hamstrings, and core.',
    setupInstruction:
        'Lie on your back with your knees bent and feet flat. Engage your core and squeeze your glutes.',
    quarterCue: 'Keep your core braced.',
    formCues: [
      'Lift through your heels.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Nice work.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/calf_raises/female/v2/EX020_F_0N_*.png`. Same
/// provenance model as Russian Twist (EX015): placed directly on disk, no
/// Figma node reference exists for this set — do not invent one. Human
/// visual approval completed prior to this implementation; uniform
/// 277×265 canvas confirmed on all six frames.
///
/// Loop order 01->02->03->04->05->06->(01...), a plain forward wrap, per
/// the approved sequence — [LoopMode.timedCycle] already produces this,
/// same mechanism as every other completed exercise.
String _calfRaisesV2Asset(String file) =>
    'assets/glow_up/exercises/calf_raises/female/v2/EX020_F_$file.png';

final _calfRaises = ExerciseDefinition(
  id: 'EX020',
  displayName: 'Calf Raises',
  category: 'Strength',
  playbackType: 'REPS',
  bodyAreas: const ['Calves'],
  benefitShort:
      'Calf raises strengthen your calves and improve ankle stability.',
  durationSeconds: 35,
  reps: 20,
  poses: [
    PoseDefinition(
      poseId: 'calf_raises_v2_01',
      order: 1,
      label: 'START',
      instruction: 'Stand tall with your feet hip-width apart.',
      approvedAsset: _calfRaisesV2Asset('01_START'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.55,
    ),
    PoseDefinition(
      poseId: 'calf_raises_v2_02',
      order: 2,
      label: 'RISE',
      instruction: 'Rise onto your toes with control.',
      approvedAsset: _calfRaisesV2Asset('02_RISE'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'calf_raises_v2_03',
      order: 3,
      label: 'TOP HOLD',
      instruction: 'Hold at the top and squeeze your calves.',
      approvedAsset: _calfRaisesV2Asset('03_TOP_HOLD'),
      purpose: PosePurpose.active,
      phaseSeconds: 0.75,
    ),
    PoseDefinition(
      poseId: 'calf_raises_v2_04',
      order: 4,
      label: 'LOWER',
      instruction: 'Lower back down with control.',
      approvedAsset: _calfRaisesV2Asset('04_LOWER'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'calf_raises_v2_05',
      order: 5,
      label: 'FLOOR RETURN',
      instruction: 'Return your heels to the floor.',
      approvedAsset: _calfRaisesV2Asset('05_FLOOR_RETURN'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.55,
    ),
    PoseDefinition(
      poseId: 'calf_raises_v2_06',
      order: 6,
      label: 'RESET',
      instruction: 'Reset to the starting position.',
      approvedAsset: _calfRaisesV2Asset('06_RESET'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.55,
    ),
  ],
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.landscape,
  visualAspectRatio: 277 / 265, // real Calf Raises V2 frames
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: 'Next: Calf Raises.',
    benefit: 'Calf raises strengthen your calves and improve ankle stability.',
    setupInstruction: 'Stand tall with your feet hip-width apart.',
    quarterCue: 'Rise onto your toes with control.',
    formCues: [
      'Keep your core engaged and move with control.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Nice work.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/wall_push_ups/female/v2/EX019_F_0N_*.png`.
/// Same provenance model as Calf Raises (EX020) and Russian Twist (EX015):
/// placed directly on disk, no Figma node reference exists for this set —
/// do not invent one. Human visual approval completed prior to this
/// implementation; uniform 277×265 canvas confirmed on all six frames.
///
/// This app's `EX019` is Wall Push-Up — unrelated to Figma's own internal
/// "EX-019" library numbering for the Dead Bug design (see the note above
/// on `_deadBug`, which remains `EX012` in this app). Do not confuse them.
///
/// Loop order 01->02->03->04->05->06->(01...), a plain forward wrap, per
/// the approved sequence — [LoopMode.timedCycle] already produces this,
/// same mechanism as every other completed exercise.
String _wallPushUpsV2Asset(String file) =>
    'assets/glow_up/exercises/wall_push_ups/female/v2/EX019_F_$file.png';

final _wallPushUps = ExerciseDefinition(
  id: 'EX019',
  displayName: 'Wall Push-Ups',
  category: 'Strength',
  playbackType: 'REPS',
  bodyAreas: const ['Chest', 'Shoulders', 'Arms'],
  benefitShort:
      'Wall Push-Ups build upper-body strength with a joint-friendly, beginner-safe angle.',
  durationSeconds: 40,
  reps: 12,
  poses: [
    PoseDefinition(
      poseId: 'wall_push_ups_v2_01',
      order: 1,
      label: 'START',
      instruction:
          'Place your palms on the wall and keep your body in a straight line.',
      approvedAsset: _wallPushUpsV2Asset('01_START'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.55,
    ),
    PoseDefinition(
      poseId: 'wall_push_ups_v2_02',
      order: 2,
      label: 'LOWER',
      instruction: 'Bend your elbows and bring your chest toward the wall.',
      approvedAsset: _wallPushUpsV2Asset('02_LOWER'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'wall_push_ups_v2_03',
      order: 3,
      label: 'BOTTOM HOLD',
      instruction: 'Hold with your chest close to the wall.',
      approvedAsset: _wallPushUpsV2Asset('03_BOTTOM_HOLD'),
      purpose: PosePurpose.active,
      phaseSeconds: 0.75,
    ),
    PoseDefinition(
      poseId: 'wall_push_ups_v2_04',
      order: 4,
      label: 'PUSH',
      instruction: 'Press through your palms and push away from the wall.',
      approvedAsset: _wallPushUpsV2Asset('04_PUSH'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'wall_push_ups_v2_05',
      order: 5,
      label: 'RETURN',
      instruction: 'Return to the starting position with control.',
      approvedAsset: _wallPushUpsV2Asset('05_RETURN'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.55,
    ),
    PoseDefinition(
      poseId: 'wall_push_ups_v2_06',
      order: 6,
      label: 'RESET',
      instruction: 'Reset to the starting position.',
      approvedAsset: _wallPushUpsV2Asset('06_RESET'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.55,
    ),
  ],
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.landscape,
  visualAspectRatio: 277 / 265, // real Wall Push-Ups V2 frames
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: 'Next: Wall Push-Ups.',
    benefit:
        'Wall Push-Ups build upper-body strength with a joint-friendly, beginner-safe angle.',
    setupInstruction:
        'Place your palms on the wall and keep your body in a straight line.',
    quarterCue: 'Bend your elbows and bring your chest toward the wall.',
    formCues: [
      'Press through your palms and return to the starting position.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Nice work.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/tricep_dips/female/v2/EX021_F_0N_*.png`. Same
/// provenance model as Wall Push-Ups (EX019) and Calf Raises (EX020):
/// placed directly on disk, no Figma node reference exists for this set —
/// do not invent one. Human visual approval completed prior to this
/// implementation; uniform 277×265 canvas confirmed on all six frames.
///
/// Loop order 01->02->03->04->05->06->(01...), a plain forward wrap, per
/// the approved sequence — [LoopMode.timedCycle] already produces this,
/// same mechanism as every other completed exercise.
String _tricepDipsV2Asset(String file) =>
    'assets/glow_up/exercises/tricep_dips/female/v2/EX021_F_$file.png';

final _tricepDips = ExerciseDefinition(
  id: 'EX021',
  displayName: 'Tricep Dips',
  category: 'Strength',
  playbackType: 'REPS',
  bodyAreas: const ['Arms', 'Shoulders'],
  benefitShort: 'Tricep dips strengthen your triceps, shoulders, and chest.',
  durationSeconds: 40,
  reps: 12,
  poses: [
    PoseDefinition(
      poseId: 'tricep_dips_v2_01',
      order: 1,
      label: 'START',
      instruction:
          'Place your hands securely on the bench and keep your chest lifted.',
      approvedAsset: _tricepDipsV2Asset('01_START'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.55,
    ),
    PoseDefinition(
      poseId: 'tricep_dips_v2_02',
      order: 2,
      label: 'LOWER',
      instruction: 'Bend your elbows and lower with control.',
      approvedAsset: _tricepDipsV2Asset('02_LOWER'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'tricep_dips_v2_03',
      order: 3,
      label: 'BOTTOM HOLD',
      instruction: 'Hold at the bottom with your elbows bent.',
      approvedAsset: _tricepDipsV2Asset('03_BOTTOM_HOLD'),
      purpose: PosePurpose.active,
      phaseSeconds: 0.75,
    ),
    PoseDefinition(
      poseId: 'tricep_dips_v2_04',
      order: 4,
      label: 'PRESS UP',
      instruction: 'Press through your palms and extend your arms.',
      approvedAsset: _tricepDipsV2Asset('04_PRESS_UP'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'tricep_dips_v2_05',
      order: 5,
      label: 'RETURN',
      instruction: 'Return to the starting position with control.',
      approvedAsset: _tricepDipsV2Asset('05_RETURN'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.55,
    ),
    PoseDefinition(
      poseId: 'tricep_dips_v2_06',
      order: 6,
      label: 'RESET',
      instruction: 'Reset to the starting position.',
      approvedAsset: _tricepDipsV2Asset('06_RESET'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.55,
    ),
  ],
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.landscape,
  visualAspectRatio: 277 / 265, // real Tricep Dips V2 frames
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: 'Next: Tricep Dips.',
    benefit: 'Tricep dips strengthen your triceps, shoulders, and chest.',
    setupInstruction:
        'Place your hands securely on the bench and keep your chest lifted.',
    quarterCue: 'Bend your elbows and lower with control.',
    formCues: [
      'Press through your palms and extend your arms.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Nice work.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/donkey_kicks/female/v2/EX022_F_0N_*.png`.
/// Same provenance model as Tricep Dips (EX021), Wall Push-Ups (EX019),
/// and Calf Raises (EX020): placed directly on disk, no Figma node
/// reference exists for this set — do not invent one. Human visual
/// approval completed prior to this implementation; uniform 277×265
/// canvas confirmed on all six frames.
///
/// The legacy `lib/workout` catalog entry for EX022 marks
/// `hasSwitchSide: true`/`SIDE_SEQUENCE` (anticipating a future bilateral
/// left/right asset set), but only a single six-frame demonstration set
/// was approved for production here — same single-loop pattern already
/// used by every other completed Strength exercise. If a bilateral set is
/// approved later, this can be upgraded the same way Lunges uses
/// `bilateralFrames`; do not fabricate a mirrored second side now.
///
/// Loop order 01->02->03->04->05->06->(01...), a plain forward wrap, per
/// the approved sequence — [LoopMode.timedCycle] already produces this,
/// same mechanism as every other completed exercise.
String _donkeyKicksV2Asset(String file) =>
    'assets/glow_up/exercises/donkey_kicks/female/v2/EX022_F_$file.png';

final _donkeyKicks = ExerciseDefinition(
  id: 'EX022',
  displayName: 'Donkey Kicks',
  category: 'Strength',
  playbackType: 'REPS',
  bodyAreas: const ['Glutes', 'Core'],
  benefitShort: 'Donkey kicks strengthen and shape your glutes.',
  durationSeconds: 40,
  reps: 12,
  poses: [
    PoseDefinition(
      poseId: 'donkey_kicks_v2_01',
      order: 1,
      label: 'START',
      instruction:
          'Start on all fours with your hands under your shoulders and knees under your hips.',
      approvedAsset: _donkeyKicksV2Asset('01_START'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.55,
    ),
    PoseDefinition(
      poseId: 'donkey_kicks_v2_02',
      order: 2,
      label: 'LIFTING',
      instruction: 'Keep your knee bent and drive your heel upward.',
      approvedAsset: _donkeyKicksV2Asset('02_LIFTING'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'donkey_kicks_v2_03',
      order: 3,
      label: 'TOP HOLD',
      instruction: 'Squeeze your glute at the top.',
      approvedAsset: _donkeyKicksV2Asset('03_TOP_HOLD'),
      purpose: PosePurpose.active,
      phaseSeconds: 0.75,
    ),
    PoseDefinition(
      poseId: 'donkey_kicks_v2_04',
      order: 4,
      label: 'LOWERING',
      instruction: 'Lower with control without shifting your torso.',
      approvedAsset: _donkeyKicksV2Asset('04_LOWERING'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'donkey_kicks_v2_05',
      order: 5,
      label: 'ALMOST START',
      instruction: 'Bring your knee almost back to the starting position.',
      approvedAsset: _donkeyKicksV2Asset('05_ALMOST_START'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.55,
    ),
    PoseDefinition(
      poseId: 'donkey_kicks_v2_06',
      order: 6,
      label: 'RESET',
      instruction: 'Return to your starting position.',
      approvedAsset: _donkeyKicksV2Asset('06_RESET'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.55,
    ),
  ],
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.landscape,
  visualAspectRatio: 277 / 265, // real Donkey Kicks V2 frames
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: 'Next: Donkey Kicks.',
    benefit: 'Donkey kicks strengthen and shape your glutes.',
    setupInstruction:
        'Start on all fours with your hands under your shoulders and knees under your hips.',
    quarterCue: 'Keep your knee bent and drive your heel upward.',
    formCues: [
      'Squeeze your glute at the top and lower with control.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Nice work.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/shoulder_taps/female/v2/EX023_F_0N_*.png`.
/// Same provenance model as Donkey Kicks (EX022), Tricep Dips (EX021),
/// Wall Push-Ups (EX019), and Calf Raises (EX020): placed directly on
/// disk, no Figma node reference exists for this set — do not invent one.
/// Human visual approval completed prior to this implementation; uniform
/// 277×265 canvas confirmed on all six frames.
///
/// Loop order 01->02->03->04->05->06->(01...), a plain forward wrap, per
/// the approved sequence — [LoopMode.timedCycle] already produces this,
/// same mechanism as every other completed exercise.
String _shoulderTapsV2Asset(String file) =>
    'assets/glow_up/exercises/shoulder_taps/female/v2/EX023_F_$file.png';

final _shoulderTaps = ExerciseDefinition(
  id: 'EX023',
  displayName: 'Shoulder Taps',
  category: 'Strength',
  playbackType: 'REPS',
  bodyAreas: const ['Core', 'Shoulders'],
  benefitShort: 'Shoulder taps build core stability and shoulder control.',
  durationSeconds: 35,
  reps: 16,
  poses: [
    PoseDefinition(
      poseId: 'shoulder_taps_v2_01',
      order: 1,
      label: 'START',
      instruction:
          'Start in a strong high plank with your hands under your shoulders.',
      approvedAsset: _shoulderTapsV2Asset('01_START'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.55,
    ),
    PoseDefinition(
      poseId: 'shoulder_taps_v2_02',
      order: 2,
      label: 'TAP RIGHT',
      instruction: 'Lift your right hand and tap the opposite shoulder.',
      approvedAsset: _shoulderTapsV2Asset('02_TAP_RIGHT'),
      purpose: PosePurpose.active,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'shoulder_taps_v2_03',
      order: 3,
      label: 'RETURN RIGHT',
      instruction: 'Place your hand back down and keep your hips steady.',
      approvedAsset: _shoulderTapsV2Asset('03_RETURN_RIGHT'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.6,
    ),
    PoseDefinition(
      poseId: 'shoulder_taps_v2_04',
      order: 4,
      label: 'TAP LEFT',
      instruction: 'Lift your left hand and tap the opposite shoulder.',
      approvedAsset: _shoulderTapsV2Asset('04_TAP_LEFT'),
      purpose: PosePurpose.active,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'shoulder_taps_v2_05',
      order: 5,
      label: 'RETURN LEFT',
      instruction: 'Place your hand back down and keep your hips steady.',
      approvedAsset: _shoulderTapsV2Asset('05_RETURN_LEFT'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.6,
    ),
    PoseDefinition(
      poseId: 'shoulder_taps_v2_06',
      order: 6,
      label: 'RESET',
      instruction: 'Return to a strong plank position.',
      approvedAsset: _shoulderTapsV2Asset('06_RESET'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.55,
    ),
  ],
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.landscape,
  visualAspectRatio: 277 / 265, // real Shoulder Taps V2 frames
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: 'Next: Shoulder Taps.',
    benefit: 'Shoulder taps build core stability and shoulder control.',
    setupInstruction:
        'Start in a strong high plank with your hands under your shoulders.',
    quarterCue: 'Lift one hand at a time and tap the opposite shoulder.',
    formCues: [
      'Keep your hips steady and avoid rocking side to side.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Nice work.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/superman/female/v2/EX024_F_0N_*.png`. Same
/// provenance model as Shoulder Taps (EX023), Donkey Kicks (EX022),
/// Tricep Dips (EX021), Wall Push-Ups (EX019), and Calf Raises (EX020):
/// placed directly on disk, no Figma node reference exists for this set —
/// do not invent one. Human visual approval completed prior to this
/// implementation; uniform 277×265 canvas confirmed on all six frames.
///
/// [ExerciseDefinition] has no dedicated difficulty/equipment/safety/
/// modification fields — that data is folded into [bodyAreas] (target
/// muscles), the per-pose `instruction` text, and `voiceScript.formCues`
/// (safety cue + a lower-impact modification cue), the same way every
/// other exercise in this registry represents it; no new field was added.
///
/// Loop order 01->02->03->04->05->06->(01...), a plain forward wrap — the
/// six frames show a repeating lift/hold/lower cycle (not a single static
/// hold), so this uses the same REPS + [LoopMode.timedCycle] pattern as
/// Donkey Kicks/Glute Bridge rather than the legacy catalog's `_hold`
/// playbackType (that field is independent Tier-2 metadata, same
/// distinction already established for Donkey Kicks' `hasSwitchSide`).
String _supermanV2Asset(String file) =>
    'assets/glow_up/exercises/superman/female/v2/EX024_F_$file.png';

final _superman = ExerciseDefinition(
  id: 'EX024',
  displayName: 'Superman',
  category: 'Strength',
  playbackType: 'REPS',
  bodyAreas: const ['Lower Back', 'Glutes', 'Core'],
  benefitShort: 'Superman strengthens your lower back, glutes, and core.',
  durationSeconds: 25,
  reps: 12,
  poses: [
    PoseDefinition(
      poseId: 'superman_v2_01',
      order: 1,
      label: 'START',
      instruction:
          'Lie face down with your arms extended overhead and legs straight.',
      approvedAsset: _supermanV2Asset('01_START'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.55,
    ),
    PoseDefinition(
      poseId: 'superman_v2_02',
      order: 2,
      label: 'LIFTING',
      instruction:
          'Lift your chest and legs off the floor together with control.',
      approvedAsset: _supermanV2Asset('02_LIFTING'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'superman_v2_03',
      order: 3,
      label: 'TOP HOLD',
      instruction: 'Hold at the top and squeeze your lower back and glutes.',
      approvedAsset: _supermanV2Asset('03_TOP_HOLD'),
      purpose: PosePurpose.active,
      phaseSeconds: 0.75,
    ),
    PoseDefinition(
      poseId: 'superman_v2_04',
      order: 4,
      label: 'LOWERING',
      instruction: 'Lower your chest and legs back down with control.',
      approvedAsset: _supermanV2Asset('04_LOWERING'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'superman_v2_05',
      order: 5,
      label: 'ALMOST START',
      instruction:
          'Bring your chest and legs almost back to the starting position.',
      approvedAsset: _supermanV2Asset('05_ALMOST_START'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.55,
    ),
    PoseDefinition(
      poseId: 'superman_v2_06',
      order: 6,
      label: 'RESET',
      instruction: 'Reset to the starting position.',
      approvedAsset: _supermanV2Asset('06_RESET'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.55,
    ),
  ],
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.landscape,
  visualAspectRatio: 277 / 265, // real Superman V2 frames
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: 'Next: Superman.',
    benefit: 'Superman strengthens your lower back, glutes, and core.',
    setupInstruction:
        'Lie face down with your arms extended overhead and legs straight.',
    quarterCue:
        'Lift your chest and legs together, keeping your neck relaxed and in line with your spine.',
    formCues: [
      'Move within a comfortable range — never force the lift or arch your neck back.',
      'Modification: if lifting both arms and legs feels like too much, lift just your legs, or just your upper body, and build up from there.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Nice work.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/hamstring_stretch/female/v2/EX025_F_0N_*.png`.
/// Same provenance model as EX019-EX024: placed directly on disk, no
/// Figma node reference exists for this set — do not invent one. Human
/// visual approval completed prior to this implementation; uniform
/// 277×265 canvas confirmed on all six frames.
///
/// First Flexibility-category exercise implemented in this registry.
/// `Evening Stretch` (its home workout in `workout_catalog.dart`) lists
/// seven exercises (EX025-EX031); Flexibility now resolves through the
/// same per-exercise gate as Strength (`_perExerciseRoutineFor` in
/// `app_router.dart`, generalized from the Strength-only
/// `_strengthRoutineFor`), so EX025 opens its own real RoutinePlayer
/// definition immediately, independent of EX026-EX031's pending status —
/// no all-or-nothing per-workout gate blocks it.
///
/// Loop order 01->02->03->04->05->06->(01...), a plain forward wrap, per
/// the approved sequence — [LoopMode.timedCycle] already produces this,
/// same mechanism as every other completed exercise.
String _hamstringStretchV2Asset(String file) =>
    'assets/glow_up/exercises/hamstring_stretch/female/v2/EX025_F_$file.png';

final _hamstringStretch = ExerciseDefinition(
  id: 'EX025',
  displayName: 'Hamstring Stretch',
  category: 'Flexibility',
  playbackType: 'REPS',
  bodyAreas: const ['Hamstrings', 'Lower Back'],
  benefitShort: 'Hamstring Stretch lengthens your hamstrings and lower back.',
  durationSeconds: 30,
  reps: 8,
  poses: [
    PoseDefinition(
      poseId: 'hamstring_stretch_v2_01',
      order: 1,
      label: 'START',
      instruction: 'Sit tall with one leg extended and the other bent in.',
      approvedAsset: _hamstringStretchV2Asset('01_START'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.6,
    ),
    PoseDefinition(
      poseId: 'hamstring_stretch_v2_02',
      order: 2,
      label: 'REACH',
      instruction: 'Hinge forward from your hips and reach toward your foot.',
      approvedAsset: _hamstringStretchV2Asset('02_REACH'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.75,
    ),
    PoseDefinition(
      poseId: 'hamstring_stretch_v2_03',
      order: 3,
      label: 'DEEPEN',
      instruction: 'Deepen the stretch slowly, keeping your back long.',
      approvedAsset: _hamstringStretchV2Asset('03_DEEPEN'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.8,
    ),
    PoseDefinition(
      poseId: 'hamstring_stretch_v2_04',
      order: 4,
      label: 'HOLD',
      instruction: 'Hold here and breathe, never bouncing into the stretch.',
      approvedAsset: _hamstringStretchV2Asset('04_HOLD'),
      purpose: PosePurpose.active,
      phaseSeconds: 1.1,
    ),
    PoseDefinition(
      poseId: 'hamstring_stretch_v2_05',
      order: 5,
      label: 'RELEASE',
      instruction: 'Release the stretch and rise back up with control.',
      approvedAsset: _hamstringStretchV2Asset('05_RELEASE'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'hamstring_stretch_v2_06',
      order: 6,
      label: 'RESET',
      instruction: 'Reset to the starting position.',
      approvedAsset: _hamstringStretchV2Asset('06_RESET'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.6,
    ),
  ],
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.landscape,
  visualAspectRatio: 277 / 265, // real Hamstring Stretch V2 frames
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: 'Next: Hamstring Stretch.',
    benefit: 'Hamstring Stretch lengthens your hamstrings and lower back.',
    setupInstruction: 'Sit tall with one leg extended and the other bent in.',
    quarterCue: 'Hinge from your hips, not your lower back.',
    formCues: [
      'Ease into the stretch — never force it or bounce.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Nice work.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/quad_stretch/female/v2/EX026_F_0N_*.png`.
/// Same provenance model as EX019-EX025: placed directly on disk, no
/// Figma node reference exists for this set — do not invent one. Human
/// visual approval completed prior to this implementation; uniform
/// 768×768 canvas confirmed on all six frames (its own real square
/// ratio — distinct from Hamstring Stretch's 277×265 landscape, never
/// bucketed/shared across exercises).
///
/// The legacy `lib/workout` catalog entry for EX026 marks
/// `hasSwitchSide: true`/`SIDE_SEQUENCE` (anticipating a future bilateral
/// left/right asset set), but only a single six-frame demonstration set
/// was approved for production here — same single-loop precedent already
/// established for Donkey Kicks (EX022). If a bilateral set is approved
/// later, this can be upgraded the same way Lunges uses
/// `bilateralFrames`; do not fabricate a mirrored second side now.
///
/// Loop order 01->02->03->04->05->06->(01...), a plain forward wrap, per
/// the approved sequence — [LoopMode.timedCycle] already produces this,
/// same mechanism as every other completed exercise.
String _quadStretchV2Asset(String file) =>
    'assets/glow_up/exercises/quad_stretch/female/v2/EX026_F_$file.png';

final _quadStretch = ExerciseDefinition(
  id: 'EX026',
  displayName: 'Quad Stretch',
  category: 'Flexibility',
  playbackType: 'REPS',
  bodyAreas: const ['Quads', 'Hip Flexors'],
  benefitShort: 'Quad Stretch lengthens your quads and hip flexors.',
  durationSeconds: 40,
  reps: 8,
  poses: [
    PoseDefinition(
      poseId: 'quad_stretch_v2_01',
      order: 1,
      label: 'START',
      instruction: 'Stand tall with your feet hip-width apart.',
      approvedAsset: _quadStretchV2Asset('01_START'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.6,
    ),
    PoseDefinition(
      poseId: 'quad_stretch_v2_02',
      order: 2,
      label: 'BEND KNEE',
      instruction: 'Bend one knee and reach back for your foot.',
      approvedAsset: _quadStretchV2Asset('02_BEND_KNEE'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.75,
    ),
    PoseDefinition(
      poseId: 'quad_stretch_v2_03',
      order: 3,
      label: 'GRAB FOOT',
      instruction: 'Grab your foot and gently pull it toward your glutes.',
      approvedAsset: _quadStretchV2Asset('03_GRAB_FOOT'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.8,
    ),
    PoseDefinition(
      poseId: 'quad_stretch_v2_04',
      order: 4,
      label: 'HOLD',
      instruction: 'Hold here and breathe, keeping your knees close together.',
      approvedAsset: _quadStretchV2Asset('04_HOLD'),
      purpose: PosePurpose.active,
      phaseSeconds: 1.1,
    ),
    PoseDefinition(
      poseId: 'quad_stretch_v2_05',
      order: 5,
      label: 'RELEASE',
      instruction: 'Release your foot and lower your leg with control.',
      approvedAsset: _quadStretchV2Asset('05_RELEASE'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'quad_stretch_v2_06',
      order: 6,
      label: 'RESET',
      instruction: 'Reset to the starting position.',
      approvedAsset: _quadStretchV2Asset('06_RESET'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.6,
    ),
  ],
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.square,
  visualAspectRatio: 1.0, // real Quad Stretch V2 frames, 768x768
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: 'Next: Quad Stretch.',
    benefit: 'Quad Stretch lengthens your quads and hip flexors.',
    setupInstruction: 'Stand tall with your feet hip-width apart.',
    quarterCue: 'Keep your knees close together as you pull your heel in.',
    formCues: [
      'Hold onto something nearby if you need help balancing.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Nice work.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/butterfly_stretch/female/v2/EX027_F_0N_*.png`.
/// Same provenance model as EX019-EX026: placed directly on disk, no
/// Figma node reference exists for this set — do not invent one. Human
/// visual approval completed prior to this implementation; uniform
/// 277×265 canvas confirmed on all six frames.
///
/// The legacy `lib/workout` catalog entry for EX027 marks
/// `playbackType: _hold, hasRepeat: false` (a true single-hold exercise
/// in that Tier-2 metadata), but the six approved frames form a complete
/// repeating cycle (tall seated start -> lean forward -> deepen -> hold
/// -> release -> reset), and this Tier-1 definition is required to loop
/// continuously (01->02->03->04->05->06->01->repeat) rather than play
/// once and freeze — so this uses the same `REPS` + [LoopMode.timedCycle]
/// pattern as Hamstring Stretch/Quad Stretch, not Plank's
/// `LoopMode.holdAfterSetup` one-pass-then-freeze pattern. The longer
/// `phaseSeconds` on the HOLD frame (order 4) still gives it a
/// noticeably longer on-screen dwell than the transitional frames within
/// that continuous loop.
///
/// Loop order 01->02->03->04->05->06->(01...), a plain forward wrap, per
/// the approved sequence — [LoopMode.timedCycle] already produces this,
/// same mechanism as every other completed exercise.
String _butterflyStretchV2Asset(String file) =>
    'assets/glow_up/exercises/butterfly_stretch/female/v2/EX027_F_$file.png';

final _butterflyStretch = ExerciseDefinition(
  id: 'EX027',
  displayName: 'Butterfly Stretch',
  category: 'Flexibility',
  playbackType: 'REPS',
  bodyAreas: const ['Hips', 'Inner Thighs'],
  benefitShort: 'Butterfly Stretch opens your hips and inner thighs.',
  durationSeconds: 30,
  reps: 6,
  poses: [
    PoseDefinition(
      poseId: 'butterfly_stretch_v2_01',
      order: 1,
      label: 'START',
      instruction:
          'Sit tall with the soles of your feet together and knees open.',
      approvedAsset: _butterflyStretchV2Asset('01_START'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.6,
    ),
    PoseDefinition(
      poseId: 'butterfly_stretch_v2_02',
      order: 2,
      label: 'LEAN FORWARD',
      instruction: 'Hinge gently forward from your hips.',
      approvedAsset: _butterflyStretchV2Asset('02_LEAN_FORWARD'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.75,
    ),
    PoseDefinition(
      poseId: 'butterfly_stretch_v2_03',
      order: 3,
      label: 'DEEPEN',
      instruction: 'Deepen the stretch slowly, keeping your back long.',
      approvedAsset: _butterflyStretchV2Asset('03_DEEPEN'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.8,
    ),
    PoseDefinition(
      poseId: 'butterfly_stretch_v2_04',
      order: 4,
      label: 'HOLD',
      instruction: 'Hold here and breathe, never bouncing into the stretch.',
      approvedAsset: _butterflyStretchV2Asset('04_HOLD'),
      purpose: PosePurpose.active,
      phaseSeconds: 1.1,
    ),
    PoseDefinition(
      poseId: 'butterfly_stretch_v2_05',
      order: 5,
      label: 'RELEASE',
      instruction: 'Release the stretch and rise back up with control.',
      approvedAsset: _butterflyStretchV2Asset('05_RELEASE'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'butterfly_stretch_v2_06',
      order: 6,
      label: 'RESET',
      instruction: 'Reset to the starting position.',
      approvedAsset: _butterflyStretchV2Asset('06_RESET'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.6,
    ),
  ],
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.landscape,
  visualAspectRatio: 277 / 265, // real Butterfly Stretch V2 frames
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: 'Next: Butterfly Stretch.',
    benefit: 'Butterfly Stretch opens your hips and inner thighs.',
    setupInstruction:
        'Sit tall with the soles of your feet together and knees open.',
    quarterCue: 'Hinge from your hips, keeping your back long.',
    formCues: [
      'Ease into the stretch and breathe — never bounce.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Nice work.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/childs_pose/female/v2/EX028_F_0N_*.png`.
/// Same provenance model as EX019-EX027: placed directly on disk, no
/// Figma node reference exists for this set — do not invent one. Human
/// visual approval completed prior to this implementation; uniform
/// 277×265 canvas confirmed on all six frames.
///
/// Same `_hold`-metadata situation as Butterfly Stretch (EX027): the
/// legacy `lib/workout` catalog entry marks `playbackType: _hold,
/// hasRepeat: false`, but the six approved frames form a complete
/// repeating cycle (kneeling start -> reach forward -> lower chest ->
/// hold -> walk back -> reset), so this uses the same `REPS` +
/// [LoopMode.timedCycle] continuous-loop pattern, not Plank's
/// `LoopMode.holdAfterSetup` one-pass-then-freeze pattern — same
/// reasoning already documented on Butterfly Stretch.
///
/// Loop order 01->02->03->04->05->06->(01...), a plain forward wrap, per
/// the approved sequence — [LoopMode.timedCycle] already produces this,
/// same mechanism as every other completed exercise.
String _childsPoseV2Asset(String file) =>
    'assets/glow_up/exercises/childs_pose/female/v2/EX028_F_$file.png';

final _childsPose = ExerciseDefinition(
  id: 'EX028',
  displayName: "Child's Pose",
  category: 'Flexibility',
  playbackType: 'REPS',
  bodyAreas: const ['Lower Back', 'Spine', 'Shoulders'],
  benefitShort: "Child's Pose relaxes your lower back, spine, and shoulders.",
  durationSeconds: 30,
  reps: 6,
  poses: [
    PoseDefinition(
      poseId: 'childs_pose_v2_01',
      order: 1,
      label: 'START',
      instruction: 'Sit your hips back toward your heels.',
      approvedAsset: _childsPoseV2Asset('01_START'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.6,
    ),
    PoseDefinition(
      poseId: 'childs_pose_v2_02',
      order: 2,
      label: 'REACH FORWARD',
      instruction: 'Reach your arms forward along the mat.',
      approvedAsset: _childsPoseV2Asset('02_REACH_FORWARD'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.75,
    ),
    PoseDefinition(
      poseId: 'childs_pose_v2_03',
      order: 3,
      label: 'LOWER CHEST',
      instruction: 'Gently lower your chest toward the mat.',
      approvedAsset: _childsPoseV2Asset('03_LOWER_CHEST'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.8,
    ),
    PoseDefinition(
      poseId: 'childs_pose_v2_04',
      order: 4,
      label: 'HOLD',
      instruction: 'Relax here and breathe slowly — never force the stretch.',
      approvedAsset: _childsPoseV2Asset('04_HOLD'),
      purpose: PosePurpose.active,
      phaseSeconds: 1.1,
    ),
    PoseDefinition(
      poseId: 'childs_pose_v2_05',
      order: 5,
      label: 'WALK BACK',
      instruction: 'Walk your hands back with control.',
      approvedAsset: _childsPoseV2Asset('05_WALK_BACK'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'childs_pose_v2_06',
      order: 6,
      label: 'RESET',
      instruction: 'Reset to the starting position.',
      approvedAsset: _childsPoseV2Asset('06_RESET'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.6,
    ),
  ],
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.landscape,
  visualAspectRatio: 277 / 265, // real Child's Pose V2 frames
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: "Next: Child's Pose.",
    benefit: "Child's Pose relaxes your lower back, spine, and shoulders.",
    setupInstruction: 'Sit your hips back toward your heels.',
    quarterCue: 'Reach forward and let your chest melt toward the mat.',
    formCues: [
      'Breathe slowly and relax — never force the stretch.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Nice work.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/cobra_stretch/female/v2/EX029_F_0N_*.png`.
/// Same provenance model as EX019-EX028: placed directly on disk, no
/// Figma node reference exists for this set — do not invent one. Human
/// visual approval completed prior to this implementation; uniform
/// 277×265 canvas confirmed on all six frames.
///
/// Same `_hold`-metadata situation as Butterfly Stretch (EX027) and
/// Child's Pose (EX028): the legacy `lib/workout` catalog entry marks
/// `playbackType: _hold`, but the six approved frames form a complete
/// repeating cycle (flat start -> press hands -> lift chest -> hold ->
/// lower down -> reset), so this uses the same `REPS` +
/// [LoopMode.timedCycle] continuous-loop pattern, not Plank's
/// `LoopMode.holdAfterSetup` one-pass-then-freeze pattern — same
/// reasoning already documented on Butterfly Stretch and Child's Pose.
///
/// Loop order 01->02->03->04->05->06->(01...), a plain forward wrap, per
/// the approved sequence — [LoopMode.timedCycle] already produces this,
/// same mechanism as every other completed exercise.
String _cobraStretchV2Asset(String file) =>
    'assets/glow_up/exercises/cobra_stretch/female/v2/EX029_F_$file.png';

final _cobraStretch = ExerciseDefinition(
  id: 'EX029',
  displayName: 'Cobra Stretch',
  category: 'Flexibility',
  playbackType: 'REPS',
  bodyAreas: const ['Spine', 'Chest', 'Shoulders'],
  benefitShort: 'Cobra Stretch opens your chest and mobilizes your spine.',
  durationSeconds: 25,
  reps: 6,
  poses: [
    PoseDefinition(
      poseId: 'cobra_stretch_v2_01',
      order: 1,
      label: 'START',
      instruction: 'Lie face down with your hands under your shoulders.',
      approvedAsset: _cobraStretchV2Asset('01_START'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.6,
    ),
    PoseDefinition(
      poseId: 'cobra_stretch_v2_02',
      order: 2,
      label: 'PRESS HANDS',
      instruction: 'Press through your palms into the mat.',
      approvedAsset: _cobraStretchV2Asset('02_PRESS_HANDS'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.75,
    ),
    PoseDefinition(
      poseId: 'cobra_stretch_v2_03',
      order: 3,
      label: 'LIFT CHEST',
      instruction: 'Lift your chest with control, keeping your hips down.',
      approvedAsset: _cobraStretchV2Asset('03_LIFT_CHEST'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.8,
    ),
    PoseDefinition(
      poseId: 'cobra_stretch_v2_04',
      order: 4,
      label: 'HOLD',
      instruction: 'Hold here and breathe, never forcing the stretch.',
      approvedAsset: _cobraStretchV2Asset('04_HOLD'),
      purpose: PosePurpose.active,
      phaseSeconds: 1.1,
    ),
    PoseDefinition(
      poseId: 'cobra_stretch_v2_05',
      order: 5,
      label: 'LOWER DOWN',
      instruction: 'Lower back down with control.',
      approvedAsset: _cobraStretchV2Asset('05_LOWER_DOWN'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'cobra_stretch_v2_06',
      order: 6,
      label: 'RESET',
      instruction: 'Reset to the starting position.',
      approvedAsset: _cobraStretchV2Asset('06_RESET'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.6,
    ),
  ],
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.landscape,
  visualAspectRatio: 277 / 265, // real Cobra Stretch V2 frames
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: 'Next: Cobra Stretch.',
    benefit: 'Cobra Stretch opens your chest and mobilizes your spine.',
    setupInstruction: 'Lie face down with your hands under your shoulders.',
    quarterCue: 'Press through your palms and lift your chest with control.',
    formCues: [
      'Keep your hips down and never force the stretch.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Nice work.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/hip_flexor_stretch/female/v2/EX030_F_0N_*.png`.
/// Same provenance model as EX019-EX029: placed directly on disk, no
/// Figma node reference exists for this set — do not invent one. Human
/// visual approval completed prior to this implementation; uniform
/// 277×265 canvas confirmed on all six frames.
///
/// The legacy `lib/workout` catalog entry for EX030 marks
/// `hasSwitchSide: true`/`SIDE_SEQUENCE` (anticipating a future bilateral
/// left/right asset set), but only a single six-frame demonstration set
/// was approved for production here — same single-loop precedent already
/// established for Donkey Kicks (EX022) and Quad Stretch (EX026). If a
/// bilateral set is approved later, this can be upgraded the same way
/// Lunges uses `bilateralFrames`; do not fabricate a mirrored second side
/// now.
///
/// Loop order 01->02->03->04->05->06->(01...), a plain forward wrap, per
/// the approved sequence — [LoopMode.timedCycle] already produces this,
/// same mechanism as every other completed exercise.
String _hipFlexorStretchV2Asset(String file) =>
    'assets/glow_up/exercises/hip_flexor_stretch/female/v2/EX030_F_$file.png';

final _hipFlexorStretch = ExerciseDefinition(
  id: 'EX030',
  displayName: 'Hip Flexor Stretch',
  category: 'Flexibility',
  playbackType: 'REPS',
  bodyAreas: const ['Hip Flexors', 'Quads'],
  benefitShort: 'Hip Flexor Stretch opens your hips and quads.',
  durationSeconds: 40,
  reps: 6,
  poses: [
    PoseDefinition(
      poseId: 'hip_flexor_stretch_v2_01',
      order: 1,
      label: 'START',
      instruction: 'Sink into a low lunge with your back knee down.',
      approvedAsset: _hipFlexorStretchV2Asset('01_START'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.6,
    ),
    PoseDefinition(
      poseId: 'hip_flexor_stretch_v2_02',
      order: 2,
      label: 'SET POSITION',
      instruction: 'Square your hips forward and settle into the lunge.',
      approvedAsset: _hipFlexorStretchV2Asset('02_SET_POSITION'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'hip_flexor_stretch_v2_03',
      order: 3,
      label: 'RAISE ARMS',
      instruction: 'Raise your arms overhead to deepen the stretch.',
      approvedAsset: _hipFlexorStretchV2Asset('03_RAISE_ARMS'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.75,
    ),
    PoseDefinition(
      poseId: 'hip_flexor_stretch_v2_04',
      order: 4,
      label: 'HOLD STRETCH',
      instruction: 'Hold here and breathe, never forcing the stretch.',
      approvedAsset: _hipFlexorStretchV2Asset('04_HOLD_STRETCH'),
      purpose: PosePurpose.active,
      phaseSeconds: 1.1,
    ),
    PoseDefinition(
      poseId: 'hip_flexor_stretch_v2_05',
      order: 5,
      label: 'LEAN FORWARD',
      instruction: 'Lower your arms and lean gently forward.',
      approvedAsset: _hipFlexorStretchV2Asset('05_LEAN_FORWARD'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'hip_flexor_stretch_v2_06',
      order: 6,
      label: 'RESET',
      instruction: 'Reset to the starting position.',
      approvedAsset: _hipFlexorStretchV2Asset('06_RESET'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.6,
    ),
  ],
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.landscape,
  visualAspectRatio: 277 / 265, // real Hip Flexor Stretch V2 frames
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: 'Next: Hip Flexor Stretch.',
    benefit: 'Hip Flexor Stretch opens your hips and quads.',
    setupInstruction: 'Sink into a low lunge with your back knee down.',
    quarterCue: 'Raise your arms overhead to deepen the stretch.',
    formCues: [
      'Keep your hips squared forward and breathe — never force it.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Nice work.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/cat_cow/female/v2/EX031_F_0N_*.png`. Same
/// provenance model as EX019-EX030: placed directly on disk, no Figma
/// node reference exists for this set — do not invent one. Human visual
/// approval completed prior to this implementation; uniform 277×265
/// canvas confirmed on all six frames.
///
/// The last exercise in Evening Stretch (EX025-EX031) — with this one
/// implemented, every exercise in that workout now has a real Tier 1
/// definition, though that has no special effect here since Flexibility
/// already resolves per-exercise via `_perExerciseRoutineFor`, not the
/// all-or-nothing gate.
///
/// Loop order 01->02->03->04->05->06->(01...), a plain forward wrap, per
/// the approved sequence — [LoopMode.timedCycle] already produces this,
/// same mechanism as every other completed exercise.
String _catCowV2Asset(String file) =>
    'assets/glow_up/exercises/cat_cow/female/v2/EX031_F_$file.png';

final _catCow = ExerciseDefinition(
  id: 'EX031',
  displayName: 'Cat-Cow',
  category: 'Flexibility',
  playbackType: 'REPS',
  bodyAreas: const ['Spine', 'Core'],
  benefitShort: 'Cat-Cow mobilizes your spine and warms up your core.',
  durationSeconds: 40,
  reps: 8,
  poses: [
    PoseDefinition(
      poseId: 'cat_cow_v2_01',
      order: 1,
      label: 'START NEUTRAL',
      instruction: 'Start on all fours in a neutral tabletop position.',
      approvedAsset: _catCowV2Asset('01_START_NEUTRAL'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.6,
    ),
    PoseDefinition(
      poseId: 'cat_cow_v2_02',
      order: 2,
      label: 'COW / ARCH BACK',
      instruction: 'Drop your belly and arch your back.',
      approvedAsset: _catCowV2Asset('02_COW_ARCH_BACK'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'cat_cow_v2_03',
      order: 3,
      label: 'COW / LOOK UP',
      instruction: 'Lift your chest and gaze gently upward.',
      approvedAsset: _catCowV2Asset('03_COW_LOOK_UP'),
      purpose: PosePurpose.active,
      phaseSeconds: 0.85,
    ),
    PoseDefinition(
      poseId: 'cat_cow_v2_04',
      order: 4,
      label: 'CAT / ROUND BACK',
      instruction: 'Round your spine toward the ceiling.',
      approvedAsset: _catCowV2Asset('04_CAT_ROUND_BACK'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'cat_cow_v2_05',
      order: 5,
      label: 'CAT / TUCK CHIN',
      instruction: 'Tuck your chin toward your chest.',
      approvedAsset: _catCowV2Asset('05_CAT_TUCK_CHIN'),
      purpose: PosePurpose.active,
      phaseSeconds: 0.85,
    ),
    PoseDefinition(
      poseId: 'cat_cow_v2_06',
      order: 6,
      label: 'RETURN NEUTRAL',
      instruction: 'Return to a neutral tabletop position.',
      approvedAsset: _catCowV2Asset('06_RETURN_NEUTRAL'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.6,
    ),
  ],
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.landscape,
  visualAspectRatio: 277 / 265, // real Cat-Cow V2 frames
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: 'Next: Cat-Cow.',
    benefit: 'Cat-Cow mobilizes your spine and warms up your core.',
    setupInstruction: 'Start on all fours in a neutral tabletop position.',
    quarterCue: 'Move slowly between arching and rounding your spine.',
    formCues: [
      'Sync your breath with the movement — inhale to arch, exhale to round.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Nice work.',
  ),
);

/// Real, individually-exported (not manually cropped) V1 Mountain Climbers
/// frame — Figma `wZpdIxyGJ3DDPVHtZtwQeC`, node `08_MOUNTAIN_CLIMBERS >
/// MOUNTAIN_CLIMBERS_ANIMATION_ASSETS_V1` (nodes 472:5-472:10). Landscape
/// 600×400 — its own real ratio, kept as an explicit per-exercise value
/// (never bucketed/shared with Plank/Glute Bridge's numerically-identical-
/// but-separately-declared 3:2). The QA board's forward-sequence preview
/// (472:15-472:20, identical content to production) and its separate loop
/// preview (472:23-472:29, a design-time smoothness check that visually
/// repeats frame 01 at both ends) are both design-time-only — production
/// uses only the forward six, looping 01->06->01->repeat.
String _mountainClimbersV1Asset(String file) =>
    'assets/glow_up/exercises/mountain_climbers/female/v1/mountain_climbers_female_$file.png';

/// Reuses id `EX017` — same convention as every other RoutinePlayer
/// exercise, whose ids deliberately mirror the same real-world exercise's
/// id in the separate legacy `lib/workout` catalog (`EX017` = "Mountain
/// Climbers" there too). RoutinePlayer does not import that module; this is
/// a from-scratch definition using only real, individually-verified V1
/// frames. No prior RoutinePlayer Mountain Climbers entry existed, so this
/// is a fresh addition (not a replacement) — kept as its own exercise
/// identity/configuration, never mapped onto Plank/Pushups/Glute
/// Bridge/Jumping Jack/Squat/Lunges/Deep Breathing.
final _mountainClimbers = ExerciseDefinition(
  id: 'EX017',
  displayName: 'Mountain Climbers',
  category: 'Cardio',
  playbackType: 'REPS',
  bodyAreas: const ['Core', 'Full Body'],
  benefitShort:
      'Mountain Climbers work your core while building full-body endurance.',
  durationSeconds: 30,
  poses: [
    PoseDefinition(
      poseId: 'mountain_climbers_v1_01',
      order: 1,
      label: 'START',
      instruction:
          'Start in a strong high plank with your hands under your shoulders.',
      approvedAsset: _mountainClimbersV1Asset('01_start'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.50,
    ),
    PoseDefinition(
      poseId: 'mountain_climbers_v1_02',
      order: 2,
      label: 'RIGHT KNEE IN',
      instruction: 'Drive your right knee toward your chest.',
      approvedAsset: _mountainClimbersV1Asset('02_right_knee_in'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.72,
    ),
    PoseDefinition(
      poseId: 'mountain_climbers_v1_03',
      order: 3,
      label: 'RIGHT RETURN',
      instruction: 'Return your right foot to plank.',
      approvedAsset: _mountainClimbersV1Asset('03_right_return'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.50,
    ),
    PoseDefinition(
      poseId: 'mountain_climbers_v1_04',
      order: 4,
      label: 'LEFT KNEE IN',
      instruction: 'Drive your left knee toward your chest.',
      approvedAsset: _mountainClimbersV1Asset('04_left_knee_in'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.72,
    ),
    PoseDefinition(
      poseId: 'mountain_climbers_v1_05',
      order: 5,
      label: 'LEFT RETURN',
      instruction: 'Return your left foot to plank.',
      approvedAsset: _mountainClimbersV1Asset('05_left_return'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.50,
    ),
    PoseDefinition(
      poseId: 'mountain_climbers_v1_06',
      order: 6,
      label: 'RESET',
      instruction: 'Reset to a stable high plank.',
      approvedAsset: _mountainClimbersV1Asset('06_reset'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.44,
    ),
  ],
  // Weighted 500/720/500/720/500/440ms per frame (never an even split) =
  // 3.38s per complete visual cycle. Slowed again (~1.7x from the prior
  // 290/420/290/420/290/260ms = 1.97s pass) per explicit "still too fast"
  // production feedback — a Mountain-Climbers-specific timing change only;
  // every other exercise's phaseSeconds is untouched.
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.landscape,
  visualAspectRatio: 600 / 400, // real Mountain Climbers V1 frames
  // Athletic/rhythmic movement: two overlapping semi-transparent frames
  // would look wrong — clean sequential frame replacement instead (Section 9).
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: 'Next: Mountain Climbers.',
    benefit:
        'Mountain Climbers work your core while building full-body endurance.',
    setupInstruction:
        'Start in a strong high plank with your hands under your shoulders.',
    quarterCue: 'Drive one knee toward your chest at a time.',
    formCues: [
      'Keep a steady rhythm.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Done.',
  ),
);

/// Real, individually-exported production frames — Figma
/// `wZpdIxyGJ3DDPVHtZtwQeC`, node `12_DEAD_BUG_V2__QA_APPROVED_LOCKED`
/// (`526:2`) > `EX_019_DEAD_BUG_V2__QA_APPROVED_LOCKED` (`524:38`) >
/// `EX_019_DEAD_BUG_ANIMATION_ASSETS_V2__PRODUCTION_READY` (`524:39`,
/// frames `524:41`-`524:51`). Landscape 600×400, same real ratio as V1.
/// Stored in its own isolated `dead_bug/female/v2/` folder, never mixed
/// with any other exercise's assets.
///
/// Figma calls this asset set "EX-019" (its own internal library numbering
/// for the Dead Bug design) — that is NOT this app's `EX019`, which is
/// Wall Push-Up (see `exercise_catalog.dart`). In RoutinePlayer this
/// remains `EX012`, exactly as V1 was; only the asset source and pose
/// sequence changed. Do not let the Figma "EX-019" label leak into the
/// app's exercise id.
///
/// QA-approved (`524:52` `EX_019_DEAD_BUG_ANIMATION_QA_V2`, verdict
/// `V2_BETTER`) over V1: no badges baked into frames, clearer overhead-arm
/// reach, better pose differentiation. The QA board's own "LOOP PREVIEW"
/// section documents the production loop order as
/// 01->02->03->04->05->06->04->01 (NOT a full forward+mirror-reverse —
/// frame 4 "TABLETOP RETURN" and frame 1 "TABLETOP START" are visually
/// close enough that jumping straight from 4 back to 1 reads as seamless,
/// per the QA notes). [LoopMode.reversibleCycle] would instead produce
/// 01,02,03,04,05,06,05,04,03,02,(01...), which is a different loop —
/// hence [LoopMode.customSequence] below.
String _deadBugV2Asset(String file) =>
    'assets/glow_up/exercises/dead_bug/female/v2/ex019_dead_bug_female_$file.png';

/// Reuses id `EX012` — same convention as every other RoutinePlayer
/// exercise, whose ids deliberately mirror the same real-world exercise's
/// id in the separate legacy `lib/workout` catalog (`EX012` = "Dead Bug"
/// there too). RoutinePlayer does not import that module. This replaces
/// the V1 definition in place — same exercise identity, V2 production
/// assets and loop; V1's frames were never referenced by any active code
/// path (confirmed unbundled — absent from pubspec.yaml too) and have
/// been archived to `assets/_archive_legacy/dead_bug_v1/`, outside the
/// bundled asset tree.
final _deadBug = ExerciseDefinition(
  id: 'EX012',
  displayName: 'Dead Bug',
  category: 'Core',
  playbackType: 'REPS',
  bodyAreas: const ['Core', 'Lower Back'],
  benefitShort:
      'Dead Bug strengthens your core while protecting your lower back.',
  durationSeconds: 40,
  poses: [
    PoseDefinition(
      poseId: 'dead_bug_v2_01',
      order: 1,
      label: 'TABLETOP START',
      instruction:
          'Lie on your back with your arms up and knees bent at 90 degrees, tabletop position.',
      approvedAsset: _deadBugV2Asset('01_tabletop_start'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.56,
    ),
    PoseDefinition(
      poseId: 'dead_bug_v2_02',
      order: 2,
      label: 'OPPOSITE EXTENSION A',
      instruction:
          'Reach one arm overhead and extend the opposite leg out, with control.',
      approvedAsset: _deadBugV2Asset('02_opposite_extension_a'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.56,
    ),
    PoseDefinition(
      poseId: 'dead_bug_v2_03',
      order: 3,
      label: 'FULL CONTROL A',
      instruction:
          'Continue the extension fully, keeping your core braced and lower back down.',
      approvedAsset: _deadBugV2Asset('03_full_control_a'),
      purpose: PosePurpose.active,
      phaseSeconds: 0.56,
    ),
    PoseDefinition(
      poseId: 'dead_bug_v2_04',
      order: 4,
      label: 'TABLETOP RETURN',
      instruction:
          'Return your arm and leg to the tabletop position, with control.',
      approvedAsset: _deadBugV2Asset('04_tabletop_return'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.56,
    ),
    PoseDefinition(
      poseId: 'dead_bug_v2_05',
      order: 5,
      label: 'OPPOSITE EXTENSION B',
      instruction:
          'Reach your other arm overhead and extend the opposite leg out, with control.',
      approvedAsset: _deadBugV2Asset('05_opposite_extension_b'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.56,
    ),
    PoseDefinition(
      poseId: 'dead_bug_v2_06',
      order: 6,
      label: 'FULL CONTROL B',
      instruction:
          'Continue the extension fully on this side, keeping your core braced.',
      approvedAsset: _deadBugV2Asset('06_full_control_b'),
      purpose: PosePurpose.active,
      phaseSeconds: 0.56,
    ),
  ],
  // Exercise-specific loop (see LoopMode.customSequence doc): 01->02->03->
  // 04->05->06->04->01->repeat. 560ms/transition, matching V1's pacing —
  // 8 steps x 560ms = 4.48s per full cycle.
  loopMode: LoopMode.customSequence,
  customLoopOrder: const [1, 2, 3, 4, 5, 6, 4, 1],
  visualOrientation: ExerciseVisualOrientation.landscape,
  visualAspectRatio: 600 / 400, // real Dead Bug V2 frames
  // No ghosting/crossfade/double-woman — clean sequential frame replacement.
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: 'Next: Dead Bug.',
    benefit: 'Dead Bug strengthens your core while protecting your lower back.',
    setupInstruction:
        'Lie on your back with your arms up and knees bent. Keep your lower back gently pressed into the mat.',
    quarterCue: 'Extend with control.',
    formCues: [
      'Keep your core tight and your lower back down.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Done.',
  ),
);

/// The Phase 1 engine-validation routine — exactly these 9 exercises, in
/// this order (each new exercise appended last so every existing exercise
/// keeps its original index), per the explicit brief. Not a production
/// workout; reached only via the dev-only `/dev/routine-player-qa` route.
final List<ExerciseDefinition> kRoutinePlayerPhase1Qa = [
  _squat,
  _lunges,
  _pushUps,
  _deepBreathing,
  _plank,
  _jumpingJack,
  _gluteBridge,
  _mountainClimbers,
  _deadBug,
];

/// EX014-EX016 have real catalog data (name/category/reps/duration, see
/// `exercise_catalog.dart`) but no verified Figma pose images yet — same
/// status as in the legacy `lib/workout` catalog. Added here (single
/// unverified pose, `approvedAsset: null`) only so Core Crusher's real
/// 8-exercise sequence can resolve every id through RoutinePlayer without
/// dropping exercises; [MovementDisplay] already renders a null asset as
/// clean "UNVERIFIED EXERCISE ASSET" text, never an invented image. Voice
/// copy reuses the exact real cue text already authored in
/// `exercise_catalog.dart`'s placeholder steps — nothing new invented.
/// EX013 (Bicycle Crunch) used to be part of this same pending group —
/// see `_bicycleCrunch` below for its real, approved V2 definition.

/// Real, individually-exported production frames — Figma
/// `wZpdIxyGJ3DDPVHtZtwQeC`, node `EX-013 Bicycle Crunch` (`593:2`) >
/// `EX_013_BICYCLE_CRUNCH_V2_QA_APPROVED_LOCKED` (`593:3`) >
/// `EX_013_BICYCLE_CRUNCH_ANIMATION_ASSETS_V2` (`593:4`, frames
/// `593:7`-`593:17`). Landscape 576×432 — its own real ratio. Stored in
/// its own isolated `bicycle_crunch/female/v2/` folder, never mixed with
/// any other exercise's assets.
///
/// QA-approved (`593:5` `EX_013_BICYCLE_CRUNCH_V2_QA_PREVIEW`, checklist
/// confirms no cropped heads/hands/feet, consistent scale, clean
/// backgrounds, correct bicycle-crunch anatomy). The QA preview's own
/// "FORWARD" label (`01 → 02 → 03 → 04 → 05 → 06 → 01`) matches the
/// explicit brief exactly; the separate dev-handoff note also lists an
/// alternative "ping-pong" pattern, but the forward-only order is what was
/// actually specified, so that's what's implemented — same resolution as
/// Fire Hydrant's equivalent QA-board ambiguity. [LoopMode.timedCycle]
/// produces exactly 01->02->03->04->05->06->(01...), weighting the two
/// "crunch" extremes (frames 02/04) slightly longer than the transitional
/// frames.
String _bicycleCrunchV2Asset(String file) =>
    'assets/glow_up/exercises/bicycle_crunch/female/v2/ex013_bicycle_crunch_female_$file.png';

final _bicycleCrunch = ExerciseDefinition(
  id: 'EX013',
  displayName: 'Bicycle Crunch',
  category: 'Core',
  playbackType: 'REPS',
  bodyAreas: const ['Core'],
  benefitShort:
      'Bicycle Crunch works your entire core with a rotational twist.',
  durationSeconds: 40,
  reps: 15,
  poses: [
    PoseDefinition(
      poseId: 'bicycle_crunch_v2_01',
      order: 1,
      label: 'START',
      instruction:
          'Start on your back with knees bent and hands lightly behind your head.',
      approvedAsset: _bicycleCrunchV2Asset('01_start'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.55,
    ),
    PoseDefinition(
      poseId: 'bicycle_crunch_v2_02',
      order: 2,
      label: 'LEFT CRUNCH',
      instruction: 'Bring your right elbow toward your left knee.',
      approvedAsset: _bicycleCrunchV2Asset('02_left_crunch'),
      purpose: PosePurpose.active,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'bicycle_crunch_v2_03',
      order: 3,
      label: 'CENTER TRANSITION',
      instruction: 'Rotate back through center with control.',
      approvedAsset: _bicycleCrunchV2Asset('03_center_transition'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.55,
    ),
    PoseDefinition(
      poseId: 'bicycle_crunch_v2_04',
      order: 4,
      label: 'RIGHT CRUNCH',
      instruction: 'Bring your left elbow toward your right knee.',
      approvedAsset: _bicycleCrunchV2Asset('04_right_crunch'),
      purpose: PosePurpose.active,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'bicycle_crunch_v2_05',
      order: 5,
      label: 'CENTER RETURN',
      instruction: 'Rotate back through center with control.',
      approvedAsset: _bicycleCrunchV2Asset('05_center_return'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.55,
    ),
    PoseDefinition(
      poseId: 'bicycle_crunch_v2_06',
      order: 6,
      label: 'RESET',
      instruction: 'Reset to the starting position.',
      approvedAsset: _bicycleCrunchV2Asset('06_reset'),
      purpose: PosePurpose.finish,
      phaseSeconds: 0.55,
    ),
  ],
  // Forward loop only (never ping-ponged): 01->02->03->04->05->06->(01...).
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.landscape,
  visualAspectRatio: 576 / 432, // real Bicycle Crunch V2 frames
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: 'Next: Bicycle Crunch.',
    benefit: 'Bicycle Crunch works your entire core with a rotational twist.',
    setupInstruction:
        'Start on your back with your knees bent and hands lightly behind your head.',
    quarterCue: 'Rotate through your core, not just your elbow.',
    formCues: [
      'Keep your lower back pressed into the mat.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Done.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/leg_raises/female/v2/EX014_F_0N_*.png`. Same
/// provenance model as Bird Dog (EX016): placed directly on disk, no
/// Figma node reference exists for this set — do not invent one. Put
/// through a dedicated read-only validation + static-image visual QA pass
/// (file existence, PNG format, uniform 277×265 canvas, correct
/// bent-knee/extend/hold/raise/return sequence, no cropped head/hands/
/// feet, consistent woman/outfit/background/mat/camera angle, seamless
/// 06→01 match), then explicitly human-approved for production use.
///
/// Loop order 01->02->03->04->05->06->(01...), a plain forward wrap, per
/// the approved sequence — [LoopMode.timedCycle] already produces this,
/// same mechanism as Bird Dog/Bicycle Crunch/Fire Hydrant.
String _legRaisesV2Asset(String file) =>
    'assets/glow_up/exercises/leg_raises/female/v2/EX014_F_$file.png';

final _legRaises = ExerciseDefinition(
  id: 'EX014',
  displayName: 'Leg Raises',
  category: 'Core',
  playbackType: 'REPS',
  bodyAreas: const ['Core'],
  benefitShort: 'Leg Raises target your lower abs and hip flexors.',
  durationSeconds: 40,
  reps: 12,
  poses: [
    PoseDefinition(
      poseId: 'leg_raises_v2_01',
      order: 1,
      label: 'START',
      instruction: 'Lie on your back with your knees bent over your hips.',
      approvedAsset: _legRaisesV2Asset('01_START'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.55,
    ),
    PoseDefinition(
      poseId: 'leg_raises_v2_02',
      order: 2,
      label: 'LOWER',
      instruction: 'Extend both legs and lower them together with control.',
      approvedAsset: _legRaisesV2Asset('02_LOWER'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'leg_raises_v2_03',
      order: 3,
      label: 'LOW HOLD',
      instruction: 'Hold your legs low, just above the floor.',
      approvedAsset: _legRaisesV2Asset('03_LOW_HOLD'),
      purpose: PosePurpose.active,
      phaseSeconds: 0.75,
    ),
    PoseDefinition(
      poseId: 'leg_raises_v2_04',
      order: 4,
      label: 'RAISE',
      instruction: 'Raise both legs back up together with control.',
      approvedAsset: _legRaisesV2Asset('04_RAISE'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'leg_raises_v2_05',
      order: 5,
      label: 'TABLETOP RETURN',
      instruction: 'Bend your knees back to the tabletop position.',
      approvedAsset: _legRaisesV2Asset('05_TABLETOP_RETURN'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.55,
    ),
    PoseDefinition(
      poseId: 'leg_raises_v2_06',
      order: 6,
      label: 'RESET',
      instruction: 'Reset to the starting position.',
      approvedAsset: _legRaisesV2Asset('06_RESET'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.55,
    ),
  ],
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.landscape,
  visualAspectRatio: 277 / 265, // real Leg Raises V2 frames
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: 'Next: Leg Raises.',
    benefit: 'Leg Raises target your lower abs and hip flexors.',
    setupInstruction: 'Lie on your back with your knees bent over your hips.',
    quarterCue: 'Keep your lower back pressed into the mat.',
    formCues: [
      'Move slowly — control the lower, not gravity.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Done.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/russian_twist/female/v2/EX015_F_0N_*.png`.
/// Same provenance model as Bird Dog (EX016) and Leg Raises (EX014):
/// placed directly on disk, no Figma node reference exists for this set —
/// do not invent one. Human visual approval completed prior to this
/// implementation; uniform 277×265 canvas confirmed on all six frames.
///
/// Loop order 01->02->03->04->05->06->(01...), a plain forward wrap, per
/// the approved sequence — [LoopMode.timedCycle] already produces this,
/// same mechanism as Bird Dog/Leg Raises/Bicycle Crunch/Fire Hydrant.
String _russianTwistV2Asset(String file) =>
    'assets/glow_up/exercises/russian_twist/female/v2/EX015_F_$file.png';

final _russianTwist = ExerciseDefinition(
  id: 'EX015',
  displayName: 'Russian Twist',
  category: 'Core',
  playbackType: 'REPS',
  bodyAreas: const ['Core'],
  benefitShort: 'Russian Twist builds rotational core strength.',
  durationSeconds: 40,
  reps: 16,
  poses: [
    PoseDefinition(
      poseId: 'russian_twist_v2_01',
      order: 1,
      label: 'START',
      instruction:
          'Sit with your knees bent and lean back slightly, keeping your back straight.',
      approvedAsset: _russianTwistV2Asset('01_START'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.55,
    ),
    PoseDefinition(
      poseId: 'russian_twist_v2_02',
      order: 2,
      label: 'ROTATE LEFT',
      instruction: 'Rotate your torso to the left, keeping your core engaged.',
      approvedAsset: _russianTwistV2Asset('02_ROTATE_LEFT'),
      purpose: PosePurpose.active,
      phaseSeconds: 0.75,
    ),
    PoseDefinition(
      poseId: 'russian_twist_v2_03',
      order: 3,
      label: 'CENTER RETURN',
      instruction: 'Rotate back through center with control.',
      approvedAsset: _russianTwistV2Asset('03_CENTER_RETURN'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.55,
    ),
    PoseDefinition(
      poseId: 'russian_twist_v2_04',
      order: 4,
      label: 'ROTATE RIGHT',
      instruction: 'Rotate your torso to the right, keeping your core engaged.',
      approvedAsset: _russianTwistV2Asset('04_ROTATE_RIGHT'),
      purpose: PosePurpose.active,
      phaseSeconds: 0.75,
    ),
    PoseDefinition(
      poseId: 'russian_twist_v2_05',
      order: 5,
      label: 'CENTER RETURN',
      instruction: 'Rotate back through center with control.',
      approvedAsset: _russianTwistV2Asset('05_CENTER_RETURN'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.55,
    ),
    PoseDefinition(
      poseId: 'russian_twist_v2_06',
      order: 6,
      label: 'RESET',
      instruction: 'Reset to the starting position.',
      approvedAsset: _russianTwistV2Asset('06_RESET'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.55,
    ),
  ],
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.landscape,
  visualAspectRatio: 277 / 265, // real Russian Twist V2 frames
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: 'Next: Russian Twist.',
    benefit: 'Russian Twist builds rotational core strength.',
    setupInstruction:
        'Sit with your knees bent and lean back slightly, keeping your back straight.',
    quarterCue: 'Rotate through your core, not just your arms.',
    formCues: [
      'Keep your chest lifted and move with control.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Done.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/bird_dog/female/v2/EX016_F_0N_*.png`. Unlike
/// every other approved Core exercise, these weren't sourced through the
/// Figma MCP in this session — they were placed directly on disk and put
/// through a dedicated read-only validation + static-image visual QA pass
/// (file existence, PNG format, uniform 277×265 canvas, no cropped
/// head/hands/feet, consistent woman/outfit/background/mat/camera angle,
/// contralateral arm+leg extension pattern, seamless 06→01 match), then
/// explicitly human-approved for production use. No Figma node reference
/// exists for this set — do not invent one.
///
/// Loop order 01->02->03->04->05->06->(01...), a plain forward wrap, per
/// the approved sequence — [LoopMode.timedCycle] already produces this.
String _birdDogV2Asset(String file) =>
    'assets/glow_up/exercises/bird_dog/female/v2/EX016_F_$file.png';

final _birdDog = ExerciseDefinition(
  id: 'EX016',
  displayName: 'Bird Dog',
  category: 'Core',
  playbackType: 'REPS',
  bodyAreas: const ['Core', 'Lower Back'],
  benefitShort: 'Bird Dog builds core stability and balance.',
  durationSeconds: 40,
  reps: 10,
  poses: [
    PoseDefinition(
      poseId: 'bird_dog_v2_01',
      order: 1,
      label: 'START',
      instruction:
          'Start on all fours with your hands under your shoulders and knees under your hips.',
      approvedAsset: _birdDogV2Asset('01_START'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.55,
    ),
    PoseDefinition(
      poseId: 'bird_dog_v2_02',
      order: 2,
      label: 'LEFT EXTENSION',
      instruction:
          'Extend one arm forward and the opposite leg back, keeping your hips square.',
      approvedAsset: _birdDogV2Asset('02_LEFT_EXTENSION'),
      purpose: PosePurpose.active,
      phaseSeconds: 0.75,
    ),
    PoseDefinition(
      poseId: 'bird_dog_v2_03',
      order: 3,
      label: 'CENTER RETURN',
      instruction: 'Return to the neutral tabletop position with control.',
      approvedAsset: _birdDogV2Asset('03_CENTER_RETURN'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.55,
    ),
    PoseDefinition(
      poseId: 'bird_dog_v2_04',
      order: 4,
      label: 'RIGHT EXTENSION',
      instruction:
          'Extend the other arm forward and the opposite leg back, keeping your hips square.',
      approvedAsset: _birdDogV2Asset('04_RIGHT_EXTENSION'),
      purpose: PosePurpose.active,
      phaseSeconds: 0.75,
    ),
    PoseDefinition(
      poseId: 'bird_dog_v2_05',
      order: 5,
      label: 'CENTER RETURN',
      instruction: 'Return to the neutral tabletop position with control.',
      approvedAsset: _birdDogV2Asset('05_CENTER_RETURN'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.55,
    ),
    PoseDefinition(
      poseId: 'bird_dog_v2_06',
      order: 6,
      label: 'RESET',
      instruction: 'Reset to the starting tabletop position.',
      approvedAsset: _birdDogV2Asset('06_RESET'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.55,
    ),
  ],
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.landscape,
  visualAspectRatio: 277 / 265, // real Bird Dog V2 frames
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: 'Next: Bird Dog.',
    benefit: 'Bird Dog builds core stability and balance.',
    setupInstruction:
        'Start on all fours with your hands under your shoulders and knees under your hips.',
    quarterCue: 'Keep your hips square as you extend.',
    formCues: [
      'Move slowly and stay balanced.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Done.',
  ),
);

/// EX002-EX006 have real catalog data but no verified Figma pose images
/// yet — same status/rationale as EX013-EX016 above (see that block's
/// doc). Added only so Bedtime Meditation's real 6-exercise sequence
/// (EX001-EX006) can resolve every id through RoutinePlayer, the same way
/// EX013-EX016 unblocked Core Crusher. Deep Breathing (EX001) already had
/// a real, fully-verified RoutinePlayer definition before this — these 5
/// are the ones that were missing, not it.
///
/// EX002 specifically is now superseded: Bedtime Meditation's real
/// "Full Body Stretch" slot uses the fully-verified `_fullBodyStretchV2`
/// (id `EX061`) below instead — see that definition's doc comment for why
/// a new id was minted rather than upgrading this placeholder in place.
/// This EX002 definition is left exactly as it was, unreferenced by any
/// production workout, purely so nothing that still resolves it directly
/// by id (if anything does) breaks — except its displayName, which gets
/// an "(Unverified)" suffix here so it no longer collides with EX061's
/// identical display name and violates the app-wide "Tier 1 display
/// names are unique" invariant. EX002 was never an approved exercise
/// (approvedAsset is null below), so this isn't an edit to approved
/// content, just a label disambiguation on an already-orphaned stub.
final _fullBodyStretch = ExerciseDefinition(
  id: 'EX002',
  displayName: 'Full Body Stretch (Unverified)',
  category: 'Bedtime',
  playbackType: 'SEQUENCE_LOOP',
  bodyAreas: const ['Full Body'],
  benefitShort:
      'Full Body Stretch lengthens and relaxes your whole body before rest.',
  durationSeconds: 45,
  poses: const [
    PoseDefinition(
      poseId: 'full_body_stretch_01',
      order: 1,
      label: 'GO',
      instruction: 'Reach and lengthen through your whole body.',
      approvedAsset: null,
      purpose: PosePurpose.active,
    ),
  ],
  loopMode: LoopMode.continuousLoop,
  voiceScript: const VoiceScript(
    intro: 'Next: Full Body Stretch.',
    benefit:
        'Full Body Stretch lengthens and relaxes your whole body before rest.',
    setupInstruction: 'Reach and lengthen through your whole body.',
    finishCue: 'Done.',
  ),
);

// Superseded by _kneeToChestV2 (EX062) below — see that definition's doc
// comment. Left as-is except displayName (disambiguated to avoid a
// duplicate-Tier-1-display-name collision; never approved content).
final _kneeToChest = ExerciseDefinition(
  id: 'EX003',
  displayName: 'Knee-to-Chest (Unverified)',
  category: 'Bedtime',
  playbackType: 'SIDE_SEQUENCE',
  bodyAreas: const ['Hips', 'Lower Back'],
  benefitShort:
      'Knee-to-Chest gently releases tension in your hips and lower back.',
  durationSeconds: 40,
  poses: const [
    PoseDefinition(
      poseId: 'knee_to_chest_01',
      order: 1,
      label: 'GO',
      instruction: 'Pull one knee gently toward your chest.',
      approvedAsset: null,
      purpose: PosePurpose.active,
    ),
  ],
  loopMode: LoopMode.continuousLoop,
  voiceScript: const VoiceScript(
    intro: 'Next: Knee-to-Chest.',
    benefit:
        'Knee-to-Chest gently releases tension in your hips and lower back.',
    setupInstruction: 'Pull one knee gently toward your chest.',
    finishCue: 'Done.',
  ),
);

// Superseded by _supineTwistV2 (EX063) below — see that definition's doc
// comment. Left as-is except displayName (disambiguated to avoid a
// duplicate-Tier-1-display-name collision; never approved content).
final _supineTwist = ExerciseDefinition(
  id: 'EX004',
  displayName: 'Supine Twist (Unverified)',
  category: 'Bedtime',
  playbackType: 'SIDE_SEQUENCE',
  bodyAreas: const ['Spine', 'Lower Back'],
  benefitShort: 'Supine Twist releases tension along your spine before sleep.',
  durationSeconds: 40,
  poses: const [
    PoseDefinition(
      poseId: 'supine_twist_01',
      order: 1,
      label: 'GO',
      instruction: 'Let your knees fall gently to one side.',
      approvedAsset: null,
      purpose: PosePurpose.active,
    ),
  ],
  loopMode: LoopMode.continuousLoop,
  voiceScript: const VoiceScript(
    intro: 'Next: Supine Twist.',
    benefit: 'Supine Twist releases tension along your spine before sleep.',
    setupInstruction: 'Let your knees fall gently to one side.',
    finishCue: 'Done.',
  ),
);

// Superseded by _ankleCirclesV2 (EX064) below — see that definition's doc
// comment. Left as-is except displayName (disambiguated to avoid a
// duplicate-Tier-1-display-name collision; never approved content).
final _ankleCircles = ExerciseDefinition(
  id: 'EX005',
  displayName: 'Ankle Circles (Unverified)',
  category: 'Bedtime',
  playbackType: 'SIDE_SEQUENCE',
  bodyAreas: const ['Ankles'],
  benefitShort:
      'Ankle Circles ease tension and improve circulation before rest.',
  durationSeconds: 30,
  poses: const [
    PoseDefinition(
      poseId: 'ankle_circles_01',
      order: 1,
      label: 'GO',
      instruction: 'Circle your ankle slowly in each direction.',
      approvedAsset: null,
      purpose: PosePurpose.active,
    ),
  ],
  loopMode: LoopMode.continuousLoop,
  voiceScript: const VoiceScript(
    intro: 'Next: Ankle Circles.',
    benefit: 'Ankle Circles ease tension and improve circulation before rest.',
    setupInstruction: 'Circle your ankle slowly in each direction.',
    finishCue: 'Done.',
  ),
);

// Superseded by _sitUpReachV2 (EX065) below — see that definition's doc
// comment. Left as-is except displayName (disambiguated to avoid a
// duplicate-Tier-1-display-name collision; never approved content).
final _sitUpReach = ExerciseDefinition(
  id: 'EX006',
  displayName: 'Sit-Up Reach (Unverified)',
  category: 'Bedtime',
  playbackType: 'REPS',
  bodyAreas: const ['Core'],
  benefitShort:
      'Sit-Up Reach gently activates your core with a calm, controlled reach.',
  durationSeconds: 40,
  reps: 10,
  poses: const [
    PoseDefinition(
      poseId: 'sit_up_reach_01',
      order: 1,
      label: 'GO',
      instruction: 'Sit up and reach toward your toes.',
      approvedAsset: null,
      purpose: PosePurpose.active,
    ),
  ],
  loopMode: LoopMode.continuousLoop,
  voiceScript: const VoiceScript(
    intro: 'Next: Sit-Up Reach.',
    benefit:
        'Sit-Up Reach gently activates your core with a calm, controlled reach.',
    setupInstruction: 'Sit up and reach toward your toes.',
    finishCue: 'Done.',
  ),
);

/// Real, individually-exported production frames — Figma
/// `wZpdIxyGJ3DDPVHtZtwQeC`, node `EX-003 Side Lunge Left` (`546:2`) >
/// `EX_003_SIDE_LUNGE_LEFT_V2_QA_APPROVED_LOCKED` (`545:2`) >
/// `EX_003_SIDE_LUNGE_LEFT_ANIMATION_ASSETS_V2` (`545:3`, frames
/// `545:6`-`545:16`). Portrait 512×768 — its own real ratio. Stored in its
/// own isolated `side_lunge_left/female/v2/` folder, never mixed with any
/// other exercise's assets.
///
/// Figma calls this exercise "EX-003" (its own internal library
/// numbering) — that is NOT this app's `EX003`, which is already
/// Knee-to-Chest (see `_kneeToChest` above, part of Bedtime Meditation).
/// Side Lunge Left did not exist anywhere in the app before this, so it's
/// assigned the next free canonical id, `EX053` (the 52-exercise
/// Exercise Sequence Library handoff table filled EX001-EX052 with no
/// gaps — this is a genuinely new 53rd entry, not a renumbering).
///
/// The same Figma page also has a already-designed
/// `EX_003_SIDE_LUNGE_RIGHT_V1_QA_APPROVED_LOCKED` section (`549:2`) —
/// explicitly out of scope; not implemented here, never referenced below.
///
/// QA-approved (`545:4` `EX_003_SIDE_LUNGE_LEFT_ANIMATION_QA_V2`). The QA
/// board's own "QA_LOOP" section documents the production loop order as
/// 01->02->03->04->05->06->01->repeat — a plain forward wrap, unlike Dead
/// Bug V2's skip-back loop, so [LoopMode.timedCycle] (not
/// [LoopMode.customSequence]) is correct here: it already produces exactly
/// this order, just weighting frame 04 ("LEFT_LUNGE_HOLD") longer than the
/// transitional frames.
String _sideLungeLeftV2Asset(String file) =>
    'assets/glow_up/exercises/side_lunge_left/female/v2/ex003_side_lunge_left_female_$file.png';

final _sideLungeLeft = ExerciseDefinition(
  id: 'EX053',
  displayName: 'Side Lunge Left',
  category: 'Strength',
  playbackType: 'REPS',
  bodyAreas: const ['Legs', 'Glutes', 'Inner Thighs'],
  benefitShort:
      'Side Lunge Left strengthens your legs and glutes while improving lateral stability.',
  durationSeconds: 40,
  poses: [
    PoseDefinition(
      poseId: 'side_lunge_left_01',
      order: 1,
      label: 'START WIDE',
      instruction: 'Stand with feet wide apart.',
      approvedAsset: _sideLungeLeftV2Asset('01_start_wide'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.6,
    ),
    PoseDefinition(
      poseId: 'side_lunge_left_02',
      order: 2,
      label: 'SHIFT LEFT',
      instruction: 'Shift your weight to the left side.',
      approvedAsset: _sideLungeLeftV2Asset('02_shift_left'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.5,
    ),
    PoseDefinition(
      poseId: 'side_lunge_left_03',
      order: 3,
      label: 'LEFT LUNGE',
      instruction: 'Sit into a deep lunge on the left side.',
      approvedAsset: _sideLungeLeftV2Asset('03_left_lunge'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.6,
    ),
    PoseDefinition(
      poseId: 'side_lunge_left_04',
      order: 4,
      label: 'HOLD',
      instruction: 'Hold the left-side lunge briefly.',
      approvedAsset: _sideLungeLeftV2Asset('04_left_lunge_hold'),
      purpose: PosePurpose.active,
      phaseSeconds: 0.9,
    ),
    PoseDefinition(
      poseId: 'side_lunge_left_05',
      order: 5,
      label: 'PUSH RETURN',
      instruction: 'Push through your left heel toward center.',
      approvedAsset: _sideLungeLeftV2Asset('05_push_return'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.6,
    ),
    PoseDefinition(
      poseId: 'side_lunge_left_06',
      order: 6,
      label: 'CENTER RETURN',
      instruction: 'Return to the starting wide stance.',
      approvedAsset: _sideLungeLeftV2Asset('06_center_return'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.6,
    ),
  ],
  // Forward loop only (never mirrored, never generates a right-side copy):
  // 01->02->03->04->05->06->(01...). Left side only, per explicit brief.
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.portrait,
  visualAspectRatio: 512 / 768, // real Side Lunge Left V2 frames
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: 'Next: Side Lunge Left.',
    benefit:
        'Side Lunge Left strengthens your legs and glutes while improving lateral stability.',
    setupInstruction:
        'Stand with your feet wide and shift your weight to the left.',
    quarterCue: 'Push your hips back.',
    formCues: [
      'Keep your right leg straight and your left knee tracking over your foot.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Done.',
  ),
);

/// Real, individually-exported production frames — Figma
/// `wZpdIxyGJ3DDPVHtZtwQeC`, node `EX-006 Fire Hydrant` (`560:62`) >
/// `EX_006_FIRE_HYDRANT_V2_QA_APPROVED_LOCKED` (`560:24`) >
/// `EX_006_FIRE_HYDRANT_ANIMATION_ASSETS_V2` (`560:25`, frames
/// `560:28`-`560:38`). Landscape 576×432 — its own real ratio. Stored in
/// its own isolated `fire_hydrant/female/v2/` folder, never mixed with any
/// other exercise's assets.
///
/// Figma calls this exercise "EX-006" (its own internal library
/// numbering) — that is NOT this app's `EX006`, which is already Sit-Up
/// Reach (see `_sitUpReach` above, part of Bedtime Meditation). Fire
/// Hydrant did not exist anywhere in the app before this, so it's
/// assigned the next free canonical id, `EX054` (the legacy 52-exercise
/// catalog fills EX001-EX052 with no gaps, and `EX053` was just taken by
/// Side Lunge Left — Fire Hydrant is a genuinely new 54th entry).
///
/// QA-approved (`560:26` `EX_006_FIRE_HYDRANT_ANIMATION_QA_V2`, checklist
/// confirms bent-knee lateral abduction, no straight-leg kick, same
/// woman/outfit/background/angle across all 6, "Loop 06 -> 01: PASS —
/// smooth transition"). That QA section's own text label
/// ("QA LOOP SEQUENCE (01→06→01)") and checklist both describe a plain
/// forward wrap — matching the explicit brief — even though the QA
/// board's frame thumbnails extend into a longer 10-frame smoothness-check
/// strip (01-06 then 05-04-03-02); that strip is a visual-smoothness aid,
/// not the runtime loop spec. [LoopMode.timedCycle] already produces
/// exactly 01->02->03->04->05->06->(01...), weighting frame 04 ("HOLD")
/// longer than the transitional frames, same pattern as Squat/Side Lunge
/// Left.
String _fireHydrantV2Asset(String file) =>
    'assets/glow_up/exercises/fire_hydrant/female/v2/ex006_fire_hydrant_female_$file.png';

final _fireHydrant = ExerciseDefinition(
  id: 'EX054',
  displayName: 'Fire Hydrant',
  category: 'Strength',
  playbackType: 'REPS',
  bodyAreas: const ['Glutes', 'Hips'],
  benefitShort:
      'Fire Hydrant strengthens your glutes and improves hip stability.',
  durationSeconds: 40,
  poses: [
    PoseDefinition(
      poseId: 'fire_hydrant_01',
      order: 1,
      label: 'START',
      instruction:
          'Start on all fours, hands under your shoulders and knees under your hips.',
      approvedAsset: _fireHydrantV2Asset('01_start'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.6,
    ),
    PoseDefinition(
      poseId: 'fire_hydrant_02',
      order: 2,
      label: 'PREPARE',
      instruction: 'Brace your core and prepare to lift.',
      approvedAsset: _fireHydrantV2Asset('02_prepare'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.5,
    ),
    PoseDefinition(
      poseId: 'fire_hydrant_03',
      order: 3,
      label: 'LIFT RIGHT',
      instruction: 'Lift your right knee out to the side, keeping it bent.',
      approvedAsset: _fireHydrantV2Asset('03_lift_right'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.6,
    ),
    PoseDefinition(
      poseId: 'fire_hydrant_04',
      order: 4,
      label: 'HOLD',
      instruction: 'Hold at the top of the lift.',
      approvedAsset: _fireHydrantV2Asset('04_hold'),
      purpose: PosePurpose.active,
      phaseSeconds: 0.9,
    ),
    PoseDefinition(
      poseId: 'fire_hydrant_05',
      order: 5,
      label: 'LOWER',
      instruction: 'Lower your leg back down with control.',
      approvedAsset: _fireHydrantV2Asset('05_lower'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.6,
    ),
    PoseDefinition(
      poseId: 'fire_hydrant_06',
      order: 6,
      label: 'RETURN',
      instruction: 'Return to the starting all-fours position.',
      approvedAsset: _fireHydrantV2Asset('06_return'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.6,
    ),
  ],
  // Forward loop only (never ping-ponged): 01->02->03->04->05->06->(01...).
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.landscape,
  visualAspectRatio: 576 / 432, // real Fire Hydrant V2 frames
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: 'Next: Fire Hydrant.',
    benefit: 'Fire Hydrant strengthens your glutes and improves hip stability.',
    setupInstruction:
        'Start on all fours with your hands under your shoulders and knees under your hips.',
    quarterCue: 'Keep your right knee bent as you lift.',
    formCues: [
      'Keep your core engaged and avoid rotating your hips.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Done.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/sun_salutation/female/v2/EX055_F_0N_*.png`.
/// Same provenance model as EX025-EX031: placed directly on disk, no Figma
/// node reference exists for this set — do not invent one. Human visual
/// approval completed prior to this implementation; frames are ~310-315 x
/// 316-317px (near-square, minor per-frame variance) — treated as square
/// per the same convention as Quad Stretch's real 768x768 set.
///
/// ID note: this exercise does NOT use "EX032" despite the source asset
/// batch originally being named that way. EX032 is already permanently
/// assigned to "Legs Up Wall" (Deep Sleep Prep, Bedtime) in the Tier 2
/// legacy catalog — reusing it here would make the single global Tier 1
/// registry (`kRoutinePlayerExercisesById`) resolve that id to two
/// different exercises depending on caller. The six approved PNGs were
/// renamed on disk from `EX032_F_*` to `EX055_F_*` (content bytes
/// untouched, confirmed via unchanged file sizes) and EX055 — the next
/// free id after the existing EX001-EX054 range — was assigned instead,
/// mirroring exactly how EX053 (Side Lunge Left) and EX054 (Fire Hydrant)
/// were minted for exercises with no pre-existing legacy slot. EX032
/// "Legs Up Wall" itself was not touched.
///
/// The first-ever exercise in Morning Yoga Flow to get a real Tier 1
/// definition; Downward Dog/Warrior I/Warrior II/Tree Pose/Savasana
/// remain intentionally unimplemented (no catalogId, no Tier 1
/// definition) — see `_perExerciseRoutineFor` in app_router.dart.
///
/// Loop order 01->02->03->04->05->06->(01...), a plain forward wrap, per
/// the approved sequence — [LoopMode.timedCycle] already produces this,
/// same mechanism as every other completed exercise.
///
/// Voice: standard (non-phase-synced) [VoiceScript], same model as every
/// other completed exercise — NOT [ExerciseDefinition.phaseSyncedVoice].
/// This originally used phaseSyncedVoice with a per-pose "Inhale"/"Exhale"
/// voiceCue (Deep Breathing's mechanism), on the theory that a breath-led
/// flow should speak breath cues in sync with each frame. In practice
/// that desynced: Deep Breathing's phases are 2.5s+, long enough for TTS
/// to finish before the pose changes; Sun Salutation's are 0.6-1.0s, far
/// shorter than it takes to speak a cue like "Inhale, reach your arms
/// overhead" — so the spoken audio kept playing 1-2+ seconds into later
/// frames it no longer matched, reading as repeating, unsynchronized
/// breathing commands. Fixed by dropping phaseSyncedVoice entirely and
/// using movement-only cues (no inhale/exhale) in the generic
/// once-per-exercise VoiceScript slots, exactly like Downward
/// Dog/Warrior I/Warrior II.
String _sunSalutationV2Asset(String file) =>
    'assets/glow_up/exercises/sun_salutation/female/v2/EX055_F_$file.png';

final _sunSalutation = ExerciseDefinition(
  id: 'EX055',
  displayName: 'Sun Salutation',
  category: 'Flexibility',
  playbackType: 'REPS',
  bodyAreas: const ['Full Body', 'Spine', 'Hamstrings'],
  benefitShort:
      'Sun Salutation warms up your whole body and centers your breath.',
  durationSeconds: 42,
  reps: 6,
  poses: [
    PoseDefinition(
      poseId: 'sun_salutation_v2_01',
      order: 1,
      label: 'START',
      instruction: 'Stand tall with your hands together at your chest.',
      approvedAsset: _sunSalutationV2Asset('01_START'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.6,
    ),
    PoseDefinition(
      poseId: 'sun_salutation_v2_02',
      order: 2,
      label: 'ARMS UP',
      instruction: 'Reach your arms overhead and lengthen your spine.',
      approvedAsset: _sunSalutationV2Asset('02_ARMS_UP'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.75,
    ),
    PoseDefinition(
      poseId: 'sun_salutation_v2_03',
      order: 3,
      label: 'FORWARD FOLD',
      instruction: 'Fold forward from your hips, reaching toward your feet.',
      approvedAsset: _sunSalutationV2Asset('03_FORWARD_FOLD'),
      purpose: PosePurpose.active,
      phaseSeconds: 0.9,
    ),
    PoseDefinition(
      poseId: 'sun_salutation_v2_04',
      order: 4,
      label: 'HALF LIFT',
      instruction:
          'Lengthen your spine and lift halfway, hands resting on your shins.',
      approvedAsset: _sunSalutationV2Asset('04_HALF_LIFT'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.8,
    ),
    PoseDefinition(
      poseId: 'sun_salutation_v2_05',
      order: 5,
      label: 'FORWARD FOLD',
      instruction: 'Fold forward again, releasing toward your feet.',
      approvedAsset: _sunSalutationV2Asset('05_FORWARD_FOLD'),
      purpose: PosePurpose.active,
      phaseSeconds: 0.9,
    ),
    PoseDefinition(
      poseId: 'sun_salutation_v2_06',
      order: 6,
      label: 'RESET',
      instruction: 'Rise back to standing with your hands together.',
      approvedAsset: _sunSalutationV2Asset('06_RESET'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.6,
    ),
  ],
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.square,
  visualAspectRatio: 1.0, // real Sun Salutation V2 frames, ~310-315x316-317
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: 'Next: Sun Salutation.',
    benefit: 'Sun Salutation warms up your whole body and centers your breath.',
    setupInstruction: 'Stand tall and bring your hands together.',
    quarterCue: 'Reach your arms overhead.',
    formCues: [
      'Fold forward, then rise back to standing with control.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Nice work.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/downward_dog/female/v2/EX056_F_0N_*.png`. Same
/// provenance model as EX055: placed directly on disk, no Figma node
/// reference exists for this set — do not invent one. Human visual
/// approval completed prior to this implementation; frames are ~489-493 x
/// 415px (landscape, minor per-frame width variance).
///
/// The second exercise in Morning Yoga Flow to get a real Tier 1
/// definition, after EX055 Sun Salutation. Warrior I/Warrior II/Tree
/// Pose/Savasana remain intentionally unimplemented (no catalogId, no
/// Tier 1 definition) — see `_perExerciseRoutineFor` in app_router.dart.
///
/// Loop order 01->02->03->04->05->06->(01...), a plain forward wrap, per
/// the approved sequence — [LoopMode.timedCycle] already produces this,
/// same mechanism as every other completed exercise. Unlike EX055, this
/// uses the standard (non-phase-synced) [VoiceScript] — the suggested
/// cues here are instructional stepping cues, not breath-synced text, so
/// there's no reason to special-case per-pose voice for this one.
String _downwardDogV2Asset(String file) =>
    'assets/glow_up/exercises/downward_dog/female/v2/EX056_F_$file.png';

final _downwardDog = ExerciseDefinition(
  id: 'EX056',
  displayName: 'Downward Dog',
  category: 'Flexibility',
  playbackType: 'REPS',
  bodyAreas: const ['Hamstrings', 'Shoulders', 'Calves'],
  benefitShort:
      'Downward Dog stretches your hamstrings, calves, and shoulders while building strength.',
  durationSeconds: 40,
  reps: 5,
  poses: [
    PoseDefinition(
      poseId: 'downward_dog_v2_01',
      order: 1,
      label: 'START',
      instruction: 'Start on your hands and knees, wrists under shoulders.',
      approvedAsset: _downwardDogV2Asset('01_START'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.6,
    ),
    PoseDefinition(
      poseId: 'downward_dog_v2_02',
      order: 2,
      label: 'LIFT HIPS',
      instruction:
          'Press through your hands and lift your hips toward the ceiling.',
      approvedAsset: _downwardDogV2Asset('02_LIFT_HIPS'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.75,
    ),
    PoseDefinition(
      poseId: 'downward_dog_v2_03',
      order: 3,
      label: 'EXTEND LEGS',
      instruction: 'Lengthen your legs and send your hips back.',
      approvedAsset: _downwardDogV2Asset('03_EXTEND_LEGS'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.8,
    ),
    PoseDefinition(
      poseId: 'downward_dog_v2_04',
      order: 4,
      label: 'HOLD',
      instruction: 'Hold steady, pressing your heels toward the floor.',
      approvedAsset: _downwardDogV2Asset('04_HOLD'),
      purpose: PosePurpose.active,
      phaseSeconds: 1.0,
    ),
    PoseDefinition(
      poseId: 'downward_dog_v2_05',
      order: 5,
      label: 'LOWER KNEES',
      instruction: 'Lower your knees back down with control.',
      approvedAsset: _downwardDogV2Asset('05_LOWER_KNEES'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.65,
    ),
    PoseDefinition(
      poseId: 'downward_dog_v2_06',
      order: 6,
      label: 'RESET',
      instruction: 'Return to the starting position.',
      approvedAsset: _downwardDogV2Asset('06_RESET'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.6,
    ),
  ],
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.landscape,
  visualAspectRatio: 493 / 415, // real Downward Dog V2 frames
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: 'Next: Downward Dog.',
    benefit:
        'Downward Dog stretches your hamstrings, calves, and shoulders while building strength.',
    setupInstruction: 'Start on your hands and knees.',
    quarterCue: 'Press through your hands and lift your hips.',
    formCues: [
      'Lengthen your legs and send your hips back, holding steady as you breathe.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Nice work.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/warrior_i/female/v2/EX057_F_0N_*.png`. Same
/// provenance model as EX055/EX056: placed directly on disk, no Figma
/// node reference exists for this set — do not invent one. Human visual
/// approval completed prior to this implementation; frames are ~333-335 x
/// 351-352px (portrait, minor per-frame variance).
///
/// The third exercise in Morning Yoga Flow to get a real Tier 1
/// definition, after EX055 Sun Salutation and EX056 Downward Dog. Warrior
/// II/Tree Pose/Savasana remain intentionally unimplemented (no
/// catalogId, no Tier 1 definition) — see `_perExerciseRoutineFor` in
/// app_router.dart.
///
/// Loop order 01->02->03->04->05->06->(01...), a plain forward wrap, per
/// the approved sequence — [LoopMode.timedCycle] already produces this,
/// same mechanism as every other completed exercise. Standard
/// (non-phase-synced) [VoiceScript], same reasoning as EX056: the
/// suggested cues are instructional stepping cues, not breath-synced.
String _warriorIV2Asset(String file) =>
    'assets/glow_up/exercises/warrior_i/female/v2/EX057_F_$file.png';

final _warriorI = ExerciseDefinition(
  id: 'EX057',
  displayName: 'Warrior I',
  category: 'Flexibility',
  playbackType: 'REPS',
  bodyAreas: const ['Hips', 'Shoulders', 'Legs'],
  benefitShort:
      'Warrior I builds leg strength and opens your hips and shoulders.',
  durationSeconds: 40,
  reps: 5,
  poses: [
    PoseDefinition(
      poseId: 'warrior_i_v2_01',
      order: 1,
      label: 'START',
      instruction: 'Stand tall and prepare for Warrior One.',
      approvedAsset: _warriorIV2Asset('01_START'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.6,
    ),
    PoseDefinition(
      poseId: 'warrior_i_v2_02',
      order: 2,
      label: 'STEP BACK',
      instruction: 'Step one foot back and bend your front knee.',
      approvedAsset: _warriorIV2Asset('02_STEP_BACK'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.75,
    ),
    PoseDefinition(
      poseId: 'warrior_i_v2_03',
      order: 3,
      label: 'RAISE ARMS',
      instruction: 'Reach both arms overhead.',
      approvedAsset: _warriorIV2Asset('03_RAISE_ARMS'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.8,
    ),
    PoseDefinition(
      poseId: 'warrior_i_v2_04',
      order: 4,
      label: 'WARRIOR I HOLD',
      instruction: 'Hold Warrior One and breathe steadily.',
      approvedAsset: _warriorIV2Asset('04_WARRIOR_I_HOLD'),
      purpose: PosePurpose.active,
      phaseSeconds: 1.0,
    ),
    PoseDefinition(
      poseId: 'warrior_i_v2_05',
      order: 5,
      label: 'LOWER ARMS',
      instruction: 'Lower your arms with control.',
      approvedAsset: _warriorIV2Asset('05_LOWER_ARMS'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.65,
    ),
    PoseDefinition(
      poseId: 'warrior_i_v2_06',
      order: 6,
      label: 'RESET',
      instruction: 'Step forward and return to standing.',
      approvedAsset: _warriorIV2Asset('06_RESET'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.6,
    ),
  ],
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.portrait,
  visualAspectRatio: 333 / 352, // real Warrior I V2 frames
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: 'Next: Warrior I.',
    benefit: 'Warrior I builds leg strength and opens your hips and shoulders.',
    setupInstruction: 'Stand tall and prepare for Warrior One.',
    quarterCue: 'Step one foot back and bend your front knee.',
    formCues: [
      'Reach both arms overhead and hold steady as you breathe.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Nice work.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/warrior_ii/female/v2/EX058_F_0N_*.png`. Same
/// provenance model as EX055-EX057: placed directly on disk, no Figma
/// node reference exists for this set — do not invent one. Human visual
/// approval completed prior to this implementation; frames are ~329-347 x
/// 317-328px (near-square, minor per-frame variance).
///
/// The fourth exercise in Morning Yoga Flow to get a real Tier 1
/// definition, after EX055 Sun Salutation, EX056 Downward Dog, and EX057
/// Warrior I. Tree Pose/Savasana remain intentionally unimplemented (no
/// catalogId, no Tier 1 definition) — see `_perExerciseRoutineFor` in
/// app_router.dart.
///
/// Loop order 01->02->03->04->05->06->(01...), a plain forward wrap, per
/// the approved sequence — [LoopMode.timedCycle] already produces this,
/// same mechanism as every other completed exercise. Standard
/// (non-phase-synced) [VoiceScript], same reasoning as EX056/EX057: the
/// suggested cues are instructional stepping cues, not breath-synced.
String _warriorIIV2Asset(String file) =>
    'assets/glow_up/exercises/warrior_ii/female/v2/EX058_F_$file.png';

final _warriorII = ExerciseDefinition(
  id: 'EX058',
  displayName: 'Warrior II',
  category: 'Flexibility',
  playbackType: 'REPS',
  bodyAreas: const ['Hips', 'Shoulders', 'Legs'],
  benefitShort: 'Warrior II builds leg strength and opens your hips and chest.',
  durationSeconds: 40,
  reps: 5,
  poses: [
    PoseDefinition(
      poseId: 'warrior_ii_v2_01',
      order: 1,
      label: 'START',
      instruction: 'Stand tall and prepare for Warrior Two.',
      approvedAsset: _warriorIIV2Asset('01_START'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.6,
    ),
    PoseDefinition(
      poseId: 'warrior_ii_v2_02',
      order: 2,
      label: 'STEP WIDE',
      instruction: 'Step your feet wide apart and turn your front foot out.',
      approvedAsset: _warriorIIV2Asset('02_STEP_WIDE'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.75,
    ),
    PoseDefinition(
      poseId: 'warrior_ii_v2_03',
      order: 3,
      label: 'ARMS OUT',
      instruction: 'Bend your front knee and reach your arms out to the sides.',
      approvedAsset: _warriorIIV2Asset('03_ARMS_OUT'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.8,
    ),
    PoseDefinition(
      poseId: 'warrior_ii_v2_04',
      order: 4,
      label: 'WARRIOR II HOLD',
      instruction: 'Hold Warrior Two and breathe steadily.',
      approvedAsset: _warriorIIV2Asset('04_WARRIOR_II_HOLD'),
      purpose: PosePurpose.active,
      phaseSeconds: 1.0,
    ),
    PoseDefinition(
      poseId: 'warrior_ii_v2_05',
      order: 5,
      label: 'RELEASE ARMS',
      instruction: 'Lower your arms with control.',
      approvedAsset: _warriorIIV2Asset('05_RELEASE_ARMS'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.65,
    ),
    PoseDefinition(
      poseId: 'warrior_ii_v2_06',
      order: 6,
      label: 'RESET',
      instruction: 'Step forward and return to standing.',
      approvedAsset: _warriorIIV2Asset('06_RESET'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.6,
    ),
  ],
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.square,
  visualAspectRatio: 329 / 328, // real Warrior II V2 frames
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: 'Next: Warrior II.',
    benefit: 'Warrior II builds leg strength and opens your hips and chest.',
    setupInstruction: 'Stand tall and prepare for Warrior Two.',
    quarterCue: 'Step your feet wide apart and turn your front foot out.',
    formCues: [
      'Bend your front knee, reach your arms out, and hold steady as you breathe.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Nice work.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/tree_pose/female/v2/EX059_F_0N_*.png`.
/// Uniform 277x265 across all six frames (confirmed before renaming).
///
/// ID note: this exercise does NOT use "EX025" despite the source asset
/// batch/manifest originally being drafted with that id. EX025 is already
/// permanently assigned to "Hamstring Stretch" (Evening Stretch) — reusing
/// it here would create the exact same single-global-registry collision
/// documented on `_sunSalutation` for EX032. The six approved PNGs and
/// `manifest.json` were renamed/updated from `EX025_*` to `EX059_*`
/// (content bytes untouched, confirmed via unchanged file sizes) and
/// EX059 — the next free id after the existing EX001-EX058 range — was
/// assigned instead, mirroring EX053/EX054/EX055/EX057/EX058. EX025
/// "Hamstring Stretch" itself was not touched.
///
/// The fifth exercise in Morning Yoga Flow to get a real Tier 1
/// definition, after EX055-EX058. Savasana remains intentionally
/// unimplemented (no catalogId, no Tier 1 definition) — see
/// `_perExerciseRoutineFor` in app_router.dart.
///
/// Playback: the first live production use of [LoopMode.holdAfterSetup]
/// (previously declared in the engine but never actually used by a real
/// exercise). Frames 1-4 (START/WEIGHT_SHIFT/KNEE_LIFT/FOOT_PLACE) play
/// once, entering the pose over [loopCycleSeconds]; frame 5 (HOLD,
/// `PosePurpose.hold`) holds for the remainder of the exercise; frame 6
/// (RESET, `PosePurpose.finish`) plays for the final second as the
/// controlled exit. Never a repeating loop back to frame 1 mid-exercise —
/// this is a genuinely different shape from every other Flexibility
/// exercise so far, which is exactly why the pre-existing holdAfterSetup
/// mechanism (not timedCycle) is the correct fit, reused as designed
/// rather than building a new one.
///
/// Voice: standard (non-phase-synced) [VoiceScript], movement-only cues —
/// same reasoning as every exercise since EX056: no breath-paced
/// automation, since a single "Halfway there" style cue would not
/// reliably land on the hold phase's actual pacing.
///
/// Safety: approved asset frame 4/5 shows the raised foot placed on the
/// inner thigh, above the knee, matching the required safe-placement cue
/// (see `manifest.json`'s `safetyCue`) — this is real approved content,
/// not a placeholder, so the cue only needs to reinforce what the image
/// already shows.
String _treePoseV2Asset(String file) =>
    'assets/glow_up/exercises/tree_pose/female/v2/EX059_F_$file.png';

final _treePose = ExerciseDefinition(
  id: 'EX059',
  displayName: 'Tree Pose',
  category: 'Flexibility',
  playbackType: 'HOLD',
  bodyAreas: const ['Balance', 'Core', 'Legs'],
  benefitShort: 'Tree Pose builds balance, focus, and leg strength.',
  durationSeconds: 40,
  poses: [
    PoseDefinition(
      poseId: 'tree_pose_v2_01',
      order: 1,
      label: 'START',
      instruction: 'Stand tall with your feet together.',
      approvedAsset: _treePoseV2Asset('01_START'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.6,
    ),
    PoseDefinition(
      poseId: 'tree_pose_v2_02',
      order: 2,
      label: 'WEIGHT SHIFT',
      instruction: 'Shift your weight onto one leg.',
      approvedAsset: _treePoseV2Asset('02_WEIGHT_SHIFT'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'tree_pose_v2_03',
      order: 3,
      label: 'KNEE LIFT',
      instruction: 'Lift your other knee and open it to the side.',
      approvedAsset: _treePoseV2Asset('03_KNEE_LIFT'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.75,
    ),
    PoseDefinition(
      poseId: 'tree_pose_v2_04',
      order: 4,
      label: 'FOOT PLACE',
      instruction:
          'Place your foot on your inner thigh, above or below the knee — never on the knee joint.',
      approvedAsset: _treePoseV2Asset('04_FOOT_PLACE'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.75,
    ),
    PoseDefinition(
      poseId: 'tree_pose_v2_05',
      order: 5,
      label: 'HOLD',
      instruction:
          'Bring your hands together or reach them overhead. Hold and breathe steadily.',
      approvedAsset: _treePoseV2Asset('05_HOLD'),
      purpose: PosePurpose.hold,
    ),
    PoseDefinition(
      poseId: 'tree_pose_v2_06',
      order: 6,
      label: 'RESET',
      instruction: 'Lower your foot with control and return to standing.',
      approvedAsset: _treePoseV2Asset('06_RESET'),
      purpose: PosePurpose.finish,
    ),
  ],
  loopMode: LoopMode.holdAfterSetup,
  loopCycleSeconds:
      2.8, // sum of poses 1-4's phaseSeconds — the one-time entry into the hold
  visualOrientation: ExerciseVisualOrientation.landscape,
  visualAspectRatio: 277 / 265, // real Tree Pose V2 frames
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: 'Next: Tree Pose.',
    benefit: 'Tree Pose builds balance, focus, and leg strength.',
    setupInstruction: 'Stand tall and shift your weight onto one leg.',
    quarterCue: 'Place your foot on your inner thigh, above or below the knee.',
    formCues: [
      'Find a steady point ahead to focus on, and hold with control.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Nice work. Repeat on the other side.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/savasana/female/v2/EX060_F_0N_*.png`.
/// Uniform 277x265 across all six frames (confirmed before use).
///
/// The sixth and final exercise in Morning Yoga Flow to get a real Tier 1
/// definition — with this one implemented, every Morning Yoga exercise
/// now has a real Tier 1 definition, though that has no special routing
/// effect here (the `any`-catalogId gate in app_router.dart has been true
/// since EX055).
///
/// Category note: [ExerciseDefinition.category] is a single descriptive
/// string, not a multi-category taxonomy — set to 'Recovery' per the
/// explicit registration spec (Savasana's primary category); Flexibility
/// (its secondary category, and the category of the Morning Yoga workout
/// it lives in) isn't representable in this field. No secondary-category
/// data model exists anywhere in the app to extend safely, so this is
/// reported as a known gap rather than invented.
///
/// Playback: the second live use of [LoopMode.holdAfterSetup] (after
/// EX059 Tree Pose). Frames 1-4 (PREPARE/LOWER_TO_ELBOWS/LOWER_BACK/
/// EXTEND_LEGS, all non-hold/non-finish purpose) play once over
/// [loopCycleSeconds]; frame 5 (HOLD, `PosePurpose.hold`) holds for the
/// remainder of the 180s duration — never repeating frames 1-4, never a
/// "breathe in/breathe out" cycle; frame 6 (RECOVERY, `PosePurpose.finish`)
/// shows for the final second as the guided recovery stage, matching the
/// "roll onto one side before sitting up" instruction (spoken in
/// [VoiceScript.finishCue], never jumping straight to standing).
///
/// Voice: standard (non-phase-synced) [VoiceScript], same model as every
/// exercise since EX056 — same reasoning as Sun Salutation's fix: no
/// automated breathing narration. The safety cue (neutral neck, bend
/// knees or add support if the lower back is uncomfortable) is folded
/// into [VoiceScript.setupInstruction], spoken once before the hold
/// begins, never repeated mid-rest. The detailed modification list
/// (pregnancy/side-lying, dizziness, neck support) has no existing
/// on-screen "modifications" UI anywhere in the app to plug into — not
/// fabricated here; noted as a real gap, not silently dropped.
///
/// AI Coach post-exercise feedback ("How did Savasana feel?", quick
/// reasons, adaptive memory) is explicitly NOT implemented — that's the
/// Tell Coach / AI-memory initiative (new shared panels and services: a
/// TellCoachPanel, ExerciseFeedbackService, ExerciseMemoryClassifier)
/// that doesn't exist in this codebase yet. Building a one-off version
/// just for Savasana would be exactly the kind of duplicate/parallel
/// component this app's architecture explicitly avoids.
String _savasanaV2Asset(String file) =>
    'assets/glow_up/exercises/savasana/female/v2/EX060_F_$file.png';

final _savasana = ExerciseDefinition(
  id: 'EX060',
  displayName: 'Savasana',
  category: 'Recovery',
  playbackType: 'HOLD',
  bodyAreas: const ['Full Body', 'Nervous System'],
  benefitShort:
      'Savasana encourages full-body relaxation and helps your body transition into recovery.',
  durationSeconds: 180,
  poses: [
    PoseDefinition(
      poseId: 'savasana_v2_01',
      order: 1,
      label: 'PREPARE',
      instruction: 'Sit comfortably with your knees bent.',
      approvedAsset: _savasanaV2Asset('01_PREPARE'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'savasana_v2_02',
      order: 2,
      label: 'LOWER TO ELBOWS',
      instruction: 'Lower onto your forearms with control.',
      approvedAsset: _savasanaV2Asset('02_LOWER_TO_ELBOWS'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.8,
    ),
    PoseDefinition(
      poseId: 'savasana_v2_03',
      order: 3,
      label: 'LOWER BACK',
      instruction: 'Rest your head and back on the mat.',
      approvedAsset: _savasanaV2Asset('03_LOWER_BACK'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.8,
    ),
    PoseDefinition(
      poseId: 'savasana_v2_04',
      order: 4,
      label: 'EXTEND LEGS',
      instruction: 'Extend your legs and let your feet relax outward.',
      approvedAsset: _savasanaV2Asset('04_EXTEND_LEGS'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.9,
    ),
    PoseDefinition(
      poseId: 'savasana_v2_05',
      order: 5,
      label: 'HOLD',
      instruction: 'Allow your shoulders, hands, and jaw to soften.',
      approvedAsset: _savasanaV2Asset('05_HOLD'),
      purpose: PosePurpose.hold,
    ),
    PoseDefinition(
      poseId: 'savasana_v2_06',
      order: 6,
      label: 'RECOVERY',
      instruction:
          'Draw your knees in gently, then roll onto one side before sitting up.',
      approvedAsset: _savasanaV2Asset('06_RECOVERY'),
      purpose: PosePurpose.finish,
    ),
  ],
  loopMode: LoopMode.holdAfterSetup,
  loopCycleSeconds:
      3.2, // sum of poses 1-4's phaseSeconds — the one-time entry into the hold
  visualOrientation: ExerciseVisualOrientation.landscape,
  visualAspectRatio: 277 / 265, // real Savasana V2 frames
  crossfadeFrames: false,
  voiceScript: const VoiceScript(
    intro: 'Next: Savasana.',
    benefit:
        'Savasana encourages full-body relaxation and helps your body transition into recovery.',
    setupInstruction:
        'Sit comfortably, then lower onto your forearms, your back, and extend your legs with control. '
        'Keep your neck neutral, and bend your knees or add support if your lower back feels uncomfortable.',
    quarterCue: 'Allow your shoulders, hands, and jaw to soften.',
    formCues: [
      'Stay still and allow your body to rest.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue:
        'Begin bringing your awareness back. Draw your knees in gently, then roll onto one side before sitting up.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/full_body_stretch/female/v2/EX061_F_0N_*.png`.
/// Uniform 277x265 (confirmed before use).
///
/// ID note: "Full Body Stretch" already has an internal placeholder
/// definition at id `EX002` (`_fullBodyStretch` above — single pose,
/// `approvedAsset: null`, added purely so Bedtime Meditation's other five
/// exercises could resolve through RoutinePlayer before any of them had
/// real assets). This new, fully-verified definition intentionally does
/// NOT reuse EX002 — reusing it would let the real V2 asset silently
/// replace the meaning of an id that's still referenced by its own
/// dedicated tests as "the honestly-unverified placeholder." Assigned
/// EX061 instead — the next free id after the existing EX001-EX060 range
/// — mirroring exactly how EX055/EX056/EX057/EX058/EX059/EX060 were each
/// minted for real Morning Yoga content rather than reusing a
/// numerically-tempting but already-spoken-for id (EX032, EX025). EX002's
/// placeholder definition is left in place, untouched, and no longer
/// referenced by Bedtime Meditation (see the doc comment on
/// `bedtime-meditation` in workout_catalog.dart) — same "orphaned but not
/// deleted" treatment as EX025/EX032.
///
/// Playback: LoopMode.timedCycle, a plain repeating 6-frame loop — 2s +
/// 2s + 3s + 5s + 2s + 1s = 15.0s per cycle, three full cycles across the
/// 45s exercise (15*3=45 exactly, so the exercise always ends precisely
/// on frame 6/RESET, never mid-cycle — no special end-of-exercise frame
/// handling needed). Same forward-wrap mechanism as every other
/// timedCycle exercise, so 06->01 never flashes/restarts.
///
/// Voice: phase-synced (Deep Breathing's mechanism, now also used here) —
/// a cue repeats once per frame-entry, every cycle, matching the spec's
/// explicit "voice cues must be triggered by the exercise frame/state
/// controller, not an unrelated independent timer." NOT implemented: the
/// separate time-based "Halfway: keep the stretch comfortable..." cue —
/// phaseSyncedVoice suppresses the generic once-per-exercise halfway
/// mechanism (same reasoning as Savasana's halfway-cue gap), and elapsed
/// 22.5s (the real halfway point) falls within FULL_STRETCH_HOLD's
/// territory anyway, which already gets its own frame cue covering
/// similar ground ("Lengthen from your fingertips to your heels.").
String _fullBodyStretchV2Asset(String file) =>
    'assets/glow_up/exercises/full_body_stretch/female/v2/EX061_F_$file.png';

final _fullBodyStretchV2 = ExerciseDefinition(
  id: 'EX061',
  displayName: 'Full Body Stretch',
  category: 'Bedtime',
  playbackType: 'SEQUENCE_LOOP',
  bodyAreas: const [
    'Shoulders',
    'Upper Back',
    'Chest',
    'Abdominals',
    'Hips',
    'Legs',
    'Ankles',
  ],
  benefitShort:
      'Full Body Stretch gently lengthens your whole body and releases tension before sleep.',
  durationSeconds: 45,
  poses: [
    PoseDefinition(
      poseId: 'full_body_stretch_v2_01',
      order: 1,
      label: 'LIE BACK',
      instruction:
          'Lie on your back with your knees bent, feet flat and hip-width.',
      approvedAsset: _fullBodyStretchV2Asset('01_LIE_BACK'),
      purpose: PosePurpose.setup,
      phaseSeconds: 2,
    ),
    PoseDefinition(
      poseId: 'full_body_stretch_v2_02',
      order: 2,
      label: 'EXTEND LEGS',
      instruction:
          'Extend both legs slowly, keeping your head and spine neutral.',
      approvedAsset: _fullBodyStretchV2Asset('02_EXTEND_LEGS'),
      purpose: PosePurpose.transition,
      phaseSeconds: 2,
      voiceCue: 'Extend your legs gently.',
      cuesOnlyVoiceCue: 'Extend legs.',
    ),
    PoseDefinition(
      poseId: 'full_body_stretch_v2_03',
      order: 3,
      label: 'REACH OVERHEAD',
      instruction: 'Sweep both arms overhead, keeping your shoulders relaxed.',
      approvedAsset: _fullBodyStretchV2Asset('03_REACH_OVERHEAD'),
      purpose: PosePurpose.transition,
      phaseSeconds: 3,
      voiceCue: 'Reach your arms overhead.',
      cuesOnlyVoiceCue: 'Reach overhead.',
    ),
    PoseDefinition(
      poseId: 'full_body_stretch_v2_04',
      order: 4,
      label: 'FULL STRETCH HOLD',
      instruction:
          'Reach your fingertips and heels in opposite directions — keep it gentle, never forcing your lower back to arch.',
      approvedAsset: _fullBodyStretchV2Asset('04_FULL_STRETCH_HOLD'),
      purpose: PosePurpose.active,
      phaseSeconds: 5,
      voiceCue: 'Lengthen from your fingertips to your heels.',
      cuesOnlyVoiceCue: 'Lengthen.',
    ),
    PoseDefinition(
      poseId: 'full_body_stretch_v2_05',
      order: 5,
      label: 'RELEASE',
      instruction:
          'Release your arms slowly in a wide arc, letting your shoulders soften.',
      approvedAsset: _fullBodyStretchV2Asset('05_RELEASE'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 2,
      voiceCue: 'Release slowly.',
      cuesOnlyVoiceCue: 'Release.',
    ),
    PoseDefinition(
      poseId: 'full_body_stretch_v2_06',
      order: 6,
      label: 'RESET',
      instruction: 'Bend both knees and return your feet to the floor.',
      approvedAsset: _fullBodyStretchV2Asset('06_RESET'),
      purpose: PosePurpose.transition,
      phaseSeconds: 1,
      voiceCue: 'Bend your knees and stay on your back for the next movement.',
      cuesOnlyVoiceCue: 'Bend knees.',
    ),
  ],
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.square,
  visualAspectRatio: 277 / 265, // real Full Body Stretch V2 frames
  crossfadeFrames: false,
  phaseSyncedVoice:
      true, // frame-synced repeating movement cues — see doc comment above
  voiceScript: const VoiceScript(
    intro: 'Next: Full Body Stretch.',
    benefit:
        'Full Body Stretch gently lengthens your whole body and releases tension before sleep.',
    setupInstruction:
        'Lie back and let your body settle. Lengthen gently without forcing the lower back to arch — '
        'bend your knees if your back feels uncomfortable.',
    finishCue: 'Full Body Stretch complete.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/knee_to_chest/female/v2/EX062_F_0N_*.png`.
/// Uniform 277x265 (confirmed before use).
///
/// ID note: "Knee-to-Chest" already has an internal placeholder at id
/// `EX003` (`_kneeToChest` above) — same situation as EX002/EX061
/// (Full Body Stretch): a real, approved right+left bilateral sequence
/// exists now, so it's assigned the next free id, EX062, rather than
/// upgrading EX003 in place. EX003 is left as-is except its displayName
/// (see that definition's doc comment) and no longer referenced by
/// Bedtime Meditation.
///
/// Playback: LoopMode.timedCycle with phaseSeconds summing to exactly
/// 40.0s (the full exercise duration) — right side (START/RIGHT_KNEE_LIFT/
/// RIGHT_HOLD = 3+3+14 = 20s) then left side (CENTER_RESET/LEFT_KNEE_LIFT/
/// LEFT_HOLD = 3+3+14 = 20s), matching the manifest's
/// `sideDurationSeconds: 20`. Because the cycle length equals the whole
/// duration, elapsed never reaches a second lap within the exercise — the
/// sequence plays exactly once, never loops, using the existing timedCycle
/// mechanism as-is rather than a new "play once" LoopMode.
///
/// Voice: standard (non-phase-synced) VoiceScript, using
/// [VoiceScript.switchSideCue] (the same mechanism Lunges already uses)
/// so "switch sides" fires automatically at the real halfway point
/// (20s/50%) — right when CENTER_RESET begins. No phaseSyncedVoice, no
/// per-pose voiceCue, no repeating "breathe in/out" of any kind.
String _kneeToChestV2Asset(String file) =>
    'assets/glow_up/exercises/knee_to_chest/female/v2/EX062_F_$file.png';

final _kneeToChestV2 = ExerciseDefinition(
  id: 'EX062',
  displayName: 'Knee-to-Chest',
  category: 'Bedtime',
  playbackType: 'SIDE_SEQUENCE',
  bodyAreas: const ['Hips', 'Lower Back'],
  benefitShort:
      'Knee-to-Chest gently releases tension in your hips and lower back.',
  durationSeconds: 40,
  poses: [
    PoseDefinition(
      poseId: 'knee_to_chest_v2_01',
      order: 1,
      label: 'START',
      instruction: 'Lie on your back with both knees bent, feet flat.',
      approvedAsset: _kneeToChestV2Asset('01_START'),
      purpose: PosePurpose.setup,
      phaseSeconds: 3,
    ),
    PoseDefinition(
      poseId: 'knee_to_chest_v2_02',
      order: 2,
      label: 'RIGHT KNEE LIFT',
      instruction: 'Gently draw your right knee toward your chest.',
      approvedAsset: _kneeToChestV2Asset('02_RIGHT_KNEE_LIFT'),
      purpose: PosePurpose.transition,
      phaseSeconds: 3,
    ),
    PoseDefinition(
      poseId: 'knee_to_chest_v2_03',
      order: 3,
      label: 'RIGHT HOLD',
      instruction:
          'Hold behind your thigh or across your shin — never pull directly on the kneecap.',
      approvedAsset: _kneeToChestV2Asset('03_RIGHT_HOLD'),
      purpose: PosePurpose.active,
      phaseSeconds: 14,
    ),
    PoseDefinition(
      poseId: 'knee_to_chest_v2_04',
      order: 4,
      label: 'CENTER RESET',
      instruction: 'Lower your right leg back down to center.',
      approvedAsset: _kneeToChestV2Asset('04_CENTER_RESET'),
      purpose: PosePurpose.switchSide,
      phaseSeconds: 3,
    ),
    PoseDefinition(
      poseId: 'knee_to_chest_v2_05',
      order: 5,
      label: 'LEFT KNEE LIFT',
      instruction: 'Gently draw your left knee toward your chest.',
      approvedAsset: _kneeToChestV2Asset('05_LEFT_KNEE_LIFT'),
      purpose: PosePurpose.transition,
      phaseSeconds: 3,
    ),
    PoseDefinition(
      poseId: 'knee_to_chest_v2_06',
      order: 6,
      label: 'LEFT HOLD',
      instruction:
          'Hold behind your thigh or across your shin, keeping your head, shoulders and pelvis relaxed.',
      approvedAsset: _kneeToChestV2Asset('06_LEFT_HOLD'),
      purpose: PosePurpose.active,
      phaseSeconds: 14,
    ),
  ],
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.square,
  visualAspectRatio: 277 / 265, // real Knee-to-Chest V2 frames
  crossfadeFrames: false,
  thumbnailFrameOrder:
      3, // approved routine-card thumbnail is RIGHT_HOLD, not the neutral start
  voiceScript: const VoiceScript(
    intro: 'Next: Knee-to-Chest.',
    benefit:
        'Knee-to-Chest gently releases tension in your hips and lower back.',
    setupInstruction: 'Gently draw your right knee toward your chest.',
    switchSideCue: 'Switch sides — now draw your left knee toward your chest.',
    finishCue: 'Done.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/supine_twist/female/v2/EX063_F_0N_*.png`.
/// Uniform 277x265 (confirmed before use).
///
/// ID note: same situation as EX062 above — "Supine Twist" already has an
/// internal placeholder at id `EX004` (`_supineTwist` above); this real,
/// approved bilateral sequence is assigned the next free id, EX063,
/// rather than upgrading EX004 in place.
///
/// Playback/timing/voice: same shape as EX062, with the exact per-frame
/// seconds and cue wording specified in the approved manifest.json
/// (3+3+14+3+3+14 = 40.0s, right twist held first, then left) —
/// LoopMode.timedCycle with a 40.0s cycle so the sequence plays exactly
/// once, never loops. Standard VoiceScript with switchSideCue firing at
/// the real halfway point (20s), no phaseSyncedVoice.
String _supineTwistV2Asset(String file) =>
    'assets/glow_up/exercises/supine_twist/female/v2/EX063_F_$file.png';

final _supineTwistV2 = ExerciseDefinition(
  id: 'EX063',
  displayName: 'Supine Twist',
  category: 'Bedtime',
  playbackType: 'SIDE_SEQUENCE',
  bodyAreas: const ['Spine', 'Lower Back'],
  benefitShort: 'Supine Twist releases tension along your spine before sleep.',
  durationSeconds: 40,
  poses: [
    PoseDefinition(
      poseId: 'supine_twist_v2_01',
      order: 1,
      label: 'START',
      instruction: 'Lie on your back, bend your knees, and open your arms.',
      approvedAsset: _supineTwistV2Asset('01_START'),
      purpose: PosePurpose.setup,
      phaseSeconds: 3,
    ),
    PoseDefinition(
      poseId: 'supine_twist_v2_02',
      order: 2,
      label: 'KNEES TOGETHER',
      instruction: 'Bring your knees together and gently lift them.',
      approvedAsset: _supineTwistV2Asset('02_KNEES_TOGETHER'),
      purpose: PosePurpose.transition,
      phaseSeconds: 3,
    ),
    PoseDefinition(
      poseId: 'supine_twist_v2_03',
      order: 3,
      label: 'RIGHT TWIST HOLD',
      instruction:
          'Lower both knees to the right. Keep both shoulders grounded.',
      approvedAsset: _supineTwistV2Asset('03_RIGHT_TWIST_HOLD'),
      purpose: PosePurpose.active,
      phaseSeconds: 14,
    ),
    PoseDefinition(
      poseId: 'supine_twist_v2_04',
      order: 4,
      label: 'CENTER RESET',
      instruction: 'Return your knees slowly to center.',
      approvedAsset: _supineTwistV2Asset('04_CENTER_RESET'),
      purpose: PosePurpose.switchSide,
      phaseSeconds: 3,
    ),
    PoseDefinition(
      poseId: 'supine_twist_v2_05',
      order: 5,
      label: 'LEFT TWIST',
      instruction: 'Lower both knees gently to the left.',
      approvedAsset: _supineTwistV2Asset('05_LEFT_TWIST'),
      purpose: PosePurpose.transition,
      phaseSeconds: 3,
    ),
    PoseDefinition(
      poseId: 'supine_twist_v2_06',
      order: 6,
      label: 'LEFT TWIST HOLD',
      instruction:
          'Hold the left twist with both shoulders relaxed on the floor.',
      approvedAsset: _supineTwistV2Asset('06_LEFT_TWIST_HOLD'),
      purpose: PosePurpose.active,
      phaseSeconds: 14,
    ),
  ],
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.square,
  visualAspectRatio: 277 / 265, // real Supine Twist V2 frames
  crossfadeFrames: false,
  thumbnailFrameOrder:
      3, // approved routine-card thumbnail is RIGHT_TWIST_HOLD, not the neutral start
  voiceScript: const VoiceScript(
    intro: 'Next: Supine Twist.',
    benefit: 'Supine Twist releases tension along your spine before sleep.',
    setupInstruction: 'Lower your knees gently to the right.',
    switchSideCue: 'Return to center. Now lower your knees to the left.',
    finishCue: 'Done.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/ankle_circles/female/v2/EX064_F_0N_*.png`.
/// Uniform 277x265 (confirmed before use).
///
/// ID note: "Ankle Circles" already has an internal placeholder at id
/// `EX005` (`_ankleCircles` below) — same situation as EX062/EX063:
/// assigned the next free id (EX064) rather than upgrading EX005 in
/// place. EX005 is left as-is except its displayName.
///
/// Playback/voice: same shape as EX062/EX063 — LoopMode.timedCycle with
/// phaseSeconds taken exactly from the approved manifest
/// (2+6+6+2+7+7=30.0s, matching durationSeconds so the sequence plays
/// exactly once, never loops), right ankle completes before left ankle
/// begins, standard VoiceScript with switchSideCue firing at the real
/// halfway point, no phaseSyncedVoice, no breathing narration.
String _ankleCirclesV2Asset(String file) =>
    'assets/glow_up/exercises/ankle_circles/female/v2/EX064_F_$file.png';

final _ankleCirclesV2 = ExerciseDefinition(
  id: 'EX064',
  displayName: 'Ankle Circles',
  category: 'Bedtime',
  playbackType: 'SIDE_SEQUENCE',
  bodyAreas: const ['Ankles'],
  benefitShort: 'Ankle Circles gently mobilizes your ankles before sleep.',
  durationSeconds: 30,
  poses: [
    PoseDefinition(
      poseId: 'ankle_circles_v2_01',
      order: 1,
      label: 'START',
      instruction: 'Sit tall with both legs extended and ankles relaxed.',
      approvedAsset: _ankleCirclesV2Asset('01_START'),
      purpose: PosePurpose.setup,
      phaseSeconds: 2,
    ),
    PoseDefinition(
      poseId: 'ankle_circles_v2_02',
      order: 2,
      label: 'RIGHT ANKLE FLEX',
      instruction:
          'Circle your right ankle slowly through a comfortable range.',
      approvedAsset: _ankleCirclesV2Asset('02_RIGHT_ANKLE_FLEX'),
      purpose: PosePurpose.transition,
      phaseSeconds: 6,
    ),
    PoseDefinition(
      poseId: 'ankle_circles_v2_03',
      order: 3,
      label: 'RIGHT ANKLE POINT',
      instruction: 'Continue the right ankle circles without moving your knee.',
      approvedAsset: _ankleCirclesV2Asset('03_RIGHT_ANKLE_POINT'),
      purpose: PosePurpose.active,
      phaseSeconds: 6,
    ),
    PoseDefinition(
      poseId: 'ankle_circles_v2_04',
      order: 4,
      label: 'CENTER RESET',
      instruction: 'Return both ankles to neutral.',
      approvedAsset: _ankleCirclesV2Asset('04_CENTER_RESET'),
      purpose: PosePurpose.switchSide,
      phaseSeconds: 2,
    ),
    PoseDefinition(
      poseId: 'ankle_circles_v2_05',
      order: 5,
      label: 'LEFT ANKLE FLEX',
      instruction: 'Circle your left ankle slowly through a comfortable range.',
      approvedAsset: _ankleCirclesV2Asset('05_LEFT_ANKLE_FLEX'),
      purpose: PosePurpose.transition,
      phaseSeconds: 7,
    ),
    PoseDefinition(
      poseId: 'ankle_circles_v2_06',
      order: 6,
      label: 'LEFT ANKLE POINT',
      instruction:
          'Finish the left ankle circles while keeping the knee still.',
      approvedAsset: _ankleCirclesV2Asset('06_LEFT_ANKLE_POINT'),
      purpose: PosePurpose.active,
      phaseSeconds: 7,
    ),
  ],
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.square,
  visualAspectRatio: 277 / 265, // real Ankle Circles V2 frames
  crossfadeFrames: false,
  thumbnailFrameOrder: 2, // approved routine-card thumbnail is RIGHT_ANKLE_FLEX
  voiceScript: const VoiceScript(
    intro: 'Next: Ankle Circles.',
    benefit: 'Ankle Circles gently mobilizes your ankles before sleep.',
    setupInstruction:
        'Sit tall and relax your legs. Circle your right ankle slowly.',
    switchSideCue: 'Return to center. Now circle your left ankle.',
    finishCue: 'Done.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/sit_up_reach/female/v2/EX065_F_0N_*.png`.
/// Uniform 277x265 (confirmed before use).
///
/// ID note: "Sit-Up Reach" already has an internal placeholder at id
/// `EX006` (`_sitUpReach` below) — assigned the next free id (EX065)
/// rather than upgrading EX006 in place. EX006 is left as-is except its
/// displayName.
///
/// Playback: LoopMode.timedCycle, a standard REPS-style repeating loop —
/// same mechanism as Squat/Cat-Cow, NOT a new "counted reps with early
/// stop" mechanism (no live rep-counter exists anywhere in RoutinePlayer
/// today — `reps` is descriptive-only everywhere else in the app too).
/// Weighted 0.5+0.6+0.7+0.9+0.7+0.6=4.0s/cycle x 10 cycles = 40.0s,
/// matching the approved `targetReps: 10` / `durationSeconds: 40` as a
/// TIMING design (10 reps' worth of motion fit the 40s window), not an
/// actual counted/announced/early-terminating repetition tracker — that
/// would need new engine state and is flagged as a real gap, not built
/// here. Standard VoiceScript (no phaseSyncedVoice) — same reasoning as
/// every other REPS exercise, and no breathing narration.
String _sitUpReachV2Asset(String file) =>
    'assets/glow_up/exercises/sit_up_reach/female/v2/EX065_F_$file.png';

final _sitUpReachV2 = ExerciseDefinition(
  id: 'EX065',
  displayName: 'Sit-Up Reach',
  category: 'Bedtime',
  playbackType: 'REPS',
  bodyAreas: const ['Core', 'Neck'],
  benefitShort: 'Sit-Up Reach gently strengthens your core before sleep.',
  durationSeconds: 40,
  reps: 10,
  poses: [
    PoseDefinition(
      poseId: 'sit_up_reach_v2_01',
      order: 1,
      label: 'START',
      instruction: 'Lie back with knees bent, feet flat and arms overhead.',
      approvedAsset: _sitUpReachV2Asset('01_START'),
      purpose: PosePurpose.setup,
      phaseSeconds: 0.5,
    ),
    PoseDefinition(
      poseId: 'sit_up_reach_v2_02',
      order: 2,
      label: 'ARMS FORWARD',
      instruction: 'Sweep your arms forward and gently lift your shoulders.',
      approvedAsset: _sitUpReachV2Asset('02_ARMS_FORWARD'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.6,
    ),
    PoseDefinition(
      poseId: 'sit_up_reach_v2_03',
      order: 3,
      label: 'LIFT',
      instruction: 'Continue lifting with control and keep your feet grounded.',
      approvedAsset: _sitUpReachV2Asset('03_LIFT'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'sit_up_reach_v2_04',
      order: 4,
      label: 'FULL REACH',
      instruction:
          'Reach toward your knees or shins without pulling your neck.',
      approvedAsset: _sitUpReachV2Asset('04_FULL_REACH'),
      purpose: PosePurpose.active,
      phaseSeconds: 0.9,
    ),
    PoseDefinition(
      poseId: 'sit_up_reach_v2_05',
      order: 5,
      label: 'CONTROLLED LOWER',
      instruction: 'Lower slowly through the middle position.',
      approvedAsset: _sitUpReachV2Asset('05_CONTROLLED_LOWER'),
      purpose: PosePurpose.returnPhase,
      phaseSeconds: 0.7,
    ),
    PoseDefinition(
      poseId: 'sit_up_reach_v2_06',
      order: 6,
      label: 'RESET',
      instruction: 'Return gently to the start and prepare for the next rep.',
      approvedAsset: _sitUpReachV2Asset('06_RESET'),
      purpose: PosePurpose.transition,
      phaseSeconds: 0.6,
    ),
  ],
  loopMode: LoopMode.timedCycle,
  visualOrientation: ExerciseVisualOrientation.square,
  visualAspectRatio: 277 / 265, // real Sit-Up Reach V2 frames
  crossfadeFrames: false,
  thumbnailFrameOrder: 4, // approved routine-card thumbnail is FULL_REACH
  voiceScript: const VoiceScript(
    intro: 'Next: Sit-Up Reach.',
    benefit: 'Sit-Up Reach gently strengthens your core before sleep.',
    setupInstruction:
        'Keep your feet grounded. Sweep your arms forward and lift with control.',
    quarterCue: 'Reach toward your knees or shins without pulling your neck.',
    formCues: [
      'Lower slowly and keep your neck neutral.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Done.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/legs_up_wall/female/v2/EX066_F_0N_*.png`.
/// Uniform 277x265 (confirmed before use), same dimensions as Tree Pose/
/// Savasana.
///
/// ID note: "Legs Up Wall" already has an internal placeholder at id
/// `EX032` (`_fullBodyStretch`... no — see `exercise_catalog.dart`'s EX032
/// entry). Assigned the next free id (EX066, after EX065 Sit-Up Reach)
/// rather than upgrading EX032 in place, exactly mirroring how EX055
/// Sun Salutation was minted instead of reusing EX032's number for a
/// different exercise (see that doc comment) — EX032 "Legs Up Wall"
/// itself is untouched.
///
/// Playback: third live use of [LoopMode.holdAfterSetup] (after EX059 Tree
/// Pose and EX060 Savasana). Frames 1-3 (PREPARE/LOWER_AND_TURN/LEGS_UP,
/// non-hold/non-finish) play once over [loopCycleSeconds] (2+5+3=10s);
/// frame 4 (HOLD, `PosePurpose.hold`) holds for the remainder — never a
/// repeating loop, never re-animating in and out of the hold; frames 5-6
/// (BEND_KNEES_EXIT/RECOVERY, both `PosePurpose.finish`) play for their
/// own declared 3s/2s in the final 5 seconds, per the approved 2/5/3/45/
/// 3/2 = 60s split. This is the first exercise whose finish stage needs
/// more than one un-timed frame, which is why [PoseDefinition.phaseSeconds]
/// is now set on finish poses too and `currentPoseFor`'s holdAfterSetup
/// branch sums real per-pose seconds instead of assuming a flat 1s each —
/// a backward-compatible engine fix (Tree Pose/Savasana's single untimed
/// finish pose still gets exactly 1 second, unchanged).
///
/// Voice: standard (non-phase-synced) [VoiceScript] — no automated
/// breathing narration, same reasoning as every hold exercise since
/// EX059. The wall-distance/knee-bend safety notes live in
/// [VoiceScript.setupInstruction] and [VoiceScript.formCues], spoken once,
/// never repeated mid-hold.
///
/// AI Coach post-exercise feedback (hamstring tension, back comfort,
/// tingling/dizziness) is captured by the Tier 2 `WorkoutRestScreen` flow
/// (see `ExerciseReflectionCard` in workout land — logged through the
/// existing [WorkoutSignalLog] seam, the app's one real analytics/Brain
/// intake point) rather than a new bespoke Tier 1 panel, since Deep Sleep
/// Prep still runs on Tier 2 today (see the doc comment on the
/// `deep-sleep-prep` [Workout] in workout_catalog.dart for why).
String _legsUpWallV2Asset(String file) =>
    'assets/glow_up/exercises/legs_up_wall/female/v2/EX066_F_$file.png';

final _legsUpWallV2 = ExerciseDefinition(
  id: 'EX066',
  displayName: 'Legs Up Wall',
  category: 'Bedtime',
  playbackType: 'HOLD',
  bodyAreas: const ['Legs', 'Lower Back', 'Nervous System'],
  benefitShort:
      'Legs Up Wall relieves tired legs and calms your body before sleep.',
  durationSeconds: 60,
  poses: [
    PoseDefinition(
      poseId: 'legs_up_wall_v2_01',
      order: 1,
      label: 'PREPARE',
      instruction: 'Sit sideways with one hip close to the wall.',
      approvedAsset: _legsUpWallV2Asset('01_PREPARE'),
      purpose: PosePurpose.setup,
      phaseSeconds: 2,
    ),
    PoseDefinition(
      poseId: 'legs_up_wall_v2_02',
      order: 2,
      label: 'LOWER AND TURN',
      instruction: 'Lower onto your back and bring your feet onto the wall.',
      approvedAsset: _legsUpWallV2Asset('02_LOWER_AND_TURN'),
      purpose: PosePurpose.transition,
      phaseSeconds: 5,
    ),
    PoseDefinition(
      poseId: 'legs_up_wall_v2_03',
      order: 3,
      label: 'LEGS UP',
      instruction: 'Straighten your legs comfortably up the wall.',
      approvedAsset: _legsUpWallV2Asset('03_LEGS_UP'),
      purpose: PosePurpose.transition,
      phaseSeconds: 3,
    ),
    PoseDefinition(
      poseId: 'legs_up_wall_v2_04',
      order: 4,
      label: 'HOLD',
      instruction:
          'Relax your shoulders, soften your knees and remain comfortable.',
      approvedAsset: _legsUpWallV2Asset('04_HOLD'),
      purpose: PosePurpose.hold,
    ),
    PoseDefinition(
      poseId: 'legs_up_wall_v2_05',
      order: 5,
      label: 'BEND KNEES EXIT',
      instruction: 'Bend your knees and roll gently to one side.',
      approvedAsset: _legsUpWallV2Asset('05_BEND_KNEES_EXIT'),
      purpose: PosePurpose.finish,
      phaseSeconds: 3,
    ),
    PoseDefinition(
      poseId: 'legs_up_wall_v2_06',
      order: 6,
      label: 'RECOVERY',
      instruction: 'Return slowly to a comfortable seated position.',
      approvedAsset: _legsUpWallV2Asset('06_RECOVERY'),
      purpose: PosePurpose.finish,
      phaseSeconds: 2,
    ),
  ],
  loopMode: LoopMode.holdAfterSetup,
  loopCycleSeconds: 10, // sum of poses 1-3's phaseSeconds (2+5+3)
  visualOrientation: ExerciseVisualOrientation.landscape,
  visualAspectRatio: 277 / 265, // real Legs Up Wall V2 frames
  crossfadeFrames: false,
  thumbnailFrameOrder: 4, // approved routine-card thumbnail is HOLD
  voiceScript: const VoiceScript(
    intro: 'Next: Legs Up Wall.',
    benefit: 'Legs Up Wall relieves tired legs and calms your body before sleep.',
    setupInstruction:
        'Sit sideways with one hip close to the wall, then lower onto your back and bring your feet up.',
    quarterCue: 'Straighten your legs comfortably up the wall.',
    formCues: [
      'Relax your shoulders and soften your knees. Move away from the wall if your hamstrings pull.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Bend your knees and roll gently to one side before sitting up.',
  ),
);

/// Real, individually-verified production frames at
/// `assets/glow_up/exercises/reclined_butterfly/female/v2/EX067_F_0N_*.png`.
/// Uniform 277x265 (confirmed before use), same dimensions/provenance
/// model as EX066 Legs Up Wall, registered alongside it.
///
/// ID note: "Reclined Butterfly" already has an internal placeholder at id
/// `EX033` in `exercise_catalog.dart` — assigned the next free id (EX067,
/// after EX066) rather than upgrading EX033 in place, same reasoning as
/// EX066's doc comment. EX033 itself is untouched.
///
/// Playback: fourth live use of [LoopMode.holdAfterSetup]. Frames 1-3
/// (PREPARE/OPEN_KNEES/SETTLE) play once over [loopCycleSeconds]
/// (3+5+3=11s); frame 4 (HOLD) holds for the remainder; frames 5-6
/// (CLOSE_KNEES/RESET, both `PosePurpose.finish`) play for their own
/// declared 3s/2s in the final 5 seconds — 3/5/3/44/3/2 = 60s, using the
/// same per-pose finish-timing engine fix as EX066. The approved HOLD
/// frame is never animated forcing the knees down (per the safety note on
/// `manifest.json`) — CLOSE_KNEES explicitly narrates using the hands if
/// needed, never an automatic downward motion.
///
/// Voice: standard (non-phase-synced) [VoiceScript], no breathing
/// narration, same as EX066.
///
/// AI Coach post-exercise feedback (hip/groin/knee/lower-back comfort,
/// support used) — same Tier 2 [WorkoutSignalLog] integration as EX066,
/// see that doc comment.
String _reclinedButterflyV2Asset(String file) =>
    'assets/glow_up/exercises/reclined_butterfly/female/v2/EX067_F_$file.png';

final _reclinedButterflyV2 = ExerciseDefinition(
  id: 'EX067',
  displayName: 'Reclined Butterfly',
  category: 'Bedtime',
  playbackType: 'HOLD',
  bodyAreas: const ['Hips', 'Groin', 'Lower Back'],
  benefitShort:
      'Reclined Butterfly gently opens your hips and relaxes your body before sleep.',
  durationSeconds: 60,
  poses: [
    PoseDefinition(
      poseId: 'reclined_butterfly_v2_01',
      order: 1,
      label: 'PREPARE',
      instruction: 'Lie on your back with knees bent and feet flat.',
      approvedAsset: _reclinedButterflyV2Asset('01_PREPARE'),
      purpose: PosePurpose.setup,
      phaseSeconds: 3,
    ),
    PoseDefinition(
      poseId: 'reclined_butterfly_v2_02',
      order: 2,
      label: 'OPEN KNEES',
      instruction:
          'Bring the soles of your feet together and let your knees open gently.',
      approvedAsset: _reclinedButterflyV2Asset('02_OPEN_KNEES'),
      purpose: PosePurpose.transition,
      phaseSeconds: 5,
    ),
    PoseDefinition(
      poseId: 'reclined_butterfly_v2_03',
      order: 3,
      label: 'SETTLE',
      instruction: 'Relax your hips and support the thighs if needed.',
      approvedAsset: _reclinedButterflyV2Asset('03_SETTLE'),
      purpose: PosePurpose.transition,
      phaseSeconds: 3,
    ),
    PoseDefinition(
      poseId: 'reclined_butterfly_v2_04',
      order: 4,
      label: 'HOLD',
      instruction:
          'Stay within a comfortable range without pressing the knees down.',
      approvedAsset: _reclinedButterflyV2Asset('04_HOLD'),
      purpose: PosePurpose.hold,
    ),
    PoseDefinition(
      poseId: 'reclined_butterfly_v2_05',
      order: 5,
      label: 'CLOSE KNEES',
      instruction:
          'Use your hands if needed and bring your knees together slowly.',
      approvedAsset: _reclinedButterflyV2Asset('05_CLOSE_KNEES'),
      purpose: PosePurpose.finish,
      phaseSeconds: 3,
    ),
    PoseDefinition(
      poseId: 'reclined_butterfly_v2_06',
      order: 6,
      label: 'RESET',
      instruction: 'Return both feet to a comfortable neutral position.',
      approvedAsset: _reclinedButterflyV2Asset('06_RESET'),
      purpose: PosePurpose.finish,
      phaseSeconds: 2,
    ),
  ],
  loopMode: LoopMode.holdAfterSetup,
  loopCycleSeconds: 11, // sum of poses 1-3's phaseSeconds (3+5+3)
  visualOrientation: ExerciseVisualOrientation.landscape,
  visualAspectRatio: 277 / 265, // real Reclined Butterfly V2 frames
  crossfadeFrames: false,
  thumbnailFrameOrder: 4, // approved routine-card thumbnail is HOLD
  voiceScript: const VoiceScript(
    intro: 'Next: Reclined Butterfly.',
    benefit: 'Reclined Butterfly gently opens your hips and relaxes your body before sleep.',
    setupInstruction:
        'Lie on your back, bring the soles of your feet together, and let your knees open gently.',
    quarterCue: 'Relax your hips and support your thighs if needed.',
    formCues: [
      'Stay within a comfortable range. Never press your knees toward the floor.',
    ], // the "Halfway there." prefix is added by VoiceCoach itself
    finishCue: 'Use your hands if needed and bring your knees together slowly.',
  ),
);

final List<ExerciseDefinition> _kRoutinePlayerAll = [
  ...kRoutinePlayerPhase1Qa,
  _bicycleCrunch,
  _legRaises,
  _russianTwist,
  _birdDog,
  _fullBodyStretch,
  _kneeToChest,
  _supineTwist,
  _ankleCircles,
  _sitUpReach,
  _sideLungeLeft,
  _fireHydrant,
  _calfRaises,
  _wallPushUps,
  _tricepDips,
  _donkeyKicks,
  _shoulderTaps,
  _superman,
  _hamstringStretch,
  _quadStretch,
  _butterflyStretch,
  _childsPose,
  _cobraStretch,
  _hipFlexorStretch,
  _catCow,
  _sunSalutation,
  _downwardDog,
  _warriorI,
  _warriorII,
  _treePose,
  _savasana,
  _fullBodyStretchV2,
  _kneeToChestV2,
  _supineTwistV2,
  _ankleCirclesV2,
  _sitUpReachV2,
  _legsUpWallV2,
  _reclinedButterflyV2,
];

/// Canonical id -> [ExerciseDefinition] lookup, covering every exercise
/// RoutinePlayer knows about (the 9 in [kRoutinePlayerPhase1Qa] plus
/// EX013-EX016 above) — the single source production workout flows (e.g.
/// Core Crusher) resolve their real exercise ids through, so a workout's
/// exercise list and the routine actually passed to RoutinePlayer can
/// never drift apart into two separate definitions of the same exercise.
final Map<String, ExerciseDefinition> kRoutinePlayerExercisesById = {
  for (final exercise in _kRoutinePlayerAll) exercise.id: exercise,
};

/// Looks up a real RoutinePlayer [ExerciseDefinition] by its canonical
/// catalog id (e.g. `EX012`), or null if RoutinePlayer has no definition
/// for that id yet. Callers must never substitute a different exercise's
/// definition when this returns null.
ExerciseDefinition? routinePlayerExerciseById(String id) =>
    kRoutinePlayerExercisesById[id];
