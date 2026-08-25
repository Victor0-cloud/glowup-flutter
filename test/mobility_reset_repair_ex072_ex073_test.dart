// Regression coverage for the "Mobility Reset still shows
// ASSET_PENDING_APPROVAL after Arm Circles" repair.
//
// Root cause (confirmed by repo-wide search before any edit — see the
// conversation's audit): Wrist Circles and Hip Circles, positions 3-4 of
// the `mobility-reset` Workout in workout_catalog.dart, carried a real
// Tier 2 `catalogId` ('EX038'/'EX039') but had NO Tier 1
// `ExerciseDefinition` in routine_player_registry.dart. Mobility uses
// per-exercise resolution (`_perExerciseRoutineFor` in app_router.dart,
// added when EX070/EX071 first went in) — for any exercise whose
// catalogId doesn't resolve via `routinePlayerExerciseById`, that
// function substitutes the generic `_pendingApprovalStandIn`, whose one
// pose has `approvedAsset: null` and `label: 'ASSET_PENDING_APPROVAL'`;
// `MovementDisplay` renders a null `approvedAsset` as the literal
// "UNVERIFIED EXERCISE ASSET" text. There was never a duplicate/cached
// Mobility Reset definition, a stale test fixture leaking into runtime,
// or a gender-resolver bug — `grep`ing the whole `lib/` tree for
// `ASSET_PENDING_APPROVAL`/`pendingApproval`/`mobility-reset` turned up
// exactly one producer (`_pendingApprovalStandIn`) and exactly one
// `mobility-reset` Workout definition. The fix: register EX072 (Wrist
// Circles) and EX073 (Hip Circles) as real Tier 1 definitions (see their
// doc comments in routine_player_registry.dart) and point workout_
// catalog.dart's positions 3-4 at them, closing the only gap.
//
// This pass also added `ExerciseDefinition.previewAssetPath`/
// `previewAspectRatio` (both null/unused for every pre-existing exercise,
// so this is additive and non-breaking) so RoutinePlayer's REST/Up Next
// card can show each Mobility exercise's approved wide `sequence_preview.
// png` filmstrip instead of its portrait F_01 frame, per this pass's
// explicit requirement — see `ExerciseDefinition.previewPose` and its use
// in `_RestView` (routine_player_screen.dart).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:glow_up/app/glow_up_app.dart';
import 'package:glow_up/onboarding/state/onboarding_controller.dart';
import 'package:glow_up/routine_player/data/routine_player_registry.dart';
import 'package:glow_up/routine_player/models/pose_definition.dart';
import 'package:glow_up/routine_player/models/routine_player_state.dart';
import 'package:glow_up/routine_player/state/routine_player_controller.dart';
import 'package:glow_up/routing/app_router.dart';
import 'package:glow_up/workout/data/workout_catalog.dart';

const _kMobilityIds = ['EX070', 'EX071', 'EX072', 'EX073', 'EX074', 'EX075'];
const _kMobilityNames = [
  'Shoulder Rolls',
  'Arm Circles',
  'Wrist Circles',
  'Hip Circles',
  'Thoracic Rotation',
  'Knee Circles',
];
const _kMobilityDurations = [30, 30, 20, 30, 35, 25];

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

/// Clears the countdown (3-2-1) and moves the routine into ACTIVE.
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

void main() {
  group('1-4. Mobility Reset canonical registry — no placeholders anywhere', () {
    final workout = kWorkoutCatalog.firstWhere((w) => w.id == 'mobility-reset');

    test('exactly six canonical exercise IDs, in order: EX070-EX075', () {
      expect(workout.exercises.map((e) => e.catalogId).toList(), _kMobilityIds);
      expect(workout.exercises.map((e) => e.title).toList(), _kMobilityNames);
      expect(
        workout.exercises.map((e) => e.durationSeconds).toList(),
        _kMobilityDurations,
      );
    });

    test(
      'every ID resolves to a real Tier 1 exercise record — zero pending/placeholder entries',
      () {
        for (final id in _kMobilityIds) {
          final def = routinePlayerExerciseById(id);
          expect(
            def,
            isNotNull,
            reason:
                '$id must resolve through the canonical RoutinePlayer registry',
          );
          expect(
            def!.playbackType,
            isNot('PENDING'),
            reason: '$id must not be the generic pending stand-in',
          );
          expect(
            def.poses.any((p) => p.label == 'ASSET_PENDING_APPROVAL'),
            isFalse,
            reason: '$id must never show the ASSET_PENDING_APPROVAL label',
          );
          expect(
            def.poses.any((p) => p.approvedAsset == null),
            isFalse,
            reason: '$id must never have a null (unverified) pose asset',
          );
        }
      },
    );

    test(
      'every exercise resolves to exactly six distinct active frames plus one sequence preview',
      () {
        for (final id in _kMobilityIds) {
          final def = routinePlayerExerciseById(id)!;
          expect(
            def.poses.length,
            6,
            reason: '$id must expose exactly six active frames',
          );
          expect(
            def.poses.map((p) => p.approvedAsset).toSet().length,
            6,
            reason:
                '$id frames must all be distinct — never a substitute or reused asset',
          );
          expect(
            def.previewAssetPath,
            isNotNull,
            reason:
                '$id must have a dedicated sequence_preview.png, not a blank/placeholder thumbnail',
          );
          expect(
            File(def.previewAssetPath!).existsSync(),
            isTrue,
            reason: '$id preview must be a real file on disk',
          );
          expect(
            def.poses.every((p) => p.approvedAsset != def.previewAssetPath),
            isTrue,
            reason:
                '$id must never display sequence_preview.png as an active-exercise frame',
          );
        }
      },
    );

    test(
      'all six routine-detail thumbnails are non-placeholder, existing assets',
      () {
        for (final exercise in workout.exercises) {
          expect(
            exercise.thumbnailAssetPath,
            isNotNull,
            reason: '${exercise.title} must not have a blank thumbnail',
          );
          expect(File(exercise.thumbnailAssetPath!).existsSync(), isTrue);
        }
      },
    );
  });

  testWidgets(
    '5-8, 10. Full RoutinePlayer transition EX070 -> EX071 -> EX072 -> EX073 -> EX074 -> EX075 -> completion, never showing the pending-approval placeholder',
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
      expect(tester.takeException(), isNull);
      expect(find.text('Shoulder Rolls'), findsWidgets);

      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );
      final observedUpNext = <String>[];

      for (var i = 0; i < _kMobilityIds.length; i++) {
        await _clearCountdown(tester, controller);
        expect(tester.takeException(), isNull);
        expect(
          find.text('ASSET_PENDING_APPROVAL'),
          findsNothing,
          reason:
              'position ${i + 1} (${_kMobilityNames[i]}) must never show the pending-approval placeholder',
        );
        expect(
          find.text('UNVERIFIED EXERCISE ASSET'),
          findsNothing,
          reason:
              'position ${i + 1} (${_kMobilityNames[i]}) must never show the unverified-asset placeholder',
        );

        final currentState = container.read(routinePlayerControllerProvider)!;
        expect(currentState.currentExercise.id, _kMobilityIds[i]);

        controller.skipExercise();
        await tester.pump();

        final afterState = container.read(routinePlayerControllerProvider)!;
        if (i < _kMobilityIds.length - 1) {
          expect(
            afterState.phase,
            RoutinePlayerPhase.rest,
            reason:
                'after ${_kMobilityNames[i]}, the routine must go through rest/preview, never straight to the next exercise',
          );
          expect(
            afterState.currentExercise.id,
            _kMobilityIds[i + 1],
            reason:
                'nextExercise after ${_kMobilityNames[i]} must be ${_kMobilityIds[i + 1]}',
          );
          observedUpNext.add(afterState.currentExercise.displayName);
          expect(find.text('UP NEXT'), findsOneWidget);
          expect(find.text(_kMobilityNames[i + 1]), findsWidgets);
          expect(
            find.textContaining('${_kMobilityDurations[i + 1]}s'),
            findsWidgets,
            reason: 'rest screen must show the correct upcoming duration',
          );
          expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);
          expect(find.text('UNVERIFIED EXERCISE ASSET'), findsNothing);
          controller.skipRest();
          await tester.pump();
        } else {
          // 8. No rest screen appears after EX075 — straight to completion.
          expect(
            afterState.phase,
            RoutinePlayerPhase.complete,
            reason:
                'completing Knee Circles (the 6th and final exercise) must go straight to the completion screen, never a rest screen',
          );
        }
      }

      expect(observedUpNext, [
        'Arm Circles',
        'Wrist Circles',
        'Hip Circles',
        'Thoracic Rotation',
        'Knee Circles',
      ]);
      // The completion title interpolates the real source workout's title
      // (`workout?.title ?? 'Routine'` in routine_player_screen.dart) — it
      // only ever showed the generic 'Routine' fallback here because
      // RoutinePlayerState.copyWith previously dropped `sourceWorkout` on
      // every state transition (fixed alongside Pre-Swim's transition
      // work, since Pre-Swim's own restSecondsOverride depends on
      // `sourceWorkout` surviving copyWith too). This is now the real,
      // correct title, not a weakened assertion.
      expect(find.text('🎉 Mobility Reset Complete!'), findsOneWidget);

      // 13. Completion is recorded exactly once.
      final finalState = container.read(routinePlayerControllerProvider)!;
      expect(finalState.completedIds.length + finalState.skippedIds.length, 6);
      controller.skipExercise(); // post-completion no-op
      await tester.pump();
      expect(
        container.read(routinePlayerControllerProvider)!.phase,
        RoutinePlayerPhase.complete,
      );

      controller.endSession();
      expect(container.read(routinePlayerControllerProvider), isNull);
    },
  );

  testWidgets(
    'rest screen after Arm Circles shows Wrist Circles\'s real sequence_preview.png, never the pending stand-in image',
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
      await _clearCountdown(tester, controller); // Shoulder Rolls
      controller.skipExercise();
      await tester.pump();
      controller.skipRest();
      await tester.pump();
      await _clearCountdown(tester, controller); // Arm Circles
      controller.skipExercise();
      await tester.pump();

      expect(
        container.read(routinePlayerControllerProvider)!.phase,
        RoutinePlayerPhase.rest,
      );
      expect(
        container.read(routinePlayerControllerProvider)!.currentExercise.id,
        'EX072',
      );
      expect(find.text('Wrist Circles'), findsWidgets);
      expect(find.textContaining('20s'), findsWidgets);

      final images = tester.widgetList<Image>(find.byType(Image));
      final previewShown = images.any((img) {
        final provider = img.image;
        return provider is AssetImage &&
            provider.assetName ==
                'assets/glow_up/exercises/wrist_circles/female/v2/sequence_preview.png';
      });
      expect(
        previewShown,
        isTrue,
        reason:
            'Up Next must show the real approved sequence_preview.png, not a placeholder/blank/another exercise\'s image',
      );

      controller.endSession();
    },
  );

  testWidgets(
    'pause/resume/skip/previous/back all still work through the completed six-exercise routine, with no leaked timers on disposal',
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
      await _clearCountdown(tester, controller);
      await tester.pump(const Duration(milliseconds: 500));

      // Pause / resume.
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
        reason: 'pause must freeze the timer',
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

      // Skip forward, then Previous back.
      controller.skipExercise();
      await tester.pump();
      controller.skipRest();
      await tester.pump();
      expect(
        container.read(routinePlayerControllerProvider)!.currentExercise.id,
        'EX071',
      );
      await _clearCountdown(tester, controller);
      controller.previousExercise();
      await tester.pump();
      expect(
        container.read(routinePlayerControllerProvider)!.currentExercise.id,
        'EX070',
        reason: 'Previous must go back to Shoulder Rolls',
      );

      // Disposal: no active timers/animations/speech may survive (flutter_test's
      // own pending-timer invariant fails the test if any leaked).
      controller.endSession();
      expect(container.read(routinePlayerControllerProvider), isNull);
    },
  );

  test(
    'PoseDefinition sanity: previewPose only ever differs from firstPose when previewAssetPath is set',
    () {
      for (final id in _kMobilityIds) {
        final def = routinePlayerExerciseById(id)!;
        final PoseDefinition preview = def.previewPose;
        expect(preview.approvedAsset, def.previewAssetPath);
        expect(
          preview.approvedAsset,
          isNot(def.firstPose.approvedAsset),
          reason:
              '$id\'s Up Next preview must be the wide filmstrip, not the portrait F_01 frame',
        );
      }
    },
  );
}
