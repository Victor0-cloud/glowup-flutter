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
    // Legs Up Wall (1st) and Reclined Butterfly (2nd) are raw entries, not
    // part of _exercises(['EX032', 'EX033', ...]) below, because their real
    // production ids (EX066/EX067) don't exist in the Tier 2 legacy
    // catalog — see the doc comments on _legsUpWallV2/_reclinedButterflyV2
    // in routine_player_registry.dart. _exercises()'s exerciseById(id)!
    // lookup would crash on either, the same reason Bedtime Meditation's
    // EX061-EX065 are also raw entries. The legacy EX032/EX033 placeholders
    // these replace are left in place, untouched, and simply no longer
    // referenced here. Neck Release (3rd) and Box Breathing (4th) keep
    // their existing EX034/EX035 legacy ids — no Tier 1 id assigned yet,
    // per explicit instruction — so this workout still resolves through
    // the Tier 2 legacy WorkoutSessionScreen as a whole (see
    // `_routinePlayerRoutineFor` in app_router.dart: a [Workout] only
    // reaches Tier 1 RoutinePlayer if *every* exercise has a Tier 1
    // definition), exactly like Bedtime Meditation did before EX065 was
    // finished. This is a known, temporary state, not a bug: it flips to
    // RoutinePlayer automatically, with no further code change here, once
    // Neck Release/Box Breathing also get real Tier 1 definitions.
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
      ..._exercises(['EX034', 'EX035']),
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
    exercises: _exercises([
      'EX007',
      'EX008',
      'EX010',
      'EX018',
      'EX020',
      'EX021',
      'EX019',
      'EX022',
    ]),
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
    exercises: _exercises([
      'EX009',
      'EX042',
      'EX043',
      'EX044',
      'EX045',
      'EX046',
      'EX047',
      'EX048',
    ]),
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
    exercises: _exercises([
      'EX009',
      'EX007',
      'EX008',
      'EX010',
      'EX018',
      'EX002',
    ]),
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
    exercises: _exercises([
      'EX036',
      'EX037',
      'EX038',
      'EX039',
      'EX040',
      'EX041',
    ]),
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
];

Workout? workoutById(String id) {
  for (final w in kWorkoutCatalog) {
    if (w.id == id) return w;
  }
  return null;
}

List<Workout> workoutsForCategory(ExerciseCategory category) =>
    kWorkoutCatalog.where((w) => w.category == category).toList();
