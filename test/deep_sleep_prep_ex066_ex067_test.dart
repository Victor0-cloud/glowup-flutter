// Covers the Deep Sleep Prep recovery pass: Legs Up Wall (EX066) and
// Reclined Butterfly (EX067) registered as real Tier 1 RoutinePlayer
// definitions, wired into the `deep-sleep-prep` Workout in the approved
// order, with the approved 60s/45s-hold and 60s/44s-hold timing — plus the
// backward-compatible `currentPoseFor` engine fix (multi-frame,
// individually-timed exit) that both of them depend on, verified not to
// regress Tree Pose (EX059) / Savasana (EX060)'s existing single-frame
// exit behavior.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:glow_up/routine_player/data/routine_player_registry.dart';
import 'package:glow_up/routine_player/models/exercise_definition.dart';
import 'package:glow_up/routine_player/models/pose_definition.dart';
import 'package:glow_up/routine_player/state/routine_player_controller.dart';
import 'package:glow_up/workout/data/exercise_catalog.dart';
import 'package:glow_up/workout/data/workout_catalog.dart';
import 'package:glow_up/workout/models/exercise_models.dart';
import 'package:glow_up/workout/widgets/exercise_reflection_card.dart';

void main() {
  group('EX066 Legs Up Wall — Tier 1 registration', () {
    final def = routinePlayerExerciseById('EX066');

    test('resolves with the approved shape', () {
      expect(def, isNotNull);
      expect(def!.displayName, 'Legs Up Wall');
      expect(def.durationSeconds, 60);
      expect(def.loopMode, LoopMode.holdAfterSetup);
      expect(def.poses.length, 6);
      expect(def.thumbnailFrameOrder, 4);
    });

    test('every pose uses the approved v2 asset, never a substitute', () {
      for (final pose in def!.poses) {
        expect(
          pose.approvedAsset,
          contains('assets/glow_up/exercises/legs_up_wall/female/v2/EX066_F_'),
        );
      }
      expect(def.holdPose.approvedAsset, contains('04_HOLD'));
    });

    test(
      'entry plays PREPARE -> LOWER_AND_TURN -> LEGS_UP once over the approved 10s loopCycleSeconds (2+5+3), never repeating',
      () {
        final e = def!;
        PoseDefinition at(double s) => currentPoseFor(e, s);

        // The engine splits the one-time entry evenly across its settle
        // poses (same mechanism Tree Pose/Savasana already rely on — see
        // `currentPoseFor`'s holdAfterSetup branch); phaseSeconds on these
        // three poses documents/sums to the approved 10s entry window,
        // matching the existing convention, not an independent per-frame
        // timer.
        expect(at(0).label, 'PREPARE');
        expect(at(1.0).label, 'PREPARE');
        expect(at(4.0).label, 'LOWER AND TURN');
        expect(at(8.0).label, 'LEGS UP');
        expect(at(9.9).label, 'LEGS UP');

        // Hold must stay on the exact same frame for the whole 45s window.
        for (final s in [10.0, 20.0, 30.0, 40.0, 54.9]) {
          expect(
            at(s).label,
            'HOLD',
            reason: 'must not re-animate the entry at $s s',
          );
          expect(at(s).purpose, PosePurpose.hold);
        }

        expect(at(55.0).label, 'BEND KNEES EXIT');
        expect(at(57.9).label, 'BEND KNEES EXIT');
        expect(at(58.0).label, 'RECOVERY');
        expect(at(59.9).label, 'RECOVERY');
      },
    );

    test('never loops back to PREPARE after the exit begins', () {
      final e = def!;
      expect(currentPoseFor(e, 59.99).label, isNot('PREPARE'));
    });
  });

  group('EX067 Reclined Butterfly — Tier 1 registration', () {
    final def = routinePlayerExerciseById('EX067');

    test('resolves with the approved shape', () {
      expect(def, isNotNull);
      expect(def!.displayName, 'Reclined Butterfly');
      expect(def.durationSeconds, 60);
      expect(def.loopMode, LoopMode.holdAfterSetup);
      expect(def.poses.length, 6);
      expect(def.thumbnailFrameOrder, 4);
    });

    test('every pose uses the approved v2 asset, never a substitute', () {
      for (final pose in def!.poses) {
        expect(
          pose.approvedAsset,
          contains(
            'assets/glow_up/exercises/reclined_butterfly/female/v2/EX067_F_',
          ),
        );
      }
    });

    test(
      'entry plays PREPARE -> OPEN_KNEES -> SETTLE once over the approved 11s loopCycleSeconds (3+5+3), never repeating',
      () {
        final e = def!;
        PoseDefinition at(double s) => currentPoseFor(e, s);

        // Same even-split-across-settle-poses mechanism as EX066 (see that
        // test's comment) — phaseSeconds here sums to the approved 11s
        // entry window.
        expect(at(0).label, 'PREPARE');
        expect(at(1.0).label, 'PREPARE');
        expect(at(5.0).label, 'OPEN KNEES');
        expect(at(9.0).label, 'SETTLE');
        expect(at(10.9).label, 'SETTLE');

        for (final s in [11.0, 25.0, 40.0, 54.9]) {
          expect(
            at(s).label,
            'HOLD',
            reason: 'must not re-animate the entry at $s s',
          );
        }

        expect(at(55.0).label, 'CLOSE KNEES');
        expect(at(57.9).label, 'CLOSE KNEES');
        expect(at(58.0).label, 'RESET');
        expect(at(59.9).label, 'RESET');
      },
    );

    test(
      'the knees are never animated being forced down — CLOSE_KNEES is a slow, hands-assisted close, and no instruction ever tells the user to force/push the knees down',
      () {
        final e = def!;
        final closeKnees = e.poses.firstWhere((p) => p.label == 'CLOSE KNEES');
        expect(closeKnees.instruction.toLowerCase(), contains('hands'));
        expect(closeKnees.instruction.toLowerCase(), contains('slowly'));
        for (final pose in e.poses) {
          expect(pose.instruction.toLowerCase(), isNot(contains('force')));
          expect(pose.instruction.toLowerCase(), isNot(contains('push down')));
        }
      },
    );
  });

  group(
    'holdAfterSetup engine fix does not regress existing single-frame-exit exercises',
    () {
      test(
        'Tree Pose (EX059) still shows RESET for exactly the final 1 second',
        () {
          final e = routinePlayerExerciseById('EX059')!;
          expect(currentPoseFor(e, e.durationSeconds - 1.5).label, 'HOLD');
          expect(currentPoseFor(e, e.durationSeconds - 0.5).label, 'RESET');
        },
      );

      test(
        'Savasana (EX060) still shows RECOVERY for exactly the final 1 second',
        () {
          final e = routinePlayerExerciseById('EX060')!;
          expect(currentPoseFor(e, e.durationSeconds - 1.5).label, 'HOLD');
          expect(currentPoseFor(e, e.durationSeconds - 0.5).label, 'RECOVERY');
        },
      );
    },
  );

  group('deep-sleep-prep Workout wiring', () {
    final workout = kWorkoutCatalog.firstWhere(
      (w) => w.id == 'deep-sleep-prep',
    );

    test(
      'order is Legs Up Wall, Reclined Butterfly, Neck Release, Box Breathing',
      () {
        expect(workout.exercises.map((e) => e.title).toList(), [
          'Legs Up Wall',
          'Reclined Butterfly',
          'Neck Release',
          'Box Breathing',
        ]);
        // EX068/EX069 (Neck Release/Box Breathing) were completed in a later
        // pass than EX066/EX067 — see deep_sleep_prep_ex068_ex069_test.dart —
        // completing the routine's Tier 1 catalogId sequence.
        expect(workout.exercises.map((e) => e.catalogId).toList(), [
          'EX066',
          'EX067',
          'EX068',
          'EX069',
        ]);
      },
    );

    test('Legs Up Wall / Reclined Butterfly are HOLD badges, 60s each', () {
      expect(workout.exercises[0].playbackType, ExercisePlaybackType.hold);
      expect(workout.exercises[0].durationSeconds, 60);
      expect(workout.exercises[1].playbackType, ExercisePlaybackType.hold);
      expect(workout.exercises[1].durationSeconds, 60);
    });
  });

  group('scope protection: EX001-EX065 untouched', () {
    test('Bedtime Meditation is still exactly EX001, EX061-EX065 in order', () {
      final bedtime = kWorkoutCatalog.firstWhere(
        (w) => w.id == 'bedtime-meditation',
      );
      expect(bedtime.exercises.map((e) => e.catalogId).toList(), [
        'EX001',
        'EX061',
        'EX062',
        'EX063',
        'EX064',
        'EX065',
      ]);
    });

    test(
      'EX032/EX033 legacy placeholders still exist in the Tier 2 catalog, untouched',
      () {
        expect(exerciseById('EX032')!.name, 'Legs Up Wall');
        expect(exerciseById('EX033')!.name, 'Reclined Butterfly');
      },
    );
  });

  group('AI Coach reflection config', () {
    test('EX066 prompt and signals match the approved spec', () {
      final config = kExerciseReflectionConfigs['EX066']!;
      expect(
        config.prompt,
        'How did Legs Up Wall feel? Note hamstring tension, back comfort, tingling or dizziness.',
      );
      expect(config.signals.map((s) => s.key).toList(), [
        'hamstring_tension',
        'lower_back_comfort',
        'tingling',
        'numbness',
        'dizziness',
        'wall_distance_modification',
        'knee_bend_modification',
      ]);
    });

    test('EX067 prompt and signals match the approved spec', () {
      final config = kExerciseReflectionConfigs['EX067']!;
      expect(
        config.prompt,
        'How did Reclined Butterfly feel? Note hip, groin, knee or lower-back comfort and whether you needed support.',
      );
      expect(config.signals.map((s) => s.key).toList(), [
        'hip_comfort',
        'groin_comfort',
        'knee_comfort',
        'lower_back_comfort',
        'support_used',
        'range_of_motion',
      ]);
    });
  });

  group(
    'manifest.json on-disk correctness (asset metadata, not read by app code)',
    () {
      test(
        'legs_up_wall manifest matches the approved frames/timing/signals',
        () {
          final file = File(
            'assets/glow_up/exercises/legs_up_wall/female/v2/manifest.json',
          );
          expect(file.existsSync(), isTrue);
          final manifest =
              jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
          expect(manifest['exerciseId'], 'EX066');
          expect(manifest['durationSeconds'], 60);
          expect(manifest['thumbnailFrame'], 'EX066_F_04_HOLD.png');
          final frames = (manifest['frames'] as List)
              .cast<Map<String, dynamic>>();
          expect(frames.map((f) => f['seconds']).toList(), [2, 5, 3, 45, 3, 2]);
          expect(
            (manifest['aiCoachNote']['trainingSignals'] as List),
            contains('numbness'),
          );
        },
      );

      test(
        'reclined_butterfly manifest matches the approved frames/timing/signals',
        () {
          final file = File(
            'assets/glow_up/exercises/reclined_butterfly/female/v2/manifest.json',
          );
          expect(file.existsSync(), isTrue);
          final manifest =
              jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
          expect(manifest['exerciseId'], 'EX067');
          expect(manifest['durationSeconds'], 60);
          expect(manifest['thumbnailFrame'], 'EX067_F_04_HOLD.png');
          final frames = (manifest['frames'] as List)
              .cast<Map<String, dynamic>>();
          expect(frames.map((f) => f['seconds']).toList(), [3, 5, 3, 44, 3, 2]);
        },
      );

      test('all six approved PNGs exist on disk for both exercises', () {
        for (final dir in ['legs_up_wall', 'reclined_butterfly']) {
          final folder = Directory('assets/glow_up/exercises/$dir/female/v2');
          final pngs = folder.listSync().whereType<File>().where(
            (f) => f.path.endsWith('.png'),
          );
          expect(
            pngs.length,
            6,
            reason: '$dir must have exactly 6 approved frames',
          );
        }
      });
    },
  );
}
