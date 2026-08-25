import '../models/exercise_models.dart';
import '../models/workout_models.dart';
import 'exercise_catalog.dart';

/// Builds a routine's [WorkoutExercise] list from real catalog entries by
/// ID — the actual bridge from the 52-exercise library into a playable
/// routine. Throws if an ID doesn't exist, so a typo here fails loudly
/// instead of silently dropping an exercise.
List<WorkoutExercise> _exercises(List<String> ids) {
  return [
    for (var i = 0; i < ids.length; i++)
      WorkoutExercise.fromCatalog(
        exerciseById(ids[i])!,
        instanceId: '${ids[i]}_$i',
      ),
  ];
}

/// The one canonical Jumping Jacks entry, shared by both Cardio routines
/// (HIIT Cardio Blast and Full Body Burn each use this exact same const —
/// never a second/duplicate definition) — a raw entry, not part of
/// _exercises([...]), because `thumbnailAssetPath` needs to point at the
/// approved V2 `sequence_preview.png`; `_exercises()`'s generic
/// `WorkoutExercise.fromCatalog` bridge has no per-id override for that.
/// Real production id (EX009) is unchanged from before this pass — this
/// is an asset replacement, not a new exercise. `id: 'EX009_0'` follows
/// the same `'${catalogId}_$index'` convention `_exercises()` generates,
/// so the "every routine exercise traces back to a real catalog ID" audit
/// (exercise_catalog_test.dart) resolves it the same way it resolves
/// every other real, non-exception WorkoutExercise.
const _jumpingJacksV2 = WorkoutExercise(
  id: 'EX009_0',
  title: 'Jumping Jacks',
  durationSeconds: 45,
  catalogId: 'EX009',
  playbackType: ExercisePlaybackType.timer,
  thumbnailAssetPath:
      'assets/glow_up/exercises/jumping_jack/female/v2/sequence_preview.png',
  steps: [
    ExerciseStep(
      label: 'START',
      instruction:
          'Stand tall with your feet together and your arms at your sides.',
    ),
    ExerciseStep(
      label: 'OPENING',
      instruction: 'Jump your feet outward as your arms begin to rise.',
    ),
    ExerciseStep(
      label: 'FULL OPEN',
      instruction: 'Feet wide, arms fully overhead.',
    ),
    ExerciseStep(
      label: 'LOWERING',
      instruction: 'Feet still wide, arms lowering.',
    ),
    ExerciseStep(
      label: 'CLOSING',
      instruction: 'Jump your feet back together, arms nearly down.',
    ),
    ExerciseStep(
      label: 'RESET',
      instruction: 'Land softly, feet together, arms back at your sides.',
    ),
  ],
);

/// The one canonical Squat entry, shared by both routines that reference
/// it (Strength Foundations and Full Body Burn each use this exact same
/// const — never a second/duplicate definition) — a raw entry, not part
/// of _exercises([...]), because `thumbnailAssetPath` needs to point at
/// the approved V2 `sequence_preview.png`; `_exercises()`'s generic
/// `WorkoutExercise.fromCatalog` bridge has no per-id override for that.
/// Real production id (EX007) is unchanged from before this pass — this
/// is an asset replacement, not a new exercise. `id: 'EX007_0'` follows
/// the same `'${catalogId}_$index'` convention `_exercises()` generates,
/// so the "every routine exercise traces back to a real catalog ID" audit
/// (exercise_catalog_test.dart) resolves it the same way it resolves
/// every other real, non-exception WorkoutExercise. Step text copied
/// unchanged from the EX007 catalog entry (exercise_catalog.dart).
const _squatV2 = WorkoutExercise(
  id: 'EX007_0',
  title: 'Squat',
  durationSeconds: 45,
  catalogId: 'EX007',
  playbackType: ExercisePlaybackType.reps,
  reps: 15,
  thumbnailAssetPath:
      'assets/glow_up/exercises/squat/female/v2/sequence_preview.png',
  steps: [
    ExerciseStep(
      label: 'START',
      instruction: 'Stand with feet shoulder-width apart.',
    ),
    ExerciseStep(label: 'HIPS BACK', instruction: 'Push your hips back.'),
    ExerciseStep(label: 'LOWER', instruction: 'Lower into the squat.'),
    ExerciseStep(label: 'BOTTOM POSITION', instruction: 'Hold at the bottom.'),
    ExerciseStep(label: 'STAND', instruction: 'Drive through heels to stand.'),
    ExerciseStep(label: 'RESET', instruction: 'Return to standing position.'),
  ],
);

/// The one canonical Lunges entry, shared by both routines that reference
/// it (Strength Foundations and Full Body Burn each use this exact same
/// const — never a second/duplicate definition) — a raw entry, not part
/// of _exercises([...]), because `thumbnailAssetPath` needs to point at
/// the approved V2 `sequence_preview.png`; `_exercises()`'s generic
/// `WorkoutExercise.fromCatalog` bridge has no per-id override for that.
/// Real production id (EX008) is unchanged from before this pass — this
/// is an asset replacement, not a new exercise. `id: 'EX008_0'` follows
/// the same `'${catalogId}_$index'` convention `_exercises()` generates,
/// so the "every routine exercise traces back to a real catalog ID" audit
/// (exercise_catalog_test.dart) resolves it the same way it resolves
/// every other real, non-exception WorkoutExercise. Step text copied
/// unchanged from the EX008 catalog entry (exercise_catalog.dart).
const _lungesV2 = WorkoutExercise(
  id: 'EX008_0',
  title: 'Lunges',
  durationSeconds: 45,
  catalogId: 'EX008',
  playbackType: ExercisePlaybackType.sideSequence,
  hasSwitchSide: true,
  reps: 10,
  thumbnailAssetPath:
      'assets/glow_up/exercises/lunges/female/v2/sequence_preview.png',
  steps: [
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
);

/// The one canonical Push-Ups entry, shared by both routines that
/// reference it (Strength Foundations and Full Body Burn each use this
/// exact same const — never a second/duplicate definition) — a raw
/// entry, not part of _exercises([...]), because `thumbnailAssetPath`
/// needs to point at the approved V2 `sequence_preview.png`;
/// `_exercises()`'s generic `WorkoutExercise.fromCatalog` bridge has no
/// per-id override for that. Real production id (EX010) is unchanged
/// from before this pass — this is an asset replacement, not a new
/// exercise. `id: 'EX010_0'` follows the same `'${catalogId}_$index'`
/// convention `_exercises()` generates, so the "every routine exercise
/// traces back to a real catalog ID" audit (exercise_catalog_test.dart)
/// resolves it the same way it resolves every other real, non-exception
/// WorkoutExercise. Step text copied unchanged from the EX010 catalog
/// entry (exercise_catalog.dart) — the catalog's own "Push-Ups" title is
/// kept here too (unlike the Tier 1 registry's "Pushups" displayName)
/// since this bridges the Tier 2 catalog record.
const _pushUpsV2 = WorkoutExercise(
  id: 'EX010_0',
  title: 'Push-Ups',
  durationSeconds: 40,
  catalogId: 'EX010',
  playbackType: ExercisePlaybackType.reps,
  reps: 12,
  thumbnailAssetPath:
      'assets/glow_up/exercises/pushups/female/v2/sequence_preview.png',
  steps: [
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
);

/// Every workout/routine in the app, built from the real 52-exercise
/// Exercise Sequence Library (`exercise_catalog.dart`) — see that file's
/// doc comment for what's real vs. documented-placeholder per exercise.
/// `morning-yoga-flow` is the one exception: its 6 exercises (Sun
/// Salutation, Downward Dog, Warrior I/II, Tree Pose, Savasana) come
/// directly from the approved 32_workout_detail frame (368:3059) and
/// don't exist in the 52-exercise library under those names — kept as-is
/// since it's real Figma-specified content, just from a different source
/// than the other 10 routines. All six now have real Tier 1 ids —
/// Sun Salutation (`EX055`), Downward Dog (`EX056`), Warrior I (`EX057`),
/// Warrior II (`EX058`), Tree Pose (`EX059`), and Savasana (`EX060`) —
/// see the doc comments on
/// `_sunSalutation`/`_downwardDog`/`_warriorI`/`_warriorII`/`_treePose`/`_savasana`
/// in routine_player_registry.dart.
final List<Workout> kWorkoutCatalog = [
  const Workout(
    id: 'morning-yoga-flow',
    category: ExerciseCategory.flexibility,
    title: 'Morning Yoga Flow',
    subtitle:
        'A peaceful sequence to align your energy and ignite your inner glow.',
    heroAssetPath: 'assets/glow_up/illustrations/workout-yoga-hero.png',
    difficulty: WorkoutDifficulty.beginner,
    calories: 120,
    equipment: 'Yoga Mat',
    exercises: [
      WorkoutExercise(
        id: 'sun-salutation',
        title: 'Sun Salutation',
        durationSeconds: 180,
        poseAssetPath: 'assets/glow_up/illustrations/pose-sun-salutation.png',
        catalogId: 'EX055',
      ),
      WorkoutExercise(
        id: 'downward-dog',
        title: 'Downward Dog',
        durationSeconds: 240,
        poseAssetPath: 'assets/glow_up/illustrations/pose-downward-dog.png',
        catalogId: 'EX056',
      ),
      WorkoutExercise(
        id: 'warrior-1',
        title: 'Warrior I',
        durationSeconds: 180,
        catalogId: 'EX057',
      ),
      WorkoutExercise(
        id: 'warrior-2',
        title: 'Warrior II',
        durationSeconds: 180,
        catalogId: 'EX058',
      ),
      WorkoutExercise(
        id: 'tree-pose',
        title: 'Tree Pose',
        durationSeconds: 240,
        catalogId: 'EX059',
      ),
      WorkoutExercise(
        id: 'savasana',
        title: 'Savasana',
        durationSeconds: 180,
        catalogId: 'EX060',
      ),
    ],
  ),
  Workout(
    id: 'evening-stretch',
    category: ExerciseCategory.flexibility,
    title: 'Evening Stretch',
    subtitle: 'Wind down with a full lower-body flexibility sequence.',
    heroAssetPath: 'assets/glow_up/illustrations/workout-yoga-hero.png',
    difficulty: WorkoutDifficulty.beginner,
    calories: 60,
    equipment: 'Yoga Mat',
    exercises: _exercises([
      'EX025',
      'EX026',
      'EX027',
      'EX028',
      'EX029',
      'EX030',
      'EX031',
    ]),
  ),
  Workout(
    id: 'bedtime-meditation',
    category: ExerciseCategory.bedtime,
    title: 'Bedtime Meditation',
    subtitle: 'Calm your body and mind before sleep.',
    heroAssetPath: 'assets/glow_up/illustrations/workout-yoga-hero.png',
    difficulty: WorkoutDifficulty.beginner,
    calories: 25,
    equipment: 'None',
    // Full Body Stretch (2nd), Knee-to-Chest (3rd), Supine Twist (4th),
    // Ankle Circles (5th), and Sit-Up Reach (6th, final) are raw entries,
    // not part of _exercises(['EX001']) below, because their real
    // production ids (EX061-EX065) don't exist in the Tier 2 legacy
    // catalog — see the doc comments on
    // _fullBodyStretchV2/_kneeToChestV2/_supineTwistV2/_ankleCirclesV2/
    // _sitUpReachV2 in routine_player_registry.dart. _exercises()'s
    // exerciseById(id)! lookup would crash on any of them, the same
    // reason Morning Yoga Flow's EX055-EX060 are also raw entries. The
    // legacy EX002/EX003/EX004/EX005/EX006 placeholders these replaced
    // are left in place, untouched, and simply no longer referenced here.
    exercises: [
      ..._exercises(['EX001']),
      const WorkoutExercise(
        id: 'full-body-stretch',
        title: 'Full Body Stretch',
        durationSeconds: 45,
        catalogId: 'EX061',
      ),
      const WorkoutExercise(
        id: 'knee-to-chest',
        title: 'Knee-to-Chest',
        durationSeconds: 40,
        catalogId: 'EX062',
        playbackType: ExercisePlaybackType.sideSequence,
      ),
      const WorkoutExercise(
        id: 'supine-twist',
        title: 'Supine Twist',
        durationSeconds: 40,
        catalogId: 'EX063',
        playbackType: ExercisePlaybackType.sideSequence,
      ),
      const WorkoutExercise(
        id: 'ankle-circles',
        title: 'Ankle Circles',
        durationSeconds: 30,
        catalogId: 'EX064',
        playbackType: ExercisePlaybackType.sideSequence,
      ),
      const WorkoutExercise(
        id: 'sit-up-reach',
        title: 'Sit-Up Reach',
        durationSeconds: 40,
        catalogId: 'EX065',
        playbackType: ExercisePlaybackType.reps,
        reps: 10,
      ),
    ],
  ),
  Workout(
    id: 'deep-sleep-prep',
    category: ExerciseCategory.bedtime,
    title: 'Deep Sleep Prep',
    subtitle: 'Release tension and settle in for restorative sleep.',
    heroAssetPath: 'assets/glow_up/illustrations/workout-yoga-hero.png',
    difficulty: WorkoutDifficulty.beginner,
    calories: 20,
    equipment: 'None',
    // All four exercises are raw entries, not part of _exercises([...])
    // below, because their real production ids (EX066-EX069) don't exist
    // in the Tier 2 legacy catalog — see the doc comments on
    // _legsUpWallV2/_reclinedButterflyV2/_neckReleaseV2/_boxBreathingV2 in
    // routine_player_registry.dart. _exercises()'s exerciseById(id)!
    // lookup would crash on any of them, the same reason Bedtime
    // Meditation's EX061-EX065 are also raw entries. The legacy
    // EX032-EX035 placeholders these replace are left in place, untouched,
    // and simply no longer referenced here.
    //
    // Because every exercise here now has a real Tier 1 definition, this
    // workout resolves entirely through `_routinePlayerRoutineFor` in
    // app_router.dart (a [Workout] only reaches Tier 1 RoutinePlayer if
    // *every* exercise has a Tier 1 definition) — the exact same
    // all-or-nothing gate Bedtime Meditation flipped through once its own
    // EX065 was finished. No router/navigation code changes here; the
    // existing Tier-2 fallback branch stays exactly as-is for every other
    // routine that still needs it.
    exercises: [
      const WorkoutExercise(
        id: 'legs-up-wall-v2',
        title: 'Legs Up Wall',
        durationSeconds: 60,
        catalogId: 'EX066',
        playbackType: ExercisePlaybackType.hold,
      ),
      const WorkoutExercise(
        id: 'reclined-butterfly-v2',
        title: 'Reclined Butterfly',
        durationSeconds: 60,
        catalogId: 'EX067',
        playbackType: ExercisePlaybackType.hold,
      ),
      const WorkoutExercise(
        id: 'neck-release-v2',
        title: 'Neck Release',
        durationSeconds: 30,
        catalogId: 'EX068',
        playbackType: ExercisePlaybackType.sideSequence,
      ),
      const WorkoutExercise(
        id: 'box-breathing-v2',
        title: 'Box Breathing',
        durationSeconds: 60,
        catalogId: 'EX069',
        playbackType: ExercisePlaybackType.breathing,
      ),
    ],
  ),
  Workout(
    id: 'strength-foundations',
    category: ExerciseCategory.strength,
    title: 'Strength Foundations',
    subtitle: 'Classic bodyweight strength training, no equipment needed.',
    heroAssetPath: 'assets/glow_up/illustrations/workout-yoga-hero.png',
    difficulty: WorkoutDifficulty.intermediate,
    calories: 180,
    equipment: 'None',
    // EX019 and EX022 appended last so every existing exercise keeps its
    // original position — moved here from Advanced Strength Circuit so
    // both are reachable from the one Strength workout users already
    // open, instead of requiring a second, separate routine card.
    // Squat (1st), Lunges (2nd), and Push-Ups (3rd) are the same shared
    // canonical _squatV2/_lungesV2/_pushUpsV2 consts Full Body Burn uses —
    // real records, each referenced by both routines, never duplicated.
    // Glute Bridge/Calf Raises/Tricep Dips/Wall Push-Up/Donkey Kicks
    // (positions 4-8) stay on the generic _exercises() bridge, unchanged.
    exercises: [
      _squatV2,
      _lungesV2,
      _pushUpsV2,
      ..._exercises(['EX018', 'EX020', 'EX021', 'EX019', 'EX022']),
    ],
  ),
  Workout(
    id: 'advanced-strength-circuit',
    category: ExerciseCategory.strength,
    title: 'Advanced Strength Circuit',
    subtitle: 'Push further with a tougher strength circuit.',
    heroAssetPath: 'assets/glow_up/illustrations/workout-yoga-hero.png',
    difficulty: WorkoutDifficulty.advanced,
    calories: 160,
    equipment: 'Wall',
    exercises: _exercises(['EX023', 'EX024']),
  ),
  Workout(
    id: 'hiit-cardio-blast',
    category: ExerciseCategory.cardio,
    title: 'HIIT Cardio Blast',
    subtitle:
        'A fast-paced session to spike your heart rate and torch calories.',
    heroAssetPath: 'assets/glow_up/illustrations/workout-yoga-hero.png',
    difficulty: WorkoutDifficulty.advanced,
    calories: 240,
    equipment: 'None',
    // March In Place (2nd) is a raw entry, not part of _exercises([...])
    // below, because its real production id (EX076) doesn't exist in the
    // Tier 2 legacy catalog — see the doc comment on _marchInPlaceV2 in
    // routine_player_registry.dart. High Knees/Butt Kicks/Step Jacks/
    // Skaters/Shadow Boxing (3rd-7th) are also raw entries — their real
    // production ids (EX043-EX047) DO exist in the Tier 2 catalog (unlike
    // EX076), but the generic _exercises() bridge has no per-id override
    // for `thumbnailAssetPath`, needed here to point at each one's
    // approved V2 `sequence_preview.png` — see the doc comments on
    // _highKnees/_buttKicks/_stepJacks/_skaters/_shadowBoxing in
    // routine_player_registry.dart, including Side Steps (8th, EX048).
    exercises: [
      _jumpingJacksV2,
      const WorkoutExercise(
        id: 'march-in-place-v2',
        title: 'March In Place',
        durationSeconds: 40,
        catalogId: 'EX076',
        playbackType: ExercisePlaybackType.timer,
        thumbnailAssetPath:
            'assets/glow_up/exercises/march_in_place/female/v2/sequence_preview.png',
        steps: [
          ExerciseStep(
            label: 'NEUTRAL STANCE',
            instruction: 'Stand tall with your core engaged.',
          ),
          ExerciseStep(
            label: 'FIRST KNEE LIFT',
            instruction:
                'Lift one knee while swinging the opposite arm naturally.',
          ),
          ExerciseStep(
            label: 'FIRST FOOT LOWERING',
            instruction: 'Land softly as you lower your foot.',
          ),
          ExerciseStep(
            label: 'NEUTRAL TRANSITION',
            instruction: 'Return to a tall, neutral stance.',
          ),
          ExerciseStep(
            label: 'OPPOSITE KNEE LIFT',
            instruction: 'Lift the opposite knee while swinging the other arm.',
          ),
          ExerciseStep(
            label: 'OPPOSITE FOOT LOWERING',
            instruction: 'Land softly and prepare for the next step.',
          ),
        ],
      ),
      const WorkoutExercise(
        id: 'EX043_0',
        title: 'High Knees',
        durationSeconds: 35,
        catalogId: 'EX043',
        playbackType: ExercisePlaybackType.timer,
        thumbnailAssetPath:
            'assets/glow_up/exercises/high_knees/female/v2/sequence_preview.png',
        steps: [
          ExerciseStep(
            label: 'STAND',
            instruction: 'Stand tall with your core engaged.',
          ),
          ExerciseStep(
            label: 'DRIVE KNEE UP',
            instruction: 'Drive one knee up toward your chest.',
          ),
          ExerciseStep(
            label: 'KNEE AT PEAK',
            instruction: 'Bring your knee as high as you can, quickly.',
          ),
          ExerciseStep(
            label: 'SWITCH DOWN',
            instruction: 'Land softly and switch legs.',
          ),
          ExerciseStep(
            label: 'OPPOSITE KNEE UP',
            instruction: 'Drive the opposite knee up toward your chest.',
          ),
          ExerciseStep(
            label: 'RESET',
            instruction: 'Land softly and reset your stance.',
          ),
        ],
      ),
      const WorkoutExercise(
        id: 'EX044_0',
        title: 'Butt Kicks',
        durationSeconds: 35,
        catalogId: 'EX044',
        playbackType: ExercisePlaybackType.timer,
        thumbnailAssetPath:
            'assets/glow_up/exercises/butt_kicks/female/v2/sequence_preview.png',
        steps: [
          ExerciseStep(
            label: 'STAND',
            instruction: 'Stand tall with your core engaged.',
          ),
          ExerciseStep(
            label: 'KICK HEEL UP',
            instruction: 'Kick one heel up toward your glutes.',
          ),
          ExerciseStep(
            label: 'HEEL AT PEAK',
            instruction:
                'Bring your heel up quickly, staying light on your feet.',
          ),
          ExerciseStep(
            label: 'SWITCH DOWN',
            instruction: 'Land softly and switch legs.',
          ),
          ExerciseStep(
            label: 'OPPOSITE HEEL UP',
            instruction: 'Kick the opposite heel up toward your glutes.',
          ),
          ExerciseStep(
            label: 'RESET',
            instruction: 'Land softly and reset your stance.',
          ),
        ],
      ),
      const WorkoutExercise(
        id: 'EX045_0',
        title: 'Step Jacks',
        durationSeconds: 35,
        catalogId: 'EX045',
        playbackType: ExercisePlaybackType.timer,
        thumbnailAssetPath:
            'assets/glow_up/exercises/step_jacks/female/v2/sequence_preview.png',
        steps: [
          ExerciseStep(
            label: 'FEET TOGETHER',
            instruction: 'Stand with your feet together, arms at your sides.',
          ),
          ExerciseStep(
            label: 'STEP OUT',
            instruction: 'Step one foot out to the side.',
          ),
          ExerciseStep(
            label: 'ARMS RISE',
            instruction: 'Raise your arms out and up as you step.',
          ),
          ExerciseStep(
            label: 'ARMS OVERHEAD',
            instruction: 'Feet wide, arms overhead.',
          ),
          ExerciseStep(
            label: 'STEP BACK',
            instruction: 'Step your foot back in as your arms lower.',
          ),
          ExerciseStep(
            label: 'RESET',
            instruction: 'Feet together, arms back at your sides.',
          ),
        ],
      ),
      const WorkoutExercise(
        id: 'EX046_0',
        title: 'Skaters',
        durationSeconds: 40,
        catalogId: 'EX046',
        playbackType: ExercisePlaybackType.timer,
        thumbnailAssetPath:
            'assets/glow_up/exercises/skaters/female/v2/sequence_preview.png',
        steps: [
          ExerciseStep(
            label: 'STAND',
            instruction: 'Stand tall with your knees soft.',
          ),
          ExerciseStep(
            label: 'PUSH OFF',
            instruction: 'Push off one foot toward the side.',
          ),
          ExerciseStep(
            label: 'LEAP SIDE',
            instruction: 'Leap sideways, sweeping your back leg behind you.',
          ),
          ExerciseStep(
            label: 'LAND',
            instruction: 'Land softly and stay balanced.',
          ),
          ExerciseStep(
            label: 'SWITCH SIDE',
            instruction: 'Push off and leap to the opposite side.',
          ),
          ExerciseStep(
            label: 'RESET',
            instruction: 'Land softly and reset your stance.',
          ),
        ],
      ),
      const WorkoutExercise(
        id: 'EX047_0',
        title: 'Shadow Boxing',
        durationSeconds: 45,
        catalogId: 'EX047',
        playbackType: ExercisePlaybackType.sequenceLoop,
        thumbnailAssetPath:
            'assets/glow_up/exercises/shadow_boxing/female/v2/sequence_preview.png',
        steps: [
          ExerciseStep(
            label: 'GUARD UP',
            instruction: 'Stand tall with your fists up, guarding your face.',
          ),
          ExerciseStep(
            label: 'JAB',
            instruction: 'Throw a quick, controlled jab.',
          ),
          ExerciseStep(
            label: 'CROSS',
            instruction: 'Follow with a controlled cross.',
          ),
          ExerciseStep(
            label: 'GUARD RESET',
            instruction: 'Return your fists to guard.',
          ),
          ExerciseStep(
            label: 'OPPOSITE JAB',
            instruction: 'Throw a jab with the opposite hand.',
          ),
          ExerciseStep(
            label: 'RESET',
            instruction: 'Return to guard, staying light on your feet.',
          ),
        ],
      ),
      const WorkoutExercise(
        id: 'EX048_0',
        title: 'Side Steps',
        durationSeconds: 30,
        catalogId: 'EX048',
        playbackType: ExercisePlaybackType.timer,
        thumbnailAssetPath:
            'assets/glow_up/exercises/side_steps/female/v2/sequence_preview.png',
        steps: [
          ExerciseStep(
            label: 'STAND',
            instruction: 'Stand tall with your knees slightly bent.',
          ),
          ExerciseStep(
            label: 'STEP SIDE',
            instruction: 'Step one foot out to the side, staying low.',
          ),
          ExerciseStep(
            label: 'FEET TOGETHER LOW',
            instruction: 'Bring your feet back together, staying low.',
          ),
          ExerciseStep(
            label: 'HOLD LOW',
            instruction: 'Hold a low, athletic stance.',
          ),
          ExerciseStep(
            label: 'STEP OPPOSITE SIDE',
            instruction: 'Step the opposite foot out to the side, staying low.',
          ),
          ExerciseStep(
            label: 'RESET',
            instruction: 'Bring your feet back together, staying low.',
          ),
        ],
      ),
    ],
  ),
  Workout(
    id: 'full-body-burn',
    category: ExerciseCategory.cardio,
    title: 'Full Body Burn',
    subtitle: 'A complete mix of cardio and strength to torch calories.',
    heroAssetPath: 'assets/glow_up/illustrations/workout-yoga-hero.png',
    difficulty: WorkoutDifficulty.intermediate,
    calories: 220,
    equipment: 'None',
    // Jumping Jacks (1st) is the same shared canonical _jumpingJacksV2
    // const HIIT Cardio Blast uses; Squat (2nd), Lunges (3rd), and
    // Push-Ups (4th) are the same shared canonical _squatV2/_lungesV2/
    // _pushUpsV2 consts Strength Foundations uses — all real records,
    // each referenced by two routines, never duplicated. Glute Bridge
    // (5th) and Full Body Stretch (6th, Cardio version — a separate
    // record from Bedtime Meditation's own Full Body Stretch, EX061) are
    // raw entries, not part of _exercises([...]), because
    // `thumbnailAssetPath` needs to point at each one's approved V2
    // `sequence_preview.png`; the generic bridge has no per-id override
    // for that. Real production ids (EX018, EX002) are unchanged from
    // before this pass — see the doc comments on `_gluteBridge` and
    // `_fullBodyStretch` in routine_player_registry.dart.
    exercises: [
      _jumpingJacksV2,
      _squatV2,
      _lungesV2,
      _pushUpsV2,
      const WorkoutExercise(
        id: 'EX018_0',
        title: 'Glute Bridge',
        durationSeconds: 40,
        catalogId: 'EX018',
        playbackType: ExercisePlaybackType.reps,
        reps: 15,
        thumbnailAssetPath:
            'assets/glow_up/exercises/glute_bridge/female/v1/sequence_preview.png',
        steps: [
          ExerciseStep(
            label: 'START',
            instruction: 'Lie on your back with your knees bent and feet flat.',
          ),
          ExerciseStep(
            label: 'ENGAGE',
            instruction: 'Engage your core and squeeze your glutes.',
          ),
          ExerciseStep(
            label: 'LIFT',
            instruction: 'Lift your hips toward the ceiling.',
          ),
          ExerciseStep(label: 'TOP', instruction: 'Squeeze at the top.'),
          ExerciseStep(label: 'LOWER', instruction: 'Lower with control.'),
          ExerciseStep(
            label: 'RETURN',
            instruction: 'Return to the starting position.',
          ),
        ],
      ),
      const WorkoutExercise(
        id: 'EX002_0',
        title: 'Full Body Stretch',
        durationSeconds: 45,
        catalogId: 'EX002',
        playbackType: ExercisePlaybackType.sequenceLoop,
        thumbnailAssetPath:
            'assets/glow_up/exercises/full_body_stretch/female/v1/sequence_preview.png',
        steps: [
          ExerciseStep(
            label: 'REACH',
            instruction: 'Reach and lengthen through your whole body.',
          ),
          ExerciseStep(
            label: 'EXTEND',
            instruction: 'Extend through your arms and legs.',
          ),
          ExerciseStep(
            label: 'LENGTHEN',
            instruction: 'Lengthen through your whole body.',
          ),
          ExerciseStep(label: 'HOLD', instruction: 'Hold the full stretch.'),
          ExerciseStep(label: 'RELEASE', instruction: 'Release with control.'),
          ExerciseStep(
            label: 'RESET',
            instruction: 'Return to a relaxed starting position.',
          ),
        ],
      ),
    ],
  ),
  Workout(
    id: 'core-crusher',
    category: ExerciseCategory.core,
    title: 'Core Crusher',
    subtitle: 'Build core strength and stability from every angle.',
    heroAssetPath: 'assets/glow_up/illustrations/workout-yoga-hero.png',
    difficulty: WorkoutDifficulty.intermediate,
    calories: 150,
    equipment: 'None',
    // EX054 (Fire Hydrant) appended last so every existing exercise keeps
    // its original position/order — Core Crusher is the only workout
    // whose exercises fully resolve through the RoutinePlayer registry
    // today, so this is where a newly registry-only exercise like Fire
    // Hydrant becomes reachable from real production navigation, not the
    // legacy asset-less session flow.
    exercises: _exercises([
      'EX011',
      'EX012',
      'EX013',
      'EX014',
      'EX015',
      'EX016',
      'EX017',
      'EX054',
    ]),
  ),
  Workout(
    id: 'mobility-reset',
    category: ExerciseCategory.mobility,
    title: 'Mobility Reset',
    subtitle: 'Loosen up stiff joints with gentle mobility work.',
    heroAssetPath: 'assets/glow_up/illustrations/workout-yoga-hero.png',
    difficulty: WorkoutDifficulty.beginner,
    calories: 45,
    equipment: 'None',
    // All six exercises are raw entries, not part of _exercises([...]),
    // because their real production ids (EX070-EX075) don't exist in the
    // Tier 2 legacy catalog — see the doc comments on
    // _shoulderRollsV2/_armCirclesV2/_wristCirclesV2/_hipCirclesV2/
    // _thoracicRotationV2/_kneeCirclesV2 in routine_player_registry.dart.
    // The legacy EX036-EX041 placeholders these replace are left in
    // place, untouched, and simply no longer referenced here. Every
    // exercise now has a real Tier 1 definition, so the whole routine
    // resolves through RoutinePlayer with no ASSET_PENDING_APPROVAL
    // stand-in anywhere in it (Wrist Circles/Hip Circles were the last
    // two to get one — see EX072/EX073's doc comments for why their
    // instruction copy is derived from EX038/EX039's own pre-existing
    // approved Tier 2 placeholder text, not newly invented).
    //
    // `thumbnailAssetPath` on every entry points at that exercise's
    // approved `sequence_preview.png` (a wide filmstrip composite, not
    // any single pose frame) for the routine-detail/rest-screen
    // thumbnail; `steps` carries the same six approved instruction
    // fragments used by the Tier 1 definition, so the Tier 2 active
    // screen (only ever reached if a *future* Mobility exercise goes
    // back to pending) never shows a single static frame for any of
    // these six.
    exercises: [
      const WorkoutExercise(
        id: 'shoulder-rolls-v2',
        title: 'Shoulder Rolls',
        durationSeconds: 30,
        catalogId: 'EX070',
        playbackType: ExercisePlaybackType.sequenceLoop,
        thumbnailAssetPath:
            'assets/glow_up/exercises/shoulder_rolls/female/v2/sequence_preview.png',
        steps: [
          ExerciseStep(
            label: 'STAND TALL',
            instruction: 'Stand tall with your arms relaxed at your sides.',
          ),
          ExerciseStep(
            label: 'LIFT',
            instruction: 'Slowly lift your shoulders toward your ears.',
          ),
          ExerciseStep(
            label: 'ROLL BACK',
            instruction: 'Roll your shoulders backward.',
          ),
          ExerciseStep(
            label: 'LOWER',
            instruction: 'Lower your shoulders back down.',
          ),
          ExerciseStep(
            label: 'CIRCLE',
            instruction: 'Continue in a smooth circle.',
          ),
          ExerciseStep(
            label: 'CIRCLE CONTINUE',
            instruction: 'Keep the circle smooth as you continue.',
          ),
        ],
      ),
      const WorkoutExercise(
        id: 'arm-circles-v2',
        title: 'Arm Circles',
        durationSeconds: 30,
        catalogId: 'EX071',
        playbackType:
            ExercisePlaybackType.timer, // badge stays TIMER per the approved UI
        thumbnailAssetPath:
            'assets/glow_up/exercises/arm_circles/female/v2/sequence_preview.png',
        steps: [
          ExerciseStep(
            label: 'START',
            instruction: 'Stand tall and extend both arms out from your sides.',
          ),
          ExerciseStep(
            label: 'CIRCLE UP',
            instruction: 'Make slow, controlled circles.',
          ),
          ExerciseStep(
            label: 'CIRCLE FORWARD',
            instruction: 'Keep your torso stable.',
          ),
          ExerciseStep(
            label: 'CIRCLE DOWN',
            instruction: 'Keep your shoulders relaxed.',
          ),
          ExerciseStep(
            label: 'CIRCLE BACK',
            instruction: 'Continue the slow, controlled circles.',
          ),
          ExerciseStep(
            label: 'RESET',
            instruction: 'Keep your torso stable and shoulders relaxed.',
          ),
        ],
      ),
      const WorkoutExercise(
        id: 'wrist-circles-v2',
        title: 'Wrist Circles',
        durationSeconds: 20,
        catalogId: 'EX072',
        playbackType: ExercisePlaybackType.timer,
        thumbnailAssetPath:
            'assets/glow_up/exercises/wrist_circles/female/v2/sequence_preview.png',
        steps: [
          ExerciseStep(
            label: 'START',
            instruction:
                'Stand or sit comfortably and extend your arms in front of you.',
          ),
          ExerciseStep(
            label: 'CIRCLE OUT',
            instruction: 'Rotate your wrists slowly outward.',
          ),
          ExerciseStep(
            label: 'CIRCLE FORWARD',
            instruction: 'Continue the circle with control.',
          ),
          ExerciseStep(
            label: 'CIRCLE IN',
            instruction: 'Rotate your wrists slowly in the other direction.',
          ),
          ExerciseStep(
            label: 'CIRCLE BACK',
            instruction: 'Keep the circles small and gentle.',
          ),
          ExerciseStep(
            label: 'RESET',
            instruction: 'Continue the gentle circle before the next lap.',
          ),
        ],
      ),
      const WorkoutExercise(
        id: 'hip-circles-v2',
        title: 'Hip Circles',
        durationSeconds: 30,
        catalogId: 'EX073',
        playbackType: ExercisePlaybackType.timer,
        thumbnailAssetPath:
            'assets/glow_up/exercises/hip_circles/female/v2/sequence_preview.png',
        steps: [
          ExerciseStep(
            label: 'START',
            instruction:
                'Stand with your feet hip-width apart and hands on your hips.',
          ),
          ExerciseStep(
            label: 'CIRCLE FORWARD',
            instruction: 'Circle your hips slowly forward.',
          ),
          ExerciseStep(
            label: 'CIRCLE SIDE',
            instruction: 'Continue the circle to the side.',
          ),
          ExerciseStep(
            label: 'CIRCLE BACK',
            instruction: 'Circle your hips slowly backward.',
          ),
          ExerciseStep(
            label: 'CIRCLE SIDE',
            instruction: 'Continue the circle to the other side.',
          ),
          ExerciseStep(
            label: 'RESET',
            instruction: 'Keep the circle smooth as you continue.',
          ),
        ],
      ),
      const WorkoutExercise(
        id: 'thoracic-rotation-v2',
        title: 'Thoracic Rotation',
        durationSeconds: 35,
        catalogId: 'EX074',
        playbackType: ExercisePlaybackType
            .sideSequence, // badge stays SIDE SEQUENCE per the approved UI
        thumbnailAssetPath:
            'assets/glow_up/exercises/thoracic_rotation/female/v2/sequence_preview.png',
        steps: [
          ExerciseStep(
            label: 'NEUTRAL',
            instruction:
                'Stand with your feet slightly wider than hip-width and bend your knees softly.',
          ),
          ExerciseStep(
            label: 'LEFT ROTATION',
            instruction:
                'Hold your hands together at chest level and rotate your upper body to the left.',
          ),
          ExerciseStep(
            label: 'DEEPER LEFT ROTATION',
            instruction:
                'Keep your hips and feet facing forward as you rotate a little deeper.',
          ),
          ExerciseStep(
            label: 'NEUTRAL',
            instruction: 'Return your upper body to center.',
          ),
          ExerciseStep(
            label: 'RIGHT ROTATION',
            instruction: 'Rotate your upper body to the right.',
          ),
          ExerciseStep(
            label: 'DEEPER RIGHT ROTATION',
            instruction:
                'Keep your hips and feet facing forward as you rotate a little deeper.',
          ),
        ],
      ),
      const WorkoutExercise(
        id: 'knee-circles-v2',
        title: 'Knee Circles',
        durationSeconds: 25,
        catalogId: 'EX075',
        playbackType: ExercisePlaybackType.timer,
        thumbnailAssetPath:
            'assets/glow_up/exercises/knee_circles/female/v2/sequence_preview.png',
        steps: [
          ExerciseStep(
            label: 'START',
            instruction: 'Stand with your feet and knees together.',
          ),
          ExerciseStep(
            label: 'BEND',
            instruction:
                'Bend your knees slightly and place your hands just above them.',
          ),
          ExerciseStep(
            label: 'CIRCLE RIGHT',
            instruction: 'Guide both knees through a small, gentle circle.',
          ),
          ExerciseStep(
            label: 'CIRCLE FORWARD',
            instruction: 'Keep your feet planted as the circle continues.',
          ),
          ExerciseStep(
            label: 'CIRCLE LEFT',
            instruction: 'Keep the circle small and controlled.',
          ),
          ExerciseStep(
            label: 'CIRCLE BACK',
            instruction: 'Continue the gentle circle before the next lap.',
          ),
        ],
      ),
    ],
  ),
  Workout(
    id: 'recovery-flow',
    category: ExerciseCategory.recovery,
    title: 'Recovery Flow',
    subtitle: 'Ease sore muscles with a gentle recovery sequence.',
    heroAssetPath: 'assets/glow_up/illustrations/workout-yoga-hero.png',
    difficulty: WorkoutDifficulty.beginner,
    calories: 40,
    equipment: 'None',
    exercises: _exercises(['EX049', 'EX050', 'EX051', 'EX052']),
  ),
  Workout(
    id: 'pre-swim-prep',
    // No literal "activity-preparation" category exists in
    // ExerciseCategory — `mobility` is the closest existing fit (it
    // already houses Mobility Reset, the app's other pre-activity warm-up
    // routine) rather than inventing a new category type. Disclosed
    // choice, not a silent one — see the implementation report.
    category: ExerciseCategory.mobility,
    title: 'Pre-Swim Prep',
    subtitle:
        'Open your shoulders, hips and ankles before getting in the water.',
    heroAssetPath: 'assets/glow_up/illustrations/workout-yoga-hero.png',
    difficulty: WorkoutDifficulty.beginner,
    calories: 35,
    equipment: 'None',
    // Official V1 Pre-Swim spec (owner decision, superseding the earlier
    // 8-exercise/285s version — there is exactly one Pre-Swim definition,
    // never two competing ones). Source: the staging design package at
    // assets/glow_up/exercises/pre_swim/ (routine_manifest.json + README)
    // for the exercise order and the 45/60/60/60/45/60/60 per-exercise
    // seconds (390s raw exercise time) — the staging source's own
    // 9-minute/540s total and its `duration_minutes` field are explicitly
    // NOT used (superseded by this owner decision). The 5-second
    // transition between exercises (390 + 6×5 = 420s = 7:00 exactly) is a
    // new, explicit product decision — it is not from the staging docs.
    // All seven exercise IDs are pre-existing, already-approved Tier 1
    // definitions, never renumbered or duplicated: EX051/EX050/EX052/EX049
    // are Recovery Flow's own shared exercises (played here at Pre-Swim's
    // own approved durations via `useCatalogDurations`, which never
    // changes Recovery's); EX077/EX078/EX079 are Pre-Swim's own
    // previously-approved, unshared ids. `useCatalogDurations: true` +
    // `restSecondsOverride: 5` are this routine's own opt-in — see
    // `Workout`'s doc comments.
    useCatalogDurations: true,
    restSecondsOverride: 5,
    exercises: [
      const WorkoutExercise(
        id: 'EX051_preswim',
        title: 'Standing Chest Opener',
        durationSeconds: 45,
        catalogId: 'EX051',
        playbackType: ExercisePlaybackType.hold,
      ),
      const WorkoutExercise(
        id: 'EX079_preswim',
        title: 'Triceps & Lat Stretch',
        durationSeconds: 60,
        catalogId: 'EX079',
        playbackType: ExercisePlaybackType.hold,
      ),
      const WorkoutExercise(
        id: 'EX078_preswim',
        title: 'Streamline Side Bend',
        durationSeconds: 60,
        catalogId: 'EX078',
        playbackType: ExercisePlaybackType.timer,
      ),
      const WorkoutExercise(
        id: 'EX077_preswim',
        title: 'Dryland Freestyle Reach',
        durationSeconds: 60,
        catalogId: 'EX077',
        playbackType: ExercisePlaybackType.timer,
      ),
      const WorkoutExercise(
        id: 'EX050_preswim',
        title: 'Standing Calf Stretch',
        durationSeconds: 45,
        catalogId: 'EX050',
        playbackType: ExercisePlaybackType.hold,
      ),
      const WorkoutExercise(
        id: 'EX052_preswim',
        title: 'Seated 90/90 Hip Switch',
        durationSeconds: 60,
        catalogId: 'EX052',
        playbackType: ExercisePlaybackType.sideSequence,
      ),
      const WorkoutExercise(
        id: 'EX049_preswim',
        title: 'Figure-Four Stretch',
        durationSeconds: 60,
        catalogId: 'EX049',
        playbackType: ExercisePlaybackType.hold,
      ),
    ],
  ),
];

Workout? workoutById(String id) {
  for (final w in kWorkoutCatalog) {
    if (w.id == id) return w;
  }
  return null;
}

List<Workout> workoutsForCategory(ExerciseCategory category) =>
    kWorkoutCatalog.where((w) => w.category == category).toList();
