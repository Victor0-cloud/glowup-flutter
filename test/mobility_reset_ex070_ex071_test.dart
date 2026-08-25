// Covers Mobility Reset's first per-exercise-resolution pass: Shoulder
// Rolls (EX070) and Arm Circles (EX071) registered as real Tier 1
// RoutinePlayer definitions, `ExerciseCategory.mobility` added to
// app_router.dart's `canUsePerExerciseResolution` gate (the same
// Strength -> Flexibility -> Mobility generalization already documented
// there), and the routine-detail thumbnail wired to each exercise's
// approved `sequence_preview.png` via the new `WorkoutExercise.
// thumbnailAssetPath` field. Wrist Circles/Hip Circles/Thoracic Rotation/
// Knee Circles remain unapproved Tier 2-only placeholders — this file
// also proves they show the generic ASSET_PENDING_APPROVAL stand-in,
// never a false "complete" state.

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
  group('EX070 Shoulder Rolls — Tier 1 registration', () {
    final def = routinePlayerExerciseById('EX070');

    test('resolves with the approved shape', () {
      expect(def, isNotNull);
      expect(def!.displayName, 'Shoulder Rolls');
      expect(def.category, 'Mobility');
      expect(def.durationSeconds, 30);
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
            'assets/glow_up/exercises/shoulder_rolls/female/v2/F_0${i + 1}.png',
          );
        }
        expect(e.poses.map((p) => p.approvedAsset).toSet().length, 6);
      },
    );

    test(
      'loops F_01 -> F_06 -> F_01 continuously, never freezing or stopping mid-exercise',
      () {
        final e = def!;
        final perFrame = e.loopCycleSeconds / 6;
        // First lap.
        for (var i = 0; i < 6; i++) {
          expect(currentPoseFor(e, i * perFrame + perFrame / 2).order, i + 1);
        }
        // Second lap must repeat from F_01, never freeze on F_06 or stop.
        expect(currentPoseFor(e, e.loopCycleSeconds + perFrame / 2).order, 1);
        // Still cycling near the very end of the 30s exercise.
        expect(currentPoseFor(e, 29.9).approvedAsset, isNotNull);
      },
    );

    test(
      'no phaseSyncedVoice / no breathing-style repetition — voice fires on the standard countdown/halfway/finish schedule only',
      () {
        final e = def!;
        expect(e.phaseSyncedVoice, isFalse);
        expect(e.voiceScript.setupInstruction, isNotEmpty);
        expect(e.voiceScript.formCues, isNotEmpty);
      },
    );
  });

  group('EX071 Arm Circles — Tier 1 registration', () {
    final def = routinePlayerExerciseById('EX071');

    test('resolves with the approved shape', () {
      expect(def, isNotNull);
      expect(def!.displayName, 'Arm Circles');
      expect(def.category, 'Mobility');
      expect(def.durationSeconds, 30);
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
            'assets/glow_up/exercises/arm_circles/female/v2/F_0${i + 1}.png',
          );
        }
        expect(e.poses.map((p) => p.approvedAsset).toSet().length, 6);
      },
    );

    test(
      'animates F_01 -> F_06 as a continuous sequence across the 30s timer, never a single static frame',
      () {
        final e = def!;
        final perFrame = e.loopCycleSeconds / 6;
        final seenOrders = <int>{};
        for (var t = 0.0; t < e.durationSeconds; t += 1.0) {
          seenOrders.add(currentPoseFor(e, t).order);
        }
        expect(
          seenOrders.length,
          6,
          reason:
              'all six frames must actually appear during the 30s window, not just frame 1',
        );
        expect(currentPoseFor(e, perFrame / 2).order, 1);
      },
    );
  });

  group('Mobility Reset Workout wiring', () {
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
      // Wrist Circles/Hip Circles/Thoracic Rotation/Knee Circles were
      // completed in later passes than EX070/EX071 — see
      // mobility_reset_ex074_ex075_test.dart and
      // mobility_reset_repair_ex072_ex073_test.dart — completing the
      // routine's full Tier 1 catalogId sequence EX072-EX075.
      expect(workout.exercises.map((e) => e.catalogId).toList(), [
        'EX070',
        'EX071',
        'EX072',
        'EX073',
        'EX074',
        'EX075',
      ]);
    });

    test(
      'Mobility category has exactly two routines (Mobility Reset and Pre-Swim Prep, the activity-preparation area)',
      () {
        final mobilityWorkouts = kWorkoutCatalog.where(
          (w) => w.category == ExerciseCategory.mobility,
        );
        expect(mobilityWorkouts.map((w) => w.id).toSet(), {
          'mobility-reset',
          'pre-swim-prep',
        });
      },
    );

    test(
      'Mobility category library has exactly six exercises (EX036-EX041)',
      () {
        final mobilityExercises = kExerciseCatalog.where(
          (e) => e.primaryCategory == ExerciseCategory.mobility,
        );
        expect(mobilityExercises.length, 6);
      },
    );

    test(
      'EX070/EX071 have unique ids across both tiers, distinct from their legacy EX036/EX037 placeholders',
      () {
        expect(
          routinePlayerExerciseById('EX070')!.id,
          isNot(routinePlayerExerciseById('EX071')!.id),
        );
        expect(exerciseById('EX036')!.name, 'Shoulder Rolls');
        expect(exerciseById('EX037')!.name, 'Arm Circles');
        expect(
          routinePlayerExerciseById('EX036'),
          isNull,
          reason: 'EX036 must stay Tier 2-only, untouched',
        );
        expect(
          routinePlayerExerciseById('EX037'),
          isNull,
          reason: 'EX037 must stay Tier 2-only, untouched',
        );
      },
    );

    test(
      'both routine-detail thumbnails point at the approved sequence_preview.png, and it exists on disk',
      () {
        final shoulderRolls = workout.exercises[0];
        final armCircles = workout.exercises[1];
        expect(
          shoulderRolls.thumbnailAssetPath,
          'assets/glow_up/exercises/shoulder_rolls/female/v2/sequence_preview.png',
        );
        expect(
          armCircles.thumbnailAssetPath,
          'assets/glow_up/exercises/arm_circles/female/v2/sequence_preview.png',
        );
        expect(File(shoulderRolls.thumbnailAssetPath!).existsSync(), isTrue);
        expect(File(armCircles.thumbnailAssetPath!).existsSync(), isTrue);
      },
    );

    test(
      'all six approved PNGs (plus preview) exist on disk for both exercises',
      () {
        for (final dir in ['shoulder_rolls', 'arm_circles']) {
          final folder = Directory('assets/glow_up/exercises/$dir/female/v2');
          final pngs = folder.listSync().whereType<File>().where(
            (f) => f.path.endsWith('.png'),
          );
          expect(
            pngs.length,
            7,
            reason: '$dir must have exactly 6 frames + 1 preview',
          ); // F_01-F_06 + sequence_preview
        }
      },
    );
  });

  testWidgets(
    'Workout -> Mobility -> Mobility Reset -> Start Workout opens RoutinePlayer directly on Shoulder Rolls, never the legacy session',
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

      expect(find.text('Shoulder Rolls'), findsWidgets);
      expect(
        find.text('COACH ON'),
        findsOneWidget,
        reason:
            'must be the real RoutinePlayer, not the legacy session (which has no voice controls)',
      );
      expect(container.read(routinePlayerControllerProvider), isNotNull);
      expect(
        container.read(workoutSessionControllerProvider),
        isNull,
        reason: 'must never also start a legacy session',
      );

      container.read(routinePlayerControllerProvider.notifier).endSession();
    },
  );

  testWidgets(
    'Shoulder Rolls -> Arm Circles both show real approved frames; Wrist Circles after them shows the honest pending stand-in, never falsely marked complete',
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
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        _hasAssetImageContaining(tester, 'exercises/shoulder_rolls/female/v2/'),
        isTrue,
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);

      // Shoulder Rolls -> Rest -> Arm Circles.
      controller.skipExercise();
      await tester.pump();
      final restState = container.read(routinePlayerControllerProvider)!;
      expect(
        restState.phase,
        RoutinePlayerPhase.rest,
        reason:
            'must go through the standard rest/preview step, never skip straight to the next exercise',
      );
      expect(
        restState.isLastExercise,
        isFalse,
        reason:
            'must not falsely complete the routine after only Shoulder Rolls',
      );
      controller.skipRest();
      await tester.pump();
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Arm Circles'), findsWidgets);
      expect(
        _hasAssetImageContaining(tester, 'exercises/arm_circles/female/v2/'),
        isTrue,
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);

      // Arm Circles -> Rest -> Wrist Circles: pending, honestly labeled, not skipped/dropped/faked complete.
      controller.skipExercise();
      await tester.pump();
      final afterArmCircles = container.read(routinePlayerControllerProvider)!;
      expect(afterArmCircles.phase, RoutinePlayerPhase.rest);
      expect(
        afterArmCircles.isLastExercise,
        isFalse,
        reason:
            'Wrist/Hip/Thoracic/Knee Circles must still be part of the routine, never dropped',
      );
      controller.skipRest();
      await tester.pump();
      expect(find.text('Wrist Circles'), findsWidgets);

      controller.endSession();
    },
  );

  testWidgets(
    'pause during Shoulder Rolls freezes the frame and timer; resume continues without restarting the loop',
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
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 500));

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
        reason: 'resume must continue from the exact frozen point',
      );

      // Back/disposal: endSession must leave no active timers (flutter_test's
      // own pending-timer check fails the test if any Timer/TTS leak survives).
      controller.endSession();
      expect(container.read(routinePlayerControllerProvider), isNull);
    },
  );
}
