import '../models/exercise_models.dart';

const _core = ExerciseCategory.core;
const _strength = ExerciseCategory.strength;
const _flexibility = ExerciseCategory.flexibility;
const _bedtime = ExerciseCategory.bedtime;
const _mobility = ExerciseCategory.mobility;
const _cardio = ExerciseCategory.cardio;
const _recovery = ExerciseCategory.recovery;

const _reps = ExercisePlaybackType.reps;
const _timer = ExercisePlaybackType.timer;
const _hold = ExercisePlaybackType.hold;
const _seqLoop = ExercisePlaybackType.sequenceLoop;
const _sideSeq = ExercisePlaybackType.sideSequence;
const _breathing = ExercisePlaybackType.breathing;

/// A single reasonable placeholder step for exercises whose real 6-step
/// Figma sequence wasn't individually pulled this pass (see [Exercise]'s
/// doc comment) — never claims to be Figma-sourced.
List<ExerciseStep> _placeholder(String cue) => [
  ExerciseStep(label: 'GO', instruction: cue),
];

/// All 52 exercises from the Exercise Sequence Library handoff table
/// (357:4818), in EX001-EX052 order. Category/tags/playback type/
/// 6-step/switch/repeat flags are read directly off that table — the
/// authoritative, complete source for all 52. Real per-step instruction
/// text (see [ExerciseStep]) and verified downloaded pose images
/// ([Exercise.hasVerifiedImages]) are only in place for the 6 priority
/// exercises (one per playback type, individually fetched and downloaded
/// from Figma this pass); the rest use a single reasonable cue and no
/// image (UI falls back to clean text, never emoji/icons — see
/// exercise_widgets doc).
final List<Exercise> kExerciseCatalog = [
  Exercise(
    id: 'EX001',
    name: 'Deep Breathing',
    primaryCategory: _bedtime,
    playbackType: _breathing,
    hasSwitchSide: false,
    // Was true (pointing at the old assets/glow_up/exercises/EX001/female/
    // photos) — flipped to false now that EX001 has a real, approved Tier 1
    // V2 image set (see _deepBreathing in routine_player_registry.dart).
    // resolvePoseAssetPath tries Tier 2 first when hasVerifiedImages is
    // true, so leaving this true would keep showing the old Tier 2 photo
    // on the routine-detail thumbnail/legacy pose display even though a
    // newer, approved image exists. The old photo files are left on disk,
    // untouched — not deleted, just no longer referenced by either tier.
    hasVerifiedImages: false,
    durationSeconds: 60,
    steps: const [
      ExerciseStep(
        label: 'START',
        instruction: 'Sit tall and relax your shoulders.',
      ),
      ExerciseStep(
        label: 'HANDS SET',
        instruction: 'Place one hand on your chest and one on your belly.',
      ),
      ExerciseStep(label: 'INHALE', instruction: 'Take a slow deep breath in.'),
      ExerciseStep(
        label: 'HOLD BREATH',
        instruction: 'Pause gently for a moment.',
      ),
      ExerciseStep(label: 'EXHALE', instruction: 'Exhale slowly and relax.'),
      ExerciseStep(label: 'RESET', instruction: 'Return to start and repeat.'),
    ],
  ),
  Exercise(
    id: 'EX002',
    name: 'Full Body Stretch',
    primaryCategory: _bedtime,
    playbackType: _seqLoop,
    durationSeconds: 45,
    steps: _placeholder('Reach and lengthen through your whole body.'),
  ),
  Exercise(
    id: 'EX003',
    name: 'Knee-to-Chest',
    primaryCategory: _bedtime,
    secondaryTags: const [_flexibility],
    playbackType: _sideSeq,
    hasSwitchSide: true,
    durationSeconds: 40,
    steps: _placeholder('Pull one knee gently toward your chest.'),
  ),
  Exercise(
    id: 'EX004',
    name: 'Supine Twist',
    primaryCategory: _bedtime,
    secondaryTags: const [_flexibility],
    playbackType: _sideSeq,
    hasSwitchSide: true,
    durationSeconds: 40,
    steps: _placeholder('Let your knees fall gently to one side.'),
  ),
  Exercise(
    id: 'EX005',
    name: 'Ankle Circles',
    primaryCategory: _bedtime,
    secondaryTags: const [_mobility],
    playbackType: _sideSeq,
    hasSwitchSide: true,
    durationSeconds: 30,
    steps: _placeholder('Circle your ankle slowly in each direction.'),
  ),
  Exercise(
    id: 'EX006',
    name: 'Sit-Up Reach',
    primaryCategory: _bedtime,
    secondaryTags: const [_core],
    playbackType: _reps,
    reps: 10,
    durationSeconds: 40,
    steps: _placeholder('Sit up and reach toward your toes.'),
  ),
  Exercise(
    id: 'EX007',
    name: 'Squat',
    primaryCategory: _strength,
    playbackType: _reps,
    // hasVerifiedImages intentionally NOT set (defaults false) as of the
    // V2 asset replacement — this exercise's real approved images now
    // live in the Tier 1 registry (routine_player_registry.dart's
    // _squat), same fix as EX001 Deep Breathing and EX009 Jumping Jacks.
    // resolvePoseAssetPath tries Tier 2 first when hasVerifiedImages is
    // true, so leaving this true would keep showing the old Tier 2 photo
    // on the routine-detail thumbnail even though a newer, approved image
    // exists. The old photo files are left on disk, untouched.
    reps: 15,
    durationSeconds: 45,
    steps: const [
      ExerciseStep(
        label: 'START',
        instruction: 'Stand with feet shoulder-width apart.',
      ),
      ExerciseStep(label: 'HIPS BACK', instruction: 'Push your hips back.'),
      ExerciseStep(label: 'LOWER', instruction: 'Lower into the squat.'),
      ExerciseStep(
        label: 'BOTTOM POSITION',
        instruction: 'Hold at the bottom.',
      ),
      ExerciseStep(
        label: 'STAND',
        instruction: 'Drive through heels to stand.',
      ),
      ExerciseStep(label: 'RESET', instruction: 'Return to standing position.'),
    ],
  ),
  Exercise(
    id: 'EX008',
    name: 'Lunges',
    primaryCategory: _strength,
    playbackType: _sideSeq,
    hasSwitchSide: true,
    // hasVerifiedImages intentionally NOT set (defaults false) as of the
    // V2 asset replacement — this exercise's real approved images now
    // live in the Tier 1 registry (routine_player_registry.dart's
    // _lunges), same fix as EX001/EX007/EX009. resolvePoseAssetPath
    // tries Tier 2 first when hasVerifiedImages is true, so leaving this
    // true would keep showing the old Tier 2 photo on the routine-detail
    // thumbnail even though a newer, approved image exists. The old
    // photo files are left on disk, untouched.
    reps: 10,
    durationSeconds: 45,
    steps: const [
      ExerciseStep(
        label: 'START',
        instruction: 'Stand tall with feet hip-width apart.',
      ),
      ExerciseStep(
        label: 'STEP FORWARD',
        instruction: 'Take a big step forward.',
      ),
      ExerciseStep(
        label: 'LOWER',
        instruction: 'Lower your back knee toward the floor.',
      ),
      ExerciseStep(
        label: 'LUNGE POSITION',
        instruction: 'Hold the lunge position.',
      ),
      ExerciseStep(
        label: 'PUSH BACK',
        instruction: 'Push through front heel to rise.',
      ),
      ExerciseStep(
        label: 'RESET SWITCH',
        instruction: 'Return to start and switch sides.',
      ),
    ],
  ),
  Exercise(
    id: 'EX009',
    name: 'Jumping Jacks',
    primaryCategory: _cardio,
    playbackType: _timer,
    // hasVerifiedImages intentionally NOT set (defaults false) as of the
    // V2 asset replacement — this exercise's real approved images now
    // live in the Tier 1 registry (routine_player_registry.dart's
    // _jumpingJack, folder jumping_jack/female/v2/), resolved via
    // resolvePoseAssetPath's Tier 1 fallback. Same fix already applied to
    // EX001 Deep Breathing's own V2 replacement — leaving this true would
    // keep resolving to the old legacy exercises/EX009/female/0N.png
    // photos ahead of the new approved set.
    durationSeconds: 45,
    steps: const [
      ExerciseStep(
        label: 'START',
        instruction: 'Stand with feet together, arms at sides.',
      ),
      ExerciseStep(label: 'JUMP OPEN', instruction: 'Jump feet apart.'),
      ExerciseStep(label: 'ARMS UP', instruction: 'Raise arms overhead.'),
      ExerciseStep(
        label: 'FULL EXTENSION',
        instruction: 'Full jumping jack position.',
      ),
      ExerciseStep(
        label: 'RETURN',
        instruction: 'Jump feet together, arms down.',
      ),
      ExerciseStep(label: 'RESET', instruction: 'Return to starting position.'),
    ],
  ),
  Exercise(
    id: 'EX010',
    name: 'Push-Ups',
    primaryCategory: _strength,
    playbackType: _reps,
    // hasVerifiedImages intentionally NOT set (defaults false) as of the
    // V2 asset replacement — this exercise's real approved images now
    // live in the Tier 1 registry (routine_player_registry.dart's
    // _pushUps), same fix as EX001/EX007/EX008/EX009.
    // resolvePoseAssetPath tries Tier 2 first when hasVerifiedImages is
    // true, so leaving this true would keep showing the old Tier 2 photo
    // on the routine-detail thumbnail even though a newer, approved
    // image exists. The old photo files are left on disk, untouched.
    reps: 12,
    durationSeconds: 40,
    steps: const [
      ExerciseStep(
        label: 'HIGH PLANK',
        instruction: 'Start in a high plank position.',
      ),
      ExerciseStep(label: 'BRACE', instruction: 'Engage your core and brace.'),
      ExerciseStep(
        label: 'LOWER',
        instruction: 'Lower your chest toward the floor.',
      ),
      ExerciseStep(
        label: 'BOTTOM POSITION',
        instruction: 'Chest just above the floor.',
      ),
      ExerciseStep(label: 'PRESS UP', instruction: 'Push back up to plank.'),
      ExerciseStep(label: 'RESET', instruction: 'Return to high plank.'),
    ],
  ),
  Exercise(
    id: 'EX011',
    name: 'Plank',
    primaryCategory: _core,
    playbackType: _hold,
    hasRepeat: false,
    hasVerifiedImages: true,
    durationSeconds: 30,
    steps: const [
      ExerciseStep(label: 'SETUP', instruction: 'Get on all fours.'),
      ExerciseStep(
        label: 'STEP BACK',
        instruction: 'Step your feet back one at a time.',
      ),
      ExerciseStep(
        label: 'PLANK POSITION',
        instruction: 'Hold a straight line from head to heels.',
      ),
      ExerciseStep(label: 'HOLD', instruction: 'Engage your core and hold.'),
      ExerciseStep(
        label: 'LOWER KNEES',
        instruction: 'Lower your knees to rest.',
      ),
      ExerciseStep(label: 'RESET', instruction: 'Return to all fours.'),
    ],
  ),
  Exercise(
    id: 'EX012',
    name: 'Dead Bug',
    primaryCategory: _core,
    playbackType: _reps,
    reps: 10,
    durationSeconds: 40,
    steps: _placeholder('Extend opposite arm and leg with control.'),
  ),
  Exercise(
    id: 'EX013',
    name: 'Bicycle Crunch',
    primaryCategory: _core,
    playbackType: _reps,
    reps: 15,
    durationSeconds: 40,
    steps: _placeholder('Bring opposite elbow to knee in a pedaling motion.'),
  ),
  Exercise(
    id: 'EX014',
    name: 'Leg Raises',
    primaryCategory: _core,
    playbackType: _reps,
    reps: 12,
    durationSeconds: 40,
    steps: _placeholder('Lift both legs toward the ceiling with control.'),
  ),
  Exercise(
    id: 'EX015',
    name: 'Russian Twist',
    primaryCategory: _core,
    playbackType: _reps,
    reps: 16,
    durationSeconds: 40,
    steps: _placeholder('Rotate your torso side to side.'),
  ),
  Exercise(
    id: 'EX016',
    name: 'Bird Dog',
    primaryCategory: _core,
    secondaryTags: const [_mobility],
    playbackType: _reps,
    reps: 10,
    durationSeconds: 40,
    steps: _placeholder('Extend opposite arm and leg from all fours.'),
  ),
  Exercise(
    id: 'EX017',
    name: 'Mountain Climbers',
    primaryCategory: _core,
    secondaryTags: const [_cardio],
    playbackType: _timer,
    durationSeconds: 40,
    steps: _placeholder('Drive your knees toward your chest quickly.'),
  ),
  Exercise(
    id: 'EX018',
    name: 'Glute Bridge',
    primaryCategory: _strength,
    playbackType: _reps,
    reps: 15,
    durationSeconds: 40,
    steps: _placeholder('Lift your hips toward the ceiling.'),
  ),
  Exercise(
    id: 'EX019',
    name: 'Wall Push-Up',
    primaryCategory: _strength,
    playbackType: _reps,
    reps: 12,
    durationSeconds: 40,
    steps: _placeholder('Push away from the wall with control.'),
  ),
  Exercise(
    id: 'EX020',
    name: 'Calf Raises',
    primaryCategory: _strength,
    playbackType: _reps,
    reps: 20,
    durationSeconds: 35,
    steps: _placeholder('Rise onto your toes and lower slowly.'),
  ),
  Exercise(
    id: 'EX021',
    name: 'Tricep Dips',
    primaryCategory: _strength,
    playbackType: _reps,
    reps: 12,
    durationSeconds: 40,
    steps: _placeholder('Lower and press using your triceps.'),
  ),
  Exercise(
    id: 'EX022',
    name: 'Donkey Kicks',
    primaryCategory: _strength,
    playbackType: _sideSeq,
    hasSwitchSide: true,
    reps: 12,
    durationSeconds: 40,
    steps: _placeholder('Kick one leg up and back with control.'),
  ),
  Exercise(
    id: 'EX023',
    name: 'Shoulder Taps',
    primaryCategory: _strength,
    secondaryTags: const [_core],
    playbackType: _reps,
    reps: 16,
    durationSeconds: 35,
    steps: _placeholder('Tap opposite shoulder while holding plank.'),
  ),
  Exercise(
    id: 'EX024',
    name: 'Superman',
    primaryCategory: _strength,
    secondaryTags: const [_core],
    playbackType: _hold,
    hasRepeat: false,
    durationSeconds: 25,
    steps: _placeholder('Lift chest and legs off the floor together.'),
  ),
  Exercise(
    id: 'EX025',
    name: 'Hamstring Stretch',
    primaryCategory: _flexibility,
    playbackType: _sideSeq,
    hasSwitchSide: true,
    durationSeconds: 40,
    steps: _placeholder('Extend one leg and reach toward your toes.'),
  ),
  Exercise(
    id: 'EX026',
    name: 'Quad Stretch',
    primaryCategory: _flexibility,
    playbackType: _sideSeq,
    hasSwitchSide: true,
    durationSeconds: 40,
    steps: _placeholder('Pull your heel gently toward your glutes.'),
  ),
  Exercise(
    id: 'EX027',
    name: 'Butterfly Stretch',
    primaryCategory: _flexibility,
    playbackType: _hold,
    hasRepeat: false,
    durationSeconds: 30,
    steps: _placeholder(
      'Bring the soles of your feet together and relax your knees.',
    ),
  ),
  Exercise(
    id: 'EX028',
    name: "Child's Pose",
    primaryCategory: _flexibility,
    playbackType: _hold,
    hasRepeat: false,
    durationSeconds: 30,
    steps: _placeholder('Sit back on your heels and reach forward.'),
  ),
  Exercise(
    id: 'EX029',
    name: 'Cobra Stretch',
    primaryCategory: _flexibility,
    playbackType: _hold,
    durationSeconds: 25,
    steps: _placeholder('Press through your palms and lift your chest.'),
  ),
  Exercise(
    id: 'EX030',
    name: 'Hip Flexor Stretch',
    primaryCategory: _flexibility,
    playbackType: _sideSeq,
    hasSwitchSide: true,
    durationSeconds: 40,
    steps: _placeholder('Sink into a low lunge and open your hip.'),
  ),
  Exercise(
    id: 'EX031',
    name: 'Cat-Cow',
    primaryCategory: _flexibility,
    secondaryTags: const [_mobility],
    playbackType: _seqLoop,
    durationSeconds: 40,
    steps: _placeholder('Arch and round your spine with your breath.'),
  ),
  Exercise(
    id: 'EX032',
    name: 'Legs Up Wall',
    primaryCategory: _bedtime,
    secondaryTags: const [_recovery],
    playbackType: _hold,
    hasRepeat: false,
    durationSeconds: 60,
    steps: _placeholder('Rest your legs up against a wall and relax.'),
  ),
  Exercise(
    id: 'EX033',
    name: 'Reclined Butterfly',
    primaryCategory: _bedtime,
    secondaryTags: const [_recovery],
    playbackType: _hold,
    hasRepeat: false,
    durationSeconds: 60,
    steps: _placeholder('Lie back and let your knees fall open.'),
  ),
  Exercise(
    id: 'EX034',
    name: 'Neck Release',
    primaryCategory: _bedtime,
    secondaryTags: const [_mobility],
    playbackType: _sideSeq,
    hasSwitchSide: true,
    durationSeconds: 30,
    steps: _placeholder('Gently tilt your head to release tension.'),
  ),
  Exercise(
    id: 'EX035',
    name: 'Box Breathing',
    primaryCategory: _bedtime,
    playbackType: _breathing,
    durationSeconds: 60,
    steps: _placeholder('Inhale, hold, exhale, and hold — each for 4 counts.'),
  ),
  Exercise(
    id: 'EX036',
    name: 'Shoulder Rolls',
    primaryCategory: _mobility,
    playbackType: _seqLoop,
    durationSeconds: 30,
    steps: _placeholder('Roll your shoulders slowly in a full circle.'),
  ),
  Exercise(
    id: 'EX037',
    name: 'Arm Circles',
    primaryCategory: _mobility,
    playbackType: _timer,
    durationSeconds: 30,
    steps: _placeholder('Circle your arms forward, then backward.'),
  ),
  Exercise(
    id: 'EX038',
    name: 'Wrist Circles',
    primaryCategory: _mobility,
    playbackType: _timer,
    durationSeconds: 20,
    steps: _placeholder('Rotate your wrists slowly in each direction.'),
  ),
  Exercise(
    id: 'EX039',
    name: 'Hip Circles',
    primaryCategory: _mobility,
    playbackType: _timer,
    durationSeconds: 30,
    steps: _placeholder('Circle your hips slowly in each direction.'),
  ),
  Exercise(
    id: 'EX040',
    name: 'Thoracic Rotation',
    primaryCategory: _mobility,
    playbackType: _sideSeq,
    hasSwitchSide: true,
    durationSeconds: 35,
    steps: _placeholder('Rotate your upper back while kneeling.'),
  ),
  Exercise(
    id: 'EX041',
    name: 'Knee Circles',
    primaryCategory: _mobility,
    playbackType: _timer,
    durationSeconds: 25,
    steps: _placeholder('Circle your knees gently together.'),
  ),
  Exercise(
    id: 'EX042',
    name: 'March In Place',
    primaryCategory: _cardio,
    playbackType: _timer,
    durationSeconds: 40,
    steps: _placeholder('March your knees up at a steady pace.'),
  ),
  Exercise(
    id: 'EX043',
    name: 'High Knees',
    primaryCategory: _cardio,
    playbackType: _timer,
    durationSeconds: 35,
    steps: _placeholder('Drive your knees up toward your chest quickly.'),
  ),
  Exercise(
    id: 'EX044',
    name: 'Butt Kicks',
    primaryCategory: _cardio,
    playbackType: _timer,
    durationSeconds: 35,
    steps: _placeholder('Kick your heels up toward your glutes.'),
  ),
  Exercise(
    id: 'EX045',
    name: 'Step Jacks',
    primaryCategory: _cardio,
    playbackType: _timer,
    durationSeconds: 35,
    steps: _placeholder('Step side to side with an arm raise.'),
  ),
  Exercise(
    id: 'EX046',
    name: 'Skaters',
    primaryCategory: _cardio,
    playbackType: _timer,
    durationSeconds: 40,
    steps: _placeholder('Leap side to side like a speed skater.'),
  ),
  Exercise(
    id: 'EX047',
    name: 'Shadow Boxing',
    primaryCategory: _cardio,
    playbackType: _seqLoop,
    durationSeconds: 45,
    steps: _placeholder(
      'Throw controlled punches, staying light on your feet.',
    ),
  ),
  Exercise(
    id: 'EX048',
    name: 'Side Steps',
    primaryCategory: _cardio,
    playbackType: _timer,
    durationSeconds: 30,
    steps: _placeholder('Step side to side, staying low.'),
  ),
  Exercise(
    id: 'EX049',
    name: 'Figure Four Stretch',
    primaryCategory: _recovery,
    playbackType: _sideSeq,
    hasSwitchSide: true,
    durationSeconds: 40,
    steps: _placeholder(
      'Cross one ankle over the opposite knee and fold forward.',
    ),
  ),
  Exercise(
    id: 'EX050',
    name: 'Calf Stretch',
    primaryCategory: _recovery,
    playbackType: _sideSeq,
    hasSwitchSide: true,
    durationSeconds: 40,
    steps: _placeholder('Press your heel down with your leg extended back.'),
  ),
  Exercise(
    id: 'EX051',
    name: 'Chest Opener',
    primaryCategory: _recovery,
    playbackType: _hold,
    hasRepeat: false,
    durationSeconds: 25,
    steps: _placeholder(
      'Clasp your hands behind your back and lift your chest.',
    ),
  ),
  Exercise(
    id: 'EX052',
    name: '90/90 Hip Switch',
    primaryCategory: _recovery,
    playbackType: _sideSeq,
    hasSwitchSide: true,
    durationSeconds: 40,
    steps: _placeholder('Rotate both knees from one side to the other.'),
  ),

  /// Not part of the original 52-exercise Exercise Sequence Library
  /// handoff table (357:4818) — added later from its own dedicated Figma
  /// page (`EX-006 Fire Hydrant`, node 560:62). `hasVerifiedImages` stays
  /// false here deliberately: this legacy catalog entry exists only so
  /// `exerciseById('EX054')` resolves without crashing wherever a
  /// [Workout]'s exercise list references it (see `_exercises` above) —
  /// the real, approved V2 six-frame images live exclusively in the
  /// RoutinePlayer registry (`routine_player_registry.dart`'s
  /// `_fireHydrant`), which is what Core Crusher actually renders.
  Exercise(
    id: 'EX054',
    name: 'Fire Hydrant',
    primaryCategory: _core,
    secondaryTags: const [_strength],
    playbackType: _reps,
    reps: 10,
    durationSeconds: 40,
    steps: _placeholder(
      'Lift your right knee out to the side, keeping it bent.',
    ),
  ),
];

/// Strength-category exercises with a real legacy catalog entry above but
/// no approved Tier 1 (RoutinePlayer) production asset set — from the
/// Strength routine asset-cleanup audit. Explicitly marked rather than
/// left as a silent gap: each of these currently shows text-only (no
/// image) wherever `hasVerifiedImages` is checked, which is correct and
/// intentional — never substitute a wrong/legacy/placeholder image for an
/// exercise in this set. Do not add a Tier 1 `ExerciseDefinition` for any
/// of these without a real, individually-verified, approved Figma asset
/// set backing it (no placeholder/replacement artwork).
const kStrengthAssetPendingApproval = <String>{};

Exercise? exerciseById(String id) {
  for (final e in kExerciseCatalog) {
    if (e.id == id) return e;
  }
  return null;
}

List<Exercise> exercisesByPrimaryCategory(ExerciseCategory category) =>
    kExerciseCatalog.where((e) => e.primaryCategory == category).toList();
