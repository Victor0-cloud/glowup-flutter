// Covers the first newly-approved Cardio exercise: March In Place
// (EX076), registered as a real Tier 1 RoutinePlayer definition and
// wired into HIIT Cardio Blast at position 2 (immediately after Jumping
// Jacks). `ExerciseCategory.cardio` was added to app_router.dart's
// `canUsePerExerciseResolution` gate (the same Strength -> Flexibility ->
// Mobility -> Cardio generalization already documented there), so both
// Cardio routines now route through RoutinePlayer. High Knees (EX043,
// position 3) was later also approved — see
// full_body_burn_next_four_v2_test.dart for its dedicated coverage.
// Butt Kicks/Step Jacks/Skaters/Shadow Boxing/Side Steps (EX044-EX048,
// positions 4-8) were approved in a later pass still — see
// hiit_cardio_blast_final_five_v2_test.dart. The tests below that predate
// each pass are updated in place rather than left describing a now-stale
// pending state.

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

Future<void> _clearCountdown(
  WidgetTester tester,
  RoutinePlayerController controller,
) async {
  controller.skipPrepare();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(milliseconds: 200));
}

bool _hasAssetImageContaining(WidgetTester tester, String needle) {
  return tester.widgetList<Image>(find.byType(Image)).any((img) {
    final provider = img.image;
    return provider is AssetImage && provider.assetName.contains(needle);
  });
}

void main() {
  group('EX076 March In Place — Tier 1 registration', () {
    final def = routinePlayerExerciseById('EX076');

    test('exists exactly once, with the approved shape', () {
      expect(routinePlayerExerciseById('EX076'), isNotNull);
      expect(def!.displayName, 'March In Place');
      expect(def.category, 'Cardio');
      expect(def.durationSeconds, 40);
      expect(def.loopMode, LoopMode.continuousLoop);
      expect(def.poses.length, 6);
      // Not a duplicate: only one ExerciseDefinition in the whole registry uses this id.
      expect(
        kRoutinePlayerExercisesById.values.where((e) => e.id == 'EX076').length,
        1,
      );
    });

    test(
      'every pose uses its own approved asset, in F_01->F_06 order, never a fallback to another exercise',
      () {
        for (var i = 0; i < 6; i++) {
          expect(def!.poses[i].order, i + 1);
          expect(
            def.poses[i].approvedAsset,
            'assets/glow_up/exercises/march_in_place/female/v2/F_0${i + 1}.png',
          );
          expect(def.poses[i].approvedAsset, isNot(contains('jumping_jack')));
        }
        expect(def!.poses.map((p) => p.approvedAsset).toSet().length, 6);
      },
    );

    test(
      'animated timer sequence: loops continuously through all six frames, never freezing on one static frame',
      () {
        final e = def!;
        final perFrame = e.loopCycleSeconds / 6;
        for (var i = 0; i < 6; i++) {
          expect(currentPoseFor(e, i * perFrame + perFrame / 2).order, i + 1);
        }
        // Wraps cleanly back to F_01 on the next lap — never stops early.
        expect(currentPoseFor(e, e.loopCycleSeconds + perFrame / 2).order, 1);
        expect(currentPoseFor(e, 39.9).approvedAsset, isNotNull);
      },
    );

    test(
      'sequence_preview.png is registered as the dedicated preview, never used as a pose frame',
      () {
        expect(
          def!.previewAssetPath,
          'assets/glow_up/exercises/march_in_place/female/v2/sequence_preview.png',
        );
        expect(File(def.previewAssetPath!).existsSync(), isTrue);
        expect(
          def.poses.every((p) => p.approvedAsset != def.previewAssetPath),
          isTrue,
        );
      },
    );

    test('all six approved PNGs plus the preview exist on disk', () {
      final folder = Directory(
        'assets/glow_up/exercises/march_in_place/female/v2',
      );
      final pngs = folder.listSync().whereType<File>().where(
        (f) => f.path.endsWith('.png'),
      );
      expect(pngs.length, 7);
    });
  });

  group('HIIT Cardio Blast — March In Place wiring', () {
    final workout = kWorkoutCatalog.firstWhere(
      (w) => w.id == 'hiit-cardio-blast',
    );

    test(
      'contains exactly eight exercise positions, March In Place at position 2, Jumping Jacks still at position 1',
      () {
        expect(workout.exercises.length, 8);
        expect(workout.exercises[0].title, 'Jumping Jacks');
        expect(workout.exercises[0].catalogId, 'EX009');
        expect(workout.exercises[1].title, 'March In Place');
        expect(workout.exercises[1].catalogId, 'EX076');
        expect(workout.exercises[1].durationSeconds, 40);
        expect(workout.exercises[1].playbackType, ExercisePlaybackType.timer);
      },
    );

    test(
      'the remaining six positions are unchanged (High Knees/EX043 and Butt Kicks-Side Steps/EX044-EX048 all now approved, same catalog ids/titles/order)',
      () {
        expect(workout.exercises.skip(2).map((e) => e.catalogId).toList(), [
          'EX043',
          'EX044',
          'EX045',
          'EX046',
          'EX047',
          'EX048',
        ]);
        expect(workout.exercises.skip(2).map((e) => e.title).toList(), [
          'High Knees',
          'Butt Kicks',
          'Step Jacks',
          'Skaters',
          'Shadow Boxing',
          'Side Steps',
        ]);
      },
    );

    test(
      'March In Place has a real routine-detail thumbnail (sequence_preview.png), not blank',
      () {
        final marchInPlace = workout.exercises[1];
        expect(
          marchInPlace.thumbnailAssetPath,
          'assets/glow_up/exercises/march_in_place/female/v2/sequence_preview.png',
        );
        expect(File(marchInPlace.thumbnailAssetPath!).existsSync(), isTrue);
      },
    );

    test('Cardio category still shows exactly 8 exercises and 2 routines', () {
      final cardioWorkouts = kWorkoutCatalog.where(
        (w) => w.category == ExerciseCategory.cardio,
      );
      expect(cardioWorkouts.length, 2);
      final cardioExercises = kExerciseCatalog.where(
        (e) => e.primaryCategory == ExerciseCategory.cardio,
      );
      expect(cardioExercises.length, 8);
    });

    test(
      'EX042 (the legacy March In Place placeholder) stays untouched and unreferenced',
      () {
        expect(exerciseById('EX042')!.name, 'March In Place');
        expect(
          workout.exercises.map((e) => e.catalogId),
          isNot(contains('EX042')),
        );
        expect(routinePlayerExerciseById('EX042'), isNull);
      },
    );

    test(
      'Jumping Jacks (EX009) still resolves to its own real Tier 1 definition (asset set later replaced with V2 — see cardio_jumping_jacks_v2_test.dart)',
      () {
        final jj = routinePlayerExerciseById('EX009')!;
        expect(jj.poses.length, 6);
        expect(
          jj.poses.every(
            (p) =>
                p.approvedAsset != null &&
                p.approvedAsset!.contains('jumping_jack'),
          ),
          isTrue,
        );
      },
    );
  });

  testWidgets(
    'Cardio -> HIIT Cardio Blast -> Start Workout opens RoutinePlayer on Jumping Jacks, never the legacy session',
    (tester) async {
      final container = await _bootAtWorkoutHub(tester);
      addTearDown(container.dispose);

      await tester.ensureVisible(find.text('Cardio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cardio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HIIT Cardio Blast'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Start Workout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      expect(find.text('Jumping Jacks'), findsWidgets);
      expect(find.text('COACH ON'), findsOneWidget);
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
    '11-13. After Jumping Jacks, nextExercise.id is EX076; rest screen shows March In Place + its real preview; active screen animates all six frames',
    (tester) async {
      final container = await _bootAtWorkoutHub(tester);
      addTearDown(container.dispose);

      await tester.ensureVisible(find.text('Cardio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cardio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HIIT Cardio Blast'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Workout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );
      await _clearCountdown(tester, controller);
      controller.skipExercise();
      await tester.pump();

      final restState = container.read(routinePlayerControllerProvider)!;
      expect(restState.phase, RoutinePlayerPhase.rest);
      expect(
        restState.currentExercise.id,
        'EX076',
        reason: 'nextExercise after Jumping Jacks must be EX076',
      );
      expect(find.text('UP NEXT'), findsOneWidget);
      expect(find.text('March In Place'), findsWidgets);
      expect(find.textContaining('40s'), findsWidgets);
      final images = tester.widgetList<Image>(find.byType(Image));
      final previewShown = images.any((img) {
        final provider = img.image;
        return provider is AssetImage &&
            provider.assetName ==
                'assets/glow_up/exercises/march_in_place/female/v2/sequence_preview.png';
      });
      expect(
        previewShown,
        isTrue,
        reason: 'Up Next must show the real approved sequence_preview.png',
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);

      controller.skipRest();
      await tester.pump();
      await _clearCountdown(tester, controller);
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);
      expect(
        _hasAssetImageContaining(
          tester,
          'exercises/march_in_place/female/v2/F_',
        ),
        isTrue,
        reason:
            'active screen must animate a real F_0N frame, not a static sequence_preview.png',
      );
      expect(
        _hasAssetImageContaining(tester, 'sequence_preview.png'),
        isFalse,
        reason:
            'active screen must never show the preview as the live animation',
      );

      controller.endSession();
    },
  );

  testWidgets(
    '14-15. Pause/resume freezes and restores March In Place exactly; skip cancels it and safely reaches the now-approved High Knees exercise without crashing',
    (tester) async {
      final container = await _bootAtWorkoutHub(tester);
      addTearDown(container.dispose);

      await tester.ensureVisible(find.text('Cardio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cardio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HIIT Cardio Blast'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Workout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );
      await _clearCountdown(tester, controller); // Jumping Jacks
      controller.skipExercise();
      await tester.pump();
      controller.skipRest();
      await tester.pump();
      await _clearCountdown(tester, controller); // March In Place
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

      // Skip March In Place -> rest -> High Knees (now a real, approved
      // exercise — no crash, no pending placeholder).
      controller.skipExercise();
      await tester.pump();
      expect(
        container.read(routinePlayerControllerProvider)!.phase,
        RoutinePlayerPhase.rest,
      );
      controller.skipRest();
      await tester.pump();
      await _clearCountdown(tester, controller);
      expect(find.text('High Knees'), findsWidgets);
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);
      expect(
        _hasAssetImageContaining(tester, 'exercises/high_knees/female/v2/'),
        isTrue,
        reason: 'High Knees must show its own real approved frame',
      );
      expect(tester.takeException(), isNull);

      controller.endSession();
      expect(
        container.read(routinePlayerControllerProvider),
        isNull,
        reason: 'disposal must leave no active timers/animation/speech behind',
      );
    },
  );
}
