// Architecture-level invariants for the two-tier workout system (see the
// doc comment on `_routinePlayerRoutineFor` in lib/routing/app_router.dart
// for the tier model). These tests don't cover any single exercise's
// behavior — that's routine_player_engine_test.dart's job — they lock in
// the shape of the system as a whole: unique ids, no orphaned references,
// no cross-tier drift, and no accidental production dependency on the
// dev-only QA route.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:glow_up/routine_player/audio/music_manager.dart';
import 'package:glow_up/routine_player/data/routine_player_registry.dart';
import 'package:glow_up/routine_player/state/routine_player_controller.dart';
import 'package:glow_up/routine_player/voice/voice_coach.dart';
import 'package:glow_up/routine_player/voice/voice_speaker.dart';
import 'package:glow_up/routing/app_router.dart';
import 'package:glow_up/workout/brain/workout_brain.dart';
import 'package:glow_up/workout/data/exercise_catalog.dart';
import 'package:glow_up/workout/data/workout_catalog.dart';
import 'package:glow_up/workout/models/exercise_models.dart';

void main() {
  group('1. Exercise IDs are unique within each tier', () {
    test('Tier 2 (legacy kExerciseCatalog) has no duplicate IDs', () {
      final ids = kExerciseCatalog.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test(
      'Tier 1 (kRoutinePlayerExercisesById) — every value\'s own .id matches its map key',
      () {
        kRoutinePlayerExercisesById.forEach((key, definition) {
          expect(
            definition.id,
            key,
            reason:
                'a copy-pasted ExerciseDefinition with the wrong id would silently resolve under the wrong key',
          );
        });
      },
    );
  });

  group(
    '2. No duplicate exercise names within a tier (IDs must be the only thing distinguishing exercises)',
    () {
      test('Tier 2 (legacy) names are unique', () {
        final names = kExerciseCatalog.map((e) => e.name).toList();
        expect(
          names.toSet().length,
          names.length,
          reason:
              'a repeated name would make two distinct EX ids indistinguishable to the user',
        );
      });

      test('Tier 1 (RoutinePlayer) display names are unique', () {
        final names = kRoutinePlayerExercisesById.values
            .map((e) => e.displayName)
            .toList();
        expect(names.toSet().length, names.length);
      });
    },
  );

  group(
    '3/7/8. Every routine exercise resolves through a real tier — never an orphaned reference',
    () {
      test(
        'every WorkoutExercise across kWorkoutCatalog resolves via Tier 1, Tier 2, or an explicit static poseAssetPath override',
        () {
          for (final workout in kWorkoutCatalog) {
            // Documented, pre-existing exception (see exercise_catalog_test.dart):
            // Morning Yoga Flow uses its own custom non-EX ids end to end, by
            // design — not an orphaned reference, a deliberately separate
            // one-off routine.
            if (workout.id == 'morning-yoga-flow') continue;
            for (final exercise in workout.exercises) {
              final resolvesTier1 =
                  exercise.catalogId != null &&
                  routinePlayerExerciseById(exercise.catalogId!) != null;
              final resolvesTier2 =
                  exercise.catalogId != null &&
                  exerciseById(exercise.catalogId!) != null;
              final hasStaticOverride =
                  exercise.poseAssetPath !=
                  null; // Morning Yoga Flow's Sun Salutation/Downward Dog, documented exception
              expect(
                resolvesTier1 || resolvesTier2 || hasStaticOverride,
                isTrue,
                reason:
                    '"${workout.id}" references "${exercise.title}" (catalogId: ${exercise.catalogId}), which resolves through neither tier nor a static override — an orphaned reference',
              );
            }
          }
        },
      );

      test(
        'every workout has at least one exercise (no empty/missing routine)',
        () {
          for (final workout in kWorkoutCatalog) {
            expect(
              workout.exercises,
              isNotEmpty,
              reason: '"${workout.id}" has no exercises',
            );
          }
        },
      );
    },
  );

  group(
    '4. Every fully-verified RoutinePlayer exercise has the expected frame count',
    () {
      test(
        'a non-bilateral exercise where every pose has a real approvedAsset has exactly 6 frames',
        () {
          for (final exercise in kRoutinePlayerExercisesById.values) {
            if (exercise.bilateralFrames != null) {
              continue; // none currently — guarded below in case a future exercise adds one
            }
            final allVerified = exercise.poses.every(
              (p) => p.approvedAsset != null,
            );
            if (!allVerified) {
              continue; // unverified placeholder exercises (e.g. EX013-016) are allowed fewer/no frames
            }
            expect(
              exercise.poses.length,
              6,
              reason:
                  '${exercise.displayName} has ${exercise.poses.length} verified frames, expected exactly 6',
            );
          }
        },
      );

      test(
        'no current exercise uses bilateralFrames — Lunges V2 replaced its old left/right pair with a single 6-frame set (the mechanism itself stays available in the model for any future bilateral exercise)',
        () {
          final lunges = kRoutinePlayerExercisesById['EX008']!;
          expect(lunges.bilateralFrames, isNull);
          for (final exercise in kRoutinePlayerExercisesById.values) {
            expect(
              exercise.bilateralFrames,
              isNull,
              reason:
                  '${exercise.displayName} unexpectedly uses bilateralFrames',
            );
          }
        },
      );
    },
  );

  group(
    '6. All 7 master categories are represented and every workout\'s category is one of them',
    () {
      test('every ExerciseCategory value has at least one workout', () {
        for (final category in ExerciseCategory.values) {
          expect(
            workoutsForCategory(category),
            isNotEmpty,
            reason:
                '${category.label} has no workout — a category with nothing under it',
          );
        }
      });

      test(
        'workoutsForCategory never returns a workout from a different category (no cross-category leakage)',
        () {
          for (final category in ExerciseCategory.values) {
            for (final workout in workoutsForCategory(category)) {
              expect(workout.category, category);
            }
          }
        },
      );

      test(
        'every workout in the catalog has exactly one of the 7 valid categories (guaranteed by the enum type, asserted here for documentation)',
        () {
          for (final workout in kWorkoutCatalog) {
            expect(ExerciseCategory.values, contains(workout.category));
          }
        },
      );
    },
  );

  group('10. Preview and active player resolve from the same exercise source', () {
    test(
      'RoutinePlayerState.currentExercise and .nextExercise are drawn from the exact same routine list — never a second copy',
      () async {
        final controller = RoutinePlayerController(
          VoiceCoach(SilentSpeaker()),
          MusicManager(),
          WorkoutSignalLog(),
        );
        addTearDown(controller.dispose);
        final routine = [
          kRoutinePlayerExercisesById['EX011']!,
          kRoutinePlayerExercisesById['EX012']!,
        ];
        controller.startRoutine(routine);
        final state = controller.state!;
        expect(
          identical(state.routine, routine),
          isTrue,
          reason:
              'the state must hold the exact routine list passed in, not a copy — otherwise preview/active could drift apart',
        );
        expect(identical(state.currentExercise, routine[0]), isTrue);
        expect(identical(state.nextExercise, routine[1]), isTrue);
        controller.endSession();
      },
    );
  });

  group('11. Dev QA route stays separate from production navigation', () {
    test(
      'the literal dev QA route path never appears in production screen/widget source, only in its own router registration and the debug-only QA_ROUTE bootstrap',
      () {
        const needle = '/dev/routine-player-qa';
        final libDir = Directory('lib');
        final offenders = <String>[];
        for (final entity in libDir.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          // The route's own definition/registration, the optional debug
          // bootstrap, and doc comments inside the QA infrastructure itself
          // (the registry and the QA entry widget) are the only legitimate
          // references — none of these are production navigation code.
          if (entity.path.contains('app_router.dart') ||
              entity.path.contains('main.dart') ||
              entity.path.contains('routine_player_registry.dart') ||
              entity.path.contains('routine_player_screen.dart')) {
            continue;
          }
          final content = entity.readAsStringSync();
          if (content.contains(needle)) offenders.add(entity.path);
        }
        expect(
          offenders,
          isEmpty,
          reason:
              'no production widget/screen may hardcode the dev QA route path: $offenders',
        );
      },
    );

    test(
      'AppRoutes.routinePlayerQa is a distinct path from the production session route (never aliased/reused)',
      () {
        expect(
          AppRoutes.routinePlayerQa,
          isNot(AppRoutes.routinePlayerSession),
        );
        expect(AppRoutes.routinePlayerQa, startsWith('/dev/'));
        expect(AppRoutes.routinePlayerSession, isNot(startsWith('/dev/')));
      },
    );
  });
}
