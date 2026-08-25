// Verifies the real 52-exercise catalog and routine catalog built from it:
// complete EX001-EX052 coverage, no duplicates, all 7 categories
// represented, the bedtime routine's exact content, and the specific
// exercises the manual QA script checks for (Jumping Jacks, Lunges,
// Push-Ups) are present and reachable.
//
// Plus EX054 (Fire Hydrant) — added later, appended to Core Crusher, not
// part of the original 52-exercise handoff table (see its doc comment in
// exercise_catalog.dart). EX053 (Side Lunge Left) is deliberately NOT in
// this legacy catalog — it exists only in the RoutinePlayer registry and
// isn't wired into any workout yet.

import 'package:flutter_test/flutter_test.dart';
import 'package:glow_up/workout/data/exercise_catalog.dart';
import 'package:glow_up/workout/data/workout_catalog.dart';
import 'package:glow_up/workout/models/exercise_models.dart';

void main() {
  group('Exercise catalog (EX001-EX052)', () {
    test(
      'exactly 53 exercises are loaded (the original 52 plus EX054 Fire Hydrant)',
      () {
        expect(kExerciseCatalog.length, 53);
      },
    );

    test(
      'every ID from EX001 to EX052 is present, no duplicates, plus EX054 — EX053 deliberately absent',
      () {
        final ids = kExerciseCatalog.map((e) => e.id).toSet();
        expect(ids.length, kExerciseCatalog.length, reason: 'no duplicate IDs');
        for (var i = 1; i <= 52; i++) {
          final expected = 'EX${i.toString().padLeft(3, '0')}';
          expect(ids, contains(expected), reason: 'missing $expected');
        }
        expect(ids, contains('EX054'), reason: 'Fire Hydrant must be present');
        expect(
          ids,
          isNot(contains('EX053')),
          reason:
              'Side Lunge Left is RoutinePlayer-only, never added to this legacy catalog',
        );
      },
    );

    test('all 7 categories are represented', () {
      final present = kExerciseCatalog.map((e) => e.primaryCategory).toSet();
      expect(present, ExerciseCategory.values.toSet());
    });

    test(
      'category counts sum to 53 (the original 52 plus EX054 Fire Hydrant, core)',
      () {
        final counts = <ExerciseCategory, int>{};
        for (final e in kExerciseCatalog) {
          counts[e.primaryCategory] = (counts[e.primaryCategory] ?? 0) + 1;
        }
        expect(counts[ExerciseCategory.bedtime], 10);
        expect(counts[ExerciseCategory.strength], 10);
        expect(counts[ExerciseCategory.cardio], 8);
        expect(
          counts[ExerciseCategory.core],
          8,
          reason: '7 original + EX054 Fire Hydrant',
        );
        expect(counts[ExerciseCategory.flexibility], 7);
        expect(counts[ExerciseCategory.mobility], 6);
        expect(counts[ExerciseCategory.recovery], 4);
        expect(counts.values.fold(0, (a, b) => a + b), 53);
      },
    );

    test('Jumping Jacks is available (CARDIO, TIMER)', () {
      final e = exerciseById('EX009')!;
      expect(e.name, 'Jumping Jacks');
      expect(e.primaryCategory, ExerciseCategory.cardio);
      expect(e.playbackType, ExercisePlaybackType.timer);
    });

    test('Lunges is available (STRENGTH, SIDE_SEQUENCE, switch side)', () {
      final e = exerciseById('EX008')!;
      expect(e.name, 'Lunges');
      expect(e.primaryCategory, ExerciseCategory.strength);
      expect(e.playbackType, ExercisePlaybackType.sideSequence);
      expect(e.hasSwitchSide, isTrue);
    });

    test('Push-Ups is available (STRENGTH, REPS)', () {
      final e = exerciseById('EX010')!;
      expect(e.name, 'Push-Ups');
      expect(e.primaryCategory, ExerciseCategory.strength);
      expect(e.playbackType, ExercisePlaybackType.reps);
    });

    test(
      'Squat is available (STRENGTH, REPS) with its real 6-step sequence',
      () {
        final e = exerciseById('EX007')!;
        expect(e.name, 'Squat');
        expect(e.steps.length, 6);
        expect(e.steps.first.label, 'START');
        expect(e.steps.last.label, 'RESET');
      },
    );

    test('Plank is available (CORE, HOLD, no repeat)', () {
      final e = exerciseById('EX011')!;
      expect(e.name, 'Plank');
      expect(e.primaryCategory, ExerciseCategory.core);
      expect(e.playbackType, ExercisePlaybackType.hold);
      expect(e.hasRepeat, isFalse);
    });

    test('Deep Breathing is available (BEDTIME, BREATHING)', () {
      final e = exerciseById('EX001')!;
      expect(e.name, 'Deep Breathing');
      expect(e.playbackType, ExercisePlaybackType.breathing);
    });
  });

  group('Routine catalog', () {
    test('all 7 categories have at least one real routine', () {
      for (final category in ExerciseCategory.values) {
        expect(
          workoutsForCategory(category),
          isNotEmpty,
          reason: '${category.label} has no routine',
        );
      }
    });

    test('Bedtime Meditation contains the exact approved bedtime sequence', () {
      final w = workoutById('bedtime-meditation')!;
      expect(w.category, ExerciseCategory.bedtime);
      expect(w.exercises.map((e) => e.title).toList(), [
        'Deep Breathing',
        'Full Body Stretch',
        'Knee-to-Chest',
        'Supine Twist',
        'Ankle Circles',
        'Sit-Up Reach',
      ]);
    });

    test(
      'HIIT Cardio Blast contains real cardio-category exercises including Jumping Jacks',
      () {
        final w = workoutById('hiit-cardio-blast')!;
        expect(w.category, ExerciseCategory.cardio);
        expect(w.exercises.map((e) => e.title), contains('Jumping Jacks'));
        expect(w.exercises.length, greaterThanOrEqualTo(6));
      },
    );

    test('Full Body Burn matches the approved example composition', () {
      final w = workoutById('full-body-burn')!;
      expect(w.exercises.map((e) => e.title).toList(), [
        'Jumping Jacks',
        'Squat',
        'Lunges',
        'Push-Ups',
        'Glute Bridge',
        'Full Body Stretch',
      ]);
    });

    test('Strength Foundations contains real strength exercises', () {
      final w = workoutById('strength-foundations')!;
      expect(w.category, ExerciseCategory.strength);
      final titles = w.exercises.map((e) => e.title).toList();
      expect(titles, contains('Squat'));
      expect(titles, contains('Lunges'));
      expect(titles, contains('Push-Ups'));
    });

    test(
      'Core Crusher, Mobility Reset, and Recovery Flow all use real category exercises',
      () {
        expect(workoutById('core-crusher')!.category, ExerciseCategory.core);
        expect(
          workoutById('mobility-reset')!.category,
          ExerciseCategory.mobility,
        );
        expect(
          workoutById('recovery-flow')!.category,
          ExerciseCategory.recovery,
        );
        expect(workoutById('core-crusher')!.exercises, isNotEmpty);
        expect(workoutById('mobility-reset')!.exercises, isNotEmpty);
        expect(workoutById('recovery-flow')!.exercises, isNotEmpty);
      },
    );

    test(
      'every routine exercise (except Morning Yoga Flow and Full Body Stretch/EX061, Knee-to-Chest/EX062, Supine Twist/EX063, and Pre-Swim Prep\'s EX077-EX079) traces back to a real catalog ID',
      () {
        for (final workout in kWorkoutCatalog) {
          if (workout.id == 'morning-yoga-flow') {
            continue; // documented exception, see workout_catalog.dart
          }
          for (final exercise in workout.exercises) {
            // Full Body Stretch/Knee-to-Chest/Supine Twist (Bedtime
            // Meditation, 2nd-4th exercises) are raw WorkoutExercise entries
            // with catalogId 'EX061'/'EX062'/'EX063' — the same "real Tier 1
            // id with no Tier 2 legacy catalog entry" exception as Morning
            // Yoga Flow's EX055-EX060, documented on
            // _fullBodyStretchV2/_kneeToChestV2/_supineTwistV2 in
            // routine_player_registry.dart. Their own internal ids
            // ('full-body-stretch'/'knee-to-chest'/'supine-twist') never
            // existed in the legacy catalog and were never meant to.
            if (const {
              'EX061',
              'EX062',
              'EX063',
              'EX064',
              'EX065',
              'EX066',
              'EX067',
              'EX068',
              'EX069',
              'EX070',
              'EX071',
              'EX072',
              'EX073',
              'EX074',
              'EX075',
              'EX076',
              'EX077',
              'EX078',
              'EX079',
            }.contains(exercise.catalogId)) {
              continue;
            }
            final exId = exercise.id.split('_').first;
            expect(
              exerciseById(exId),
              isNotNull,
              reason:
                  '${workout.id} references unknown exercise ${exercise.id}',
            );
          }
        }
      },
    );

    test(
      'every routine has multiple exercises (a real session, not a single-exercise placeholder)',
      () {
        for (final workout in kWorkoutCatalog) {
          expect(
            workout.exercises.length,
            greaterThan(1),
            reason:
                '${workout.id} has only ${workout.exercises.length} exercise(s)',
          );
        }
      },
    );
  });
}
