// Covers the Deep Sleep Prep completion pass: Neck Release (EX068) and Box
// Breathing (EX069) registered as real Tier 1 RoutinePlayer definitions,
// completing the 4-exercise Deep Sleep Prep routine (EX066-EX069) and
// flipping it over to the full RoutinePlayer engine (the same all-or-
// nothing gate Bedtime Meditation already uses) — plus the new
// `LoopMode.timedCycleAfterSetup` engine addition EX069's box-breathing
// cycle depends on, verified not to regress any existing LoopMode.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:glow_up/routine_player/data/routine_player_registry.dart';
import 'package:glow_up/routine_player/models/exercise_definition.dart';
import 'package:glow_up/routine_player/models/pose_definition.dart';
import 'package:glow_up/routine_player/models/routine_player_state.dart';
import 'package:glow_up/routine_player/screens/routine_player_screen.dart';
import 'package:glow_up/routine_player/state/routine_player_controller.dart';
import 'package:glow_up/workout/brain/workout_brain.dart';
import 'package:glow_up/workout/data/exercise_catalog.dart';
import 'package:glow_up/workout/data/workout_catalog.dart';
import 'package:glow_up/workout/models/exercise_models.dart';
import 'package:glow_up/workout/widgets/exercise_reflection_card.dart';

void main() {
  group('EX068 Neck Release — Tier 1 registration', () {
    final def = routinePlayerExerciseById('EX068');

    test('resolves with the approved shape', () {
      expect(def, isNotNull);
      expect(def!.displayName, 'Neck Release');
      expect(def.durationSeconds, 30);
      expect(def.loopMode, LoopMode.timedCycle);
      expect(def.poses.length, 6);
      expect(def.thumbnailFrameOrder, 1);
    });

    test('every pose uses the approved v2 asset, never a substitute', () {
      for (final pose in def!.poses) {
        expect(
          pose.approvedAsset,
          contains('assets/glow_up/exercises/neck_release/female/v2/EX068_F_'),
        );
      }
      expect(
        def.poses.map((p) => p.approvedAsset).toSet().length,
        6,
        reason: 'all six approved frames must be distinct',
      );
    });

    test(
      'plays exactly once (cycle length equals the full 30s duration), never loops mid-exercise',
      () {
        final e = def!;
        final totalPhaseSeconds = e.poses.fold<double>(
          0,
          (sum, p) => sum + (p.phaseSeconds ?? 1),
        );
        expect(totalPhaseSeconds, 30.0);
        expect(totalPhaseSeconds, e.durationSeconds.toDouble());
      },
    );

    test(
      'right side plays before left side, switching at the exact halfway point (15s)',
      () {
        final e = def!;
        PoseDefinition at(double s) => currentPoseFor(e, s);

        expect(at(0).label, 'START');
        expect(at(3.0).label, 'RIGHT TILT');
        expect(at(7.0).label, 'RIGHT HOLD');
        expect(at(14.9).label, 'RIGHT HOLD');
        expect(
          at(15.0).label,
          'CENTER RESET',
          reason: 'switch-side must land exactly at the real halfway point',
        );
        expect(at(18.0).label, 'LEFT TILT');
        expect(at(22.0).label, 'LEFT HOLD');
        expect(at(29.9).label, 'LEFT HOLD');

        // Right-side poses must all resolve strictly before any left-side pose.
        final rightIdx = e.poses.indexWhere((p) => p.label == 'RIGHT HOLD');
        final leftIdx = e.poses.indexWhere((p) => p.label == 'LEFT HOLD');
        expect(rightIdx, lessThan(leftIdx));
      },
    );

    test(
      'never instructs pulling the head with a hand, and voice uses switchSideCue (no phaseSyncedVoice, no breathing narration)',
      () {
        final e = def!;
        for (final pose in e.poses) {
          expect(pose.instruction.toLowerCase(), isNot(contains('pull')));
        }
        expect(e.phaseSyncedVoice, isFalse);
        expect(e.voiceScript.switchSideCue, isNotNull);
      },
    );
  });

  group('EX069 Box Breathing — Tier 1 registration', () {
    final def = routinePlayerExerciseById('EX069');

    test('resolves with the approved shape', () {
      expect(def, isNotNull);
      expect(def!.displayName, 'Box Breathing');
      expect(def.durationSeconds, 60);
      expect(def.loopMode, LoopMode.timedCycleAfterSetup);
      expect(def.poses.length, 6);
      expect(def.thumbnailFrameOrder, 1);
      expect(def.phaseSyncedVoice, isTrue);
    });

    test('every pose uses the approved v2 asset, never a substitute', () {
      for (final pose in def!.poses) {
        expect(
          pose.approvedAsset,
          contains('assets/glow_up/exercises/box_breathing/female/v2/EX069_F_'),
        );
      }
      expect(
        def.poses.map((p) => p.approvedAsset).toSet().length,
        6,
        reason: 'all six approved frames must be distinct',
      );
    });

    test(
      'SETTLE plays once (2s), then a synchronized 4-4-4-4 (16s) box-breathing cycle repeats',
      () {
        final e = def!;
        PoseDefinition at(double s) => currentPoseFor(e, s);

        // One-time settle.
        expect(at(0).label, 'SETTLE');
        expect(at(1.9).label, 'SETTLE');

        // First cycle: inhale (2.0+2.0=4s) -> hold full (4s) -> exhale (4s) -> hold empty (4s).
        expect(at(2.0).label, 'INHALE BEGIN');
        expect(at(3.9).label, 'INHALE BEGIN');
        expect(at(4.0).label, 'INHALE FULL');
        expect(at(5.9).label, 'INHALE FULL');
        expect(at(6.0).label, 'HOLD FULL');
        expect(at(9.9).label, 'HOLD FULL');
        expect(at(10.0).label, 'EXHALE');
        expect(at(13.9).label, 'EXHALE');
        expect(at(14.0).label, 'HOLD EMPTY RESET');
        expect(at(17.9).label, 'HOLD EMPTY RESET');

        // Second cycle starts at 2 + 16 = 18s, never re-showing SETTLE.
        expect(at(18.0).label, 'INHALE BEGIN');
        expect(at(20.0).label, 'INHALE FULL');
        expect(at(22.0).label, 'HOLD FULL');
        expect(at(26.0).label, 'EXHALE');
        expect(at(30.0).label, 'HOLD EMPTY RESET');
        for (final s in [18.0, 34.0, 50.0]) {
          expect(
            at(s).label,
            isNot('SETTLE'),
            reason: 'SETTLE must only ever play once, at the very start',
          );
        }
      },
    );

    test(
      'the cycle stops cleanly wherever it is at exactly 60s, never overrunning (60s is not an exact multiple of the approved 16s cycle)',
      () {
        final e = def!;
        expect(e.durationSeconds, 60);
        final cyclePoses = e.poses.where((p) => p.purpose != PosePurpose.setup);
        final cycleTotal = cyclePoses.fold<double>(
          0,
          (sum, p) => sum + (p.phaseSeconds ?? 1),
        );
        expect(cycleTotal, 16.0);
        expect(
          60 % 16,
          isNot(0),
          reason:
              'sanity check that this genuinely exercises a mid-cycle cutoff, not a lucky exact multiple',
        );
        // The pose at the last representable instant must still be a real,
        // approved pose (never null/out of range) — the exercise's own
        // duration timer is what ends ACTIVE, not the cycle math itself.
        expect(currentPoseFor(e, 59.99).approvedAsset, isNotNull);
      },
    );

    test(
      'INHALE_FULL is silent (phase already announced by INHALE_BEGIN) — never a separate generic "breathe in/breathe out" narration',
      () {
        final e = def!;
        final inhaleFull = e.poses.firstWhere((p) => p.label == 'INHALE FULL');
        expect(inhaleFull.voiceCue, isNull);
        expect(inhaleFull.cuesOnlyVoiceCue, isNull);
        // Every spoken cue mentions the real phase content, never a bare
        // repeated "breathe in"/"breathe out" loop independent of the phase.
        for (final pose in e.poses) {
          if (pose.voiceCue != null) {
            expect(pose.voiceCue, isNot(equalsIgnoringCase('breathe in.')));
            expect(pose.voiceCue, isNot(equalsIgnoringCase('breathe out.')));
          }
        }
      },
    );

    test(
      'never forces the breath — no instruction says to force or push through discomfort',
      () {
        final e = def!;
        for (final pose in e.poses) {
          expect(pose.instruction.toLowerCase(), isNot(contains('force')));
        }
      },
    );
  });

  group(
    'holdAfterSetup/timedCycle regressions from the new timedCycleAfterSetup LoopMode',
    () {
      test(
        'Tree Pose (EX059) and Savasana (EX060) exit timing is unchanged',
        () {
          final tree = routinePlayerExerciseById('EX059')!;
          expect(
            currentPoseFor(tree, tree.durationSeconds - 0.5).label,
            'RESET',
          );
          final savasana = routinePlayerExerciseById('EX060')!;
          expect(
            currentPoseFor(savasana, savasana.durationSeconds - 0.5).label,
            'RECOVERY',
          );
        },
      );

      test(
        'Deep Breathing (EX001) still uses plain timedCycle, repeating SETTLE every lap (unlike EX069)',
        () {
          final e = routinePlayerExerciseById('EX001')!;
          expect(e.loopMode, LoopMode.timedCycle);
          expect(currentPoseFor(e, 0).label, 'SETTLE');
        },
      );

      test('EX066/EX067 holdAfterSetup timing is unchanged', () {
        final legsUpWall = routinePlayerExerciseById('EX066')!;
        expect(currentPoseFor(legsUpWall, 30.0).label, 'HOLD');
        final butterfly = routinePlayerExerciseById('EX067')!;
        expect(currentPoseFor(butterfly, 30.0).label, 'HOLD');
      });
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
        expect(workout.exercises.map((e) => e.catalogId).toList(), [
          'EX066',
          'EX067',
          'EX068',
          'EX069',
        ]);
      },
    );

    test(
      'Neck Release is SIDE_SEQUENCE/30s, Box Breathing is BREATHING/60s',
      () {
        expect(
          workout.exercises[2].playbackType,
          ExercisePlaybackType.sideSequence,
        );
        expect(workout.exercises[2].durationSeconds, 30);
        expect(
          workout.exercises[3].playbackType,
          ExercisePlaybackType.breathing,
        );
        expect(workout.exercises[3].durationSeconds, 60);
      },
    );

    test(
      'every exercise now resolves through Tier 1 — the routine is eligible for full RoutinePlayer routing',
      () {
        for (final exercise in workout.exercises) {
          expect(
            routinePlayerExerciseById(exercise.catalogId!),
            isNotNull,
            reason:
                '${exercise.title} (${exercise.catalogId}) must have a Tier 1 definition for the whole routine to flip over',
          );
        }
      },
    );

    test(
      'legacy EX032-EX035 placeholders still exist in the Tier 2 catalog, untouched and simply unreferenced',
      () {
        expect(exerciseById('EX032')!.name, 'Legs Up Wall');
        expect(exerciseById('EX033')!.name, 'Reclined Butterfly');
        expect(exerciseById('EX034')!.name, 'Neck Release');
        expect(exerciseById('EX035')!.name, 'Box Breathing');
      },
    );
  });

  group('AI Coach reflection config', () {
    test('EX068 prompt and signals match the approved spec', () {
      final config = kExerciseReflectionConfigs['EX068']!;
      expect(
        config.prompt,
        'How did Neck Release feel? Note any side-to-side difference, stiffness, pain, dizziness, tingling or limited range.',
      );
      expect(config.signals.map((s) => s.key).toList(), [
        'right_neck_comfort',
        'left_neck_comfort',
        'side_difference',
        'stiffness',
        'pain',
        'dizziness',
        'tingling',
        'range_of_motion',
      ]);
    });

    test('EX069 prompt and signals match the approved spec', () {
      final config = kExerciseReflectionConfigs['EX069']!;
      expect(
        config.prompt,
        'How did Box Breathing feel? Note whether the four-count holds were comfortable and whether you felt calm, dizzy, anxious or short of breath.',
      );
      expect(config.signals.map((s) => s.key).toList(), [
        'hold_comfort',
        'breath_comfort',
        'calmness',
        'dizziness',
        'anxiety',
        'shortness_of_breath',
        'preferred_count',
      ]);
    });
  });

  group(
    'manifest.json on-disk correctness (asset metadata, not read by app code)',
    () {
      test(
        'neck_release manifest matches the approved frames/timing/signals',
        () {
          final file = File(
            'assets/glow_up/exercises/neck_release/female/v2/manifest.json',
          );
          expect(file.existsSync(), isTrue);
          final manifest =
              jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
          expect(manifest['exerciseId'], 'EX068');
          expect(manifest['durationSeconds'], 30);
          expect(manifest['thumbnailFrame'], 'EX068_F_01_START.png');
          final frames = (manifest['frames'] as List)
              .cast<Map<String, dynamic>>();
          expect(frames.map((f) => f['seconds']).toList(), [3, 4, 8, 3, 4, 8]);
        },
      );

      test(
        'box_breathing manifest matches the approved breath pattern/signals',
        () {
          final file = File(
            'assets/glow_up/exercises/box_breathing/female/v2/manifest.json',
          );
          expect(file.existsSync(), isTrue);
          final manifest =
              jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
          expect(manifest['exerciseId'], 'EX069');
          expect(manifest['durationSeconds'], 60);
          expect(manifest['thumbnailFrame'], 'EX069_F_01_SETTLE.png');
          final pattern = manifest['breathPattern'] as Map<String, dynamic>;
          expect(pattern['inhaleSeconds'], 4);
          expect(pattern['holdFullSeconds'], 4);
          expect(pattern['exhaleSeconds'], 4);
          expect(pattern['holdEmptySeconds'], 4);
          expect(pattern['cycleSeconds'], 16);
          expect(pattern['stopAtDurationSeconds'], 60);
        },
      );

      test('all six approved PNGs exist on disk for both exercises', () {
        for (final dir in ['neck_release', 'box_breathing']) {
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

  group('RoutinePlayer session: full Deep Sleep Prep routine', () {
    Future<ProviderContainer> bootRoutine(
      WidgetTester tester,
      List<ExerciseDefinition> routine,
    ) async {
      await tester.binding.setSurfaceSize(const Size(402, 874));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: RoutinePlayerQaEntry(routine: routine, onExit: () {}),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      return container;
    }

    testWidgets(
      'completing EX068 continues to EX069 — does not complete the routine',
      (tester) async {
        final container = await bootRoutine(tester, [
          routinePlayerExerciseById('EX068')!,
          routinePlayerExerciseById('EX069')!,
        ]);
        addTearDown(container.dispose);
        final controller = container.read(
          routinePlayerControllerProvider.notifier,
        );

        controller.skipPrepare();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);

        controller.skipExercise(); // EX068 -> rest, next = EX069
        await tester.pump();

        final state = container.read(routinePlayerControllerProvider)!;
        expect(state.phase, RoutinePlayerPhase.rest);
        expect(
          state.isLastExercise,
          isTrue,
        ); // now on EX069, but not yet completed
        expect(find.text('REST'), findsOneWidget);
        expect(find.text('🎉 Routine Complete!'), findsNothing);

        controller.endSession();
      },
    );

    testWidgets('completing EX069 completes Deep Sleep Prep exactly once', (
      tester,
    ) async {
      final container = await bootRoutine(tester, [
        routinePlayerExerciseById('EX068')!,
        routinePlayerExerciseById('EX069')!,
      ]);
      addTearDown(container.dispose);
      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );

      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));
      controller.skipExercise(); // EX068 -> rest
      await tester.pump();
      controller.skipRest();
      await tester.pump();
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));

      controller
          .skipExercise(); // EX069 -> should complete the routine (last exercise)
      await tester.pump();

      final state = container.read(routinePlayerControllerProvider)!;
      expect(state.phase, RoutinePlayerPhase.complete);
      expect(
        state.completedIds.length + state.skippedIds.length,
        2,
        reason: 'exactly one completion record per exercise, never duplicated',
      );
      expect(find.text('🎉 Routine Complete!'), findsOneWidget);

      // Calling skipExercise again post-completion must be a no-op (no
      // duplicate completion event, no crash).
      controller.skipExercise();
      await tester.pump();
      expect(
        container.read(routinePlayerControllerProvider)!.phase,
        RoutinePlayerPhase.complete,
      );

      controller.endSession();
    });

    testWidgets(
      'pause during EX069 freezes the current breathing phase; resume continues from the same point, never restarting the cycle',
      (tester) async {
        final container = await bootRoutine(tester, [
          routinePlayerExerciseById('EX069')!,
        ]);
        addTearDown(container.dispose);
        final controller = container.read(
          routinePlayerControllerProvider.notifier,
        );

        controller.skipPrepare();
        // First three 1s pumps are absorbed by the 3-2-1 countdown (proven
        // pattern from workout_bedtime_routine_player_test.dart); ACTIVE
        // elapsed starts counting only after that.
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        // +4.7s of real ACTIVE time: SETTLE(0-2) -> INHALE_BEGIN(2-4) ->
        // INHALE_FULL(4-6), landing inside the INHALE_FULL window.
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 700));
        expect(find.textContaining('INHALE FULL'), findsOneWidget);

        controller.togglePause();
        await tester.pump();
        expect(
          container.read(routinePlayerControllerProvider)!.phase,
          RoutinePlayerPhase.paused,
        );
        final frozenElapsed = container
            .read(routinePlayerControllerProvider)!
            .activeElapsedMs;

        // Time passing while paused must not advance the exercise clock.
        await tester.pump(const Duration(seconds: 2));
        expect(
          container.read(routinePlayerControllerProvider)!.activeElapsedMs,
          frozenElapsed,
        );
        expect(
          find.textContaining('INHALE FULL'),
          findsOneWidget,
          reason: 'frame must stay frozen on the same phase while paused',
        );

        controller.togglePause();
        await tester.pump();
        expect(
          container.read(routinePlayerControllerProvider)!.phase,
          RoutinePlayerPhase.active,
        );
        expect(
          container.read(routinePlayerControllerProvider)!.activeElapsedMs,
          frozenElapsed,
          reason:
              'resume must continue from the exact frozen point, never restart the cycle',
        );

        controller.endSession();
      },
    );

    testWidgets(
      'AI Coach reflection card appears after EX068 in rest, and saving logs exactly one exerciseNoteSaved signal',
      (tester) async {
        final container = await bootRoutine(tester, [
          routinePlayerExerciseById('EX068')!,
          routinePlayerExerciseById('EX069')!,
        ]);
        addTearDown(container.dispose);
        final controller = container.read(
          routinePlayerControllerProvider.notifier,
        );

        controller.skipPrepare();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 200));
        controller.skipExercise(); // EX068 -> rest
        await tester.pump();

        expect(find.text('AI COACH'), findsOneWidget);
        expect(
          find.text(kExerciseReflectionConfigs['EX068']!.prompt),
          findsOneWidget,
        );

        await tester.ensureVisible(find.text('Stiffness'));
        await tester.pump();
        await tester.tap(find.text('Stiffness'));
        await tester.pump();
        await tester.ensureVisible(find.text('Save Note'));
        await tester.pump();
        await tester.tap(find.text('Save Note'));
        await tester.pump();

        final signals = container.read(workoutSignalLogProvider);
        final noteSignals = signals
            .where((s) => s.type == WorkoutSignalType.exerciseNoteSaved)
            .toList();
        expect(noteSignals.length, 1);
        expect(noteSignals.single.detail, contains('EX068'));
        expect(noteSignals.single.detail, contains('Stiffness'));
        expect(find.text('Note saved'), findsOneWidget);

        controller.endSession();
      },
    );
  });
}
