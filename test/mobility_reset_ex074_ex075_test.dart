// Covers Mobility Reset's completion pass: Thoracic Rotation (EX074) and
// Knee Circles (EX075) registered as real Tier 1 RoutinePlayer
// definitions, filling the 5th/6th slots of the six-exercise routine.
//
// Update: Wrist Circles (EX072) and Hip Circles (EX073) — left as Tier
// 2-only placeholders when this file was first written — were promoted
// to real Tier 1 definitions in a later repair pass (see
// mobility_reset_repair_ex072_ex073_test.dart for the dedicated
// regression coverage of that fix, including the ASSET_PENDING_APPROVAL
// root-cause repair). The "stay Tier 2-only" assertions below were
// updated accordingly.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:glow_up/app/glow_up_app.dart';
import 'package:glow_up/onboarding/state/onboarding_controller.dart';
import 'package:glow_up/routine_player/data/routine_player_registry.dart';
import 'package:glow_up/routine_player/models/exercise_definition.dart';
import 'package:glow_up/routine_player/models/routine_player_state.dart';
import 'package:glow_up/routine_player/state/routine_player_controller.dart';
import 'package:glow_up/routing/app_router.dart';
import 'package:glow_up/workout/data/exercise_catalog.dart';
import 'package:glow_up/workout/data/workout_catalog.dart';
import 'package:glow_up/workout/models/exercise_models.dart';
import 'package:glow_up/workout/models/workout_models.dart';
import 'package:glow_up/workout/state/workout_controller.dart';

Future<ProviderContainer> _bootAtWorkoutHub(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(402, 874));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer();
  container.read(onboardingControllerProvider.notifier).completeOnboarding();
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const GlowUpApp()),
  );
  appRouter.go(AppRoutes.workout);
  await tester.pumpAndSettle();
  return container;
}

bool _hasAssetImageContaining(WidgetTester tester, String needle) {
  return tester.widgetList<Image>(find.byType(Image)).any((img) {
    final provider = img.image;
    return provider is AssetImage && provider.assetName.contains(needle);
  });
}

void main() {
  group('EX074 Thoracic Rotation — Tier 1 registration', () {
    final def = routinePlayerExerciseById('EX074');

    test('resolves with the approved shape', () {
      expect(def, isNotNull);
      expect(def!.displayName, 'Thoracic Rotation');
      expect(def.category, 'Mobility');
      expect(def.durationSeconds, 35);
      expect(def.loopMode, LoopMode.continuousLoop);
      expect(def.poses.length, 6);
    });

    test(
      'every pose uses its own approved asset, in F_01->F_06 order, never a substitute',
      () {
        final e = def!;
        for (var i = 0; i < 6; i++) {
          expect(e.poses[i].order, i + 1);
          expect(
            e.poses[i].approvedAsset,
            'assets/glow_up/exercises/thoracic_rotation/female/v2/F_0${i + 1}.png',
          );
        }
        expect(e.poses.map((p) => p.approvedAsset).toSet().length, 6);
      },
    );

    test(
      'cycles continuously through the neutral/left/deeper-left/neutral/right/deeper-right sequence, never freezing',
      () {
        final e = def!;
        final perFrame = e.loopCycleSeconds / 6;
        final labels = e.poses.map((p) => p.label).toList();
        expect(labels, [
          'NEUTRAL',
          'LEFT ROTATION',
          'DEEPER LEFT ROTATION',
          'NEUTRAL',
          'RIGHT ROTATION',
          'DEEPER RIGHT ROTATION',
        ]);
        for (var i = 0; i < 6; i++) {
          expect(currentPoseFor(e, i * perFrame + perFrame / 2).order, i + 1);
        }
        // Wraps cleanly back to F_01 on the next lap.
        expect(currentPoseFor(e, e.loopCycleSeconds + perFrame / 2).order, 1);
        expect(currentPoseFor(e, 34.9).approvedAsset, isNotNull);
      },
    );

    test(
      'no image is flipped/mirrored — each pose points at its own distinct approved file',
      () {
        final e = def!;
        final assets = e.poses.map((p) => p.approvedAsset).toList();
        expect(
          assets.toSet().length,
          assets.length,
          reason:
              'a mirrored/reused asset would collapse two distinct approved frames onto the same file',
        );
      },
    );
  });

  group('EX075 Knee Circles — Tier 1 registration', () {
    final def = routinePlayerExerciseById('EX075');

    test('resolves with the approved shape', () {
      expect(def, isNotNull);
      expect(def!.displayName, 'Knee Circles');
      expect(def.category, 'Mobility');
      expect(def.durationSeconds, 25);
      expect(def.loopMode, LoopMode.continuousLoop);
      expect(def.poses.length, 6);
    });

    test(
      'every pose uses its own approved asset, in F_01->F_06 order, never a substitute',
      () {
        final e = def!;
        for (var i = 0; i < 6; i++) {
          expect(e.poses[i].order, i + 1);
          expect(
            e.poses[i].approvedAsset,
            'assets/glow_up/exercises/knee_circles/female/v2/F_0${i + 1}.png',
          );
        }
        expect(e.poses.map((p) => p.approvedAsset).toSet().length, 6);
      },
    );

    test(
      'animates all six frames continuously throughout the 25s timer, never a single static frame',
      () {
        final e = def!;
        final perFrame = e.loopCycleSeconds / 6;
        final seenOrders = <int>{};
        for (var t = 0.0; t < e.durationSeconds; t += 0.1) {
          seenOrders.add(currentPoseFor(e, t).order);
        }
        expect(
          seenOrders.length,
          6,
          reason: 'all six frames must actually appear during the 25s window',
        );
        expect(currentPoseFor(e, perFrame / 2).order, 1);
      },
    );
  });

  group('Mobility Reset Workout wiring — final six-exercise routine', () {
    final workout = kWorkoutCatalog.firstWhere((w) => w.id == 'mobility-reset');

    test('exactly six exercises, in the approved order', () {
      expect(workout.category, ExerciseCategory.mobility);
      expect(workout.exercises.length, 6);
      expect(workout.exercises.map((e) => e.title).toList(), [
        'Shoulder Rolls',
        'Arm Circles',
        'Wrist Circles',
        'Hip Circles',
        'Thoracic Rotation',
        'Knee Circles',
      ]);
      expect(workout.exercises.map((e) => e.durationSeconds).toList(), [
        30,
        30,
        20,
        30,
        35,
        25,
      ]);
    });

    test(
      'routine-card summary: Mobility Reset, ~3 min, Beginner, 6 exercises',
      () {
        expect(workout.title, 'Mobility Reset');
        expect(workout.difficulty, WorkoutDifficulty.beginner);
        expect(workout.exercises.length, 6);
        expect(workout.totalSeconds, 170); // 30+30+20+30+35+25
        expect(workout.totalMinutes, 3);
      },
    );

    test(
      'Thoracic Rotation badge is SIDE_SEQUENCE, Knee Circles badge is TIMER',
      () {
        expect(
          workout.exercises[4].playbackType,
          ExercisePlaybackType.sideSequence,
        );
        expect(workout.exercises[5].playbackType, ExercisePlaybackType.timer);
      },
    );

    test(
      'no blank thumbnail remains anywhere in Mobility Reset — all six point at a real, existing approved sequence_preview.png',
      () {
        final expected = {
          'Shoulder Rolls':
              'assets/glow_up/exercises/shoulder_rolls/female/v2/sequence_preview.png',
          'Arm Circles':
              'assets/glow_up/exercises/arm_circles/female/v2/sequence_preview.png',
          'Wrist Circles':
              'assets/glow_up/exercises/wrist_circles/female/v2/sequence_preview.png',
          'Hip Circles':
              'assets/glow_up/exercises/hip_circles/female/v2/sequence_preview.png',
          'Thoracic Rotation':
              'assets/glow_up/exercises/thoracic_rotation/female/v2/sequence_preview.png',
          'Knee Circles':
              'assets/glow_up/exercises/knee_circles/female/v2/sequence_preview.png',
        };
        for (final exercise in workout.exercises) {
          final path = exercise.thumbnailAssetPath;
          expect(
            path,
            isNotNull,
            reason: '${exercise.title} must not have a blank thumbnail',
          );
          expect(path, expected[exercise.title]);
          expect(
            File(path!).existsSync(),
            isTrue,
            reason: '${exercise.title} thumbnail must be a real file on disk',
          );
        }
      },
    );

    test(
      'Wrist Circles / Hip Circles now have real Tier 1 definitions (EX072/EX073) — see mobility_reset_repair_ex072_ex073_test.dart',
      () {
        expect(
          routinePlayerExerciseById('EX038'),
          isNull,
          reason:
              'the legacy Tier 2 placeholder must stay untouched, never promoted itself',
        );
        expect(
          routinePlayerExerciseById('EX039'),
          isNull,
          reason:
              'the legacy Tier 2 placeholder must stay untouched, never promoted itself',
        );
        expect(routinePlayerExerciseById('EX072'), isNotNull);
        expect(routinePlayerExerciseById('EX073'), isNotNull);
        expect(exerciseById('EX038')!.name, 'Wrist Circles');
        expect(exerciseById('EX039')!.name, 'Hip Circles');
      },
    );

    test(
      'EX074/EX075 have unique ids, distinct from their legacy EX040/EX041 placeholders (left untouched)',
      () {
        expect(
          routinePlayerExerciseById('EX074')!.id,
          isNot(routinePlayerExerciseById('EX075')!.id),
        );
        expect(exerciseById('EX040')!.name, 'Thoracic Rotation');
        expect(exerciseById('EX041')!.name, 'Knee Circles');
        expect(
          routinePlayerExerciseById('EX040'),
          isNull,
          reason: 'EX040 must stay Tier 2-only, untouched',
        );
        expect(
          routinePlayerExerciseById('EX041'),
          isNull,
          reason: 'EX041 must stay Tier 2-only, untouched',
        );
      },
    );

    test(
      'EX070/EX071 (Shoulder Rolls/Arm Circles) remain exactly as previously implemented',
      () {
        final shoulderRolls = routinePlayerExerciseById('EX070')!;
        expect(shoulderRolls.durationSeconds, 30);
        expect(shoulderRolls.poses.length, 6);
        final armCircles = routinePlayerExerciseById('EX071')!;
        expect(armCircles.durationSeconds, 30);
        expect(armCircles.poses.length, 6);
      },
    );

    test(
      'all six approved PNGs (plus preview) exist on disk for Thoracic Rotation and Knee Circles',
      () {
        for (final dir in ['thoracic_rotation', 'knee_circles']) {
          final folder = Directory('assets/glow_up/exercises/$dir/female/v2');
          final pngs = folder.listSync().whereType<File>().where(
            (f) => f.path.endsWith('.png'),
          );
          expect(
            pngs.length,
            7,
            reason: '$dir must have exactly 6 frames + 1 preview',
          );
        }
      },
    );
  });

  testWidgets(
    'Mobility Reset -> Start Routine launches Shoulder Rolls first, and the full six-exercise session completes exactly once after Knee Circles with no trailing rest screen',
    (tester) async {
      final container = await _bootAtWorkoutHub(tester);
      addTearDown(container.dispose);

      await tester.ensureVisible(find.text('Mobility'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mobility'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mobility Reset'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Start Workout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      expect(
        find.text('Shoulder Rolls'),
        findsWidgets,
        reason: 'Start Routine must launch EX070 Shoulder Rolls first',
      );
      expect(container.read(routinePlayerControllerProvider), isNotNull);
      expect(
        container.read(workoutSessionControllerProvider),
        isNull,
        reason: 'must never also start a legacy session',
      );

      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );

      // Fast-forward through all six exercises: skip prepare, skip exercise,
      // skip rest, repeat. skipExercise() only acts while active/paused, so
      // the countdown must genuinely clear (3x1s) each time.
      for (var i = 0; i < 6; i++) {
        controller.skipPrepare();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);

        controller.skipExercise();
        await tester.pump();

        final state = container.read(routinePlayerControllerProvider)!;
        if (i < 5) {
          expect(
            state.phase,
            RoutinePlayerPhase.rest,
            reason:
                'exercise ${i + 1}/6 must go through rest/preview, never straight to the next exercise',
          );
          controller.skipRest();
          await tester.pump();
        } else {
          expect(
            state.phase,
            RoutinePlayerPhase.complete,
            reason:
                'completing Knee Circles (the 6th and final exercise) must go straight to the completion screen, never a rest screen',
          );
        }
      }

      // The completion title interpolates the real source workout's title
      // (`workout?.title ?? 'Routine'` in routine_player_screen.dart) — it
      // only ever showed the generic 'Routine' fallback here because
      // RoutinePlayerState.copyWith previously dropped `sourceWorkout` on
      // every state transition (fixed alongside Pre-Swim's transition
      // work, since Pre-Swim's own restSecondsOverride depends on
      // `sourceWorkout` surviving copyWith too). This is now the real,
      // correct title, not a weakened assertion.
      expect(find.text('🎉 Mobility Reset Complete!'), findsOneWidget);
      final finalState = container.read(routinePlayerControllerProvider)!;
      expect(
        finalState.completedIds.length + finalState.skippedIds.length,
        6,
        reason:
            'exactly one completion/skip record per exercise, never duplicated',
      );

      // Re-issuing skipExercise() post-completion must be a no-op — no
      // duplicate completion event, no crash, no duplicate navigation.
      controller.skipExercise();
      await tester.pump();
      expect(
        container.read(routinePlayerControllerProvider)!.phase,
        RoutinePlayerPhase.complete,
      );

      controller.endSession();
      expect(
        container.read(routinePlayerControllerProvider),
        isNull,
        reason: 'disposal must leave no active session/timers behind',
      );
    },
  );

  testWidgets(
    'pause during Thoracic Rotation freezes the frame and timer together; resume continues from the exact same point, never restarting',
    (tester) async {
      final container = await _bootAtWorkoutHub(tester);
      addTearDown(container.dispose);

      await tester.ensureVisible(find.text('Mobility'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mobility'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mobility Reset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Workout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );
      // Skip straight to Thoracic Rotation (index 4): Shoulder Rolls, Arm
      // Circles, Wrist Circles, Hip Circles.
      for (var i = 0; i < 4; i++) {
        controller.skipPrepare();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 200));
        controller.skipExercise();
        await tester.pump();
        controller.skipRest();
        await tester.pump();
      }
      expect(find.text('Thoracic Rotation'), findsWidgets);

      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        _hasAssetImageContaining(
          tester,
          'exercises/thoracic_rotation/female/v2/',
        ),
        isTrue,
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);

      controller.togglePause();
      await tester.pump();
      expect(
        container.read(routinePlayerControllerProvider)!.phase,
        RoutinePlayerPhase.paused,
      );
      final frozen = container
          .read(routinePlayerControllerProvider)!
          .activeElapsedMs;

      await tester.pump(const Duration(seconds: 2));
      expect(
        container.read(routinePlayerControllerProvider)!.activeElapsedMs,
        frozen,
        reason: 'time passing while paused must not advance the exercise clock',
      );

      controller.togglePause();
      await tester.pump();
      expect(
        container.read(routinePlayerControllerProvider)!.phase,
        RoutinePlayerPhase.active,
      );
      expect(
        container.read(routinePlayerControllerProvider)!.activeElapsedMs,
        frozen,
        reason:
            'resume must continue from the exact frozen point, never restart',
      );

      controller.endSession();
      expect(container.read(routinePlayerControllerProvider), isNull);
    },
  );
}
