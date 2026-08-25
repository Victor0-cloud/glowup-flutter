// Covers the Lunges + Push-Ups V2 asset replacement (approved package
// GlowUp_Full_Body_Burn_Lunges_PushUps_V2.zip): existing-exercise ASSET
// REPLACEMENTS, not new exercises — canonical ids EX008 (Lunges) and
// EX010 (Push-Ups) preserved, metadata (SIDE_SEQUENCE/45s for Lunges,
// REPS/12/40s for Push-Ups) and both routine positions (Strength
// Foundations positions 1/2 after Squat inserted at 0, Full Body Burn
// positions 3/4 after Jumping Jacks/Squat) unchanged, only the underlying
// imagery and playback mechanism replaced.
//
// Audit summary (performed before any edit): EX008 and EX010 are each
// the one and only canonical record for their exercise, real in both
// tiers, referenced by exactly two routines each (Strength Foundations,
// Full Body Burn) via the same shared `_lungesV2`/`_pushUpsV2`
// WorkoutExercise consts — no duplicate definitions found anywhere in
// the repo. The approved package supplies exactly one 6-frame set per
// exercise (not a left/right pair for Lunges), so Lunges' old bilateral
// `BilateralFrameSequence` (`_lungeLeftFrames`/`_lungeRightFrames`) was
// replaced with a single even `continuousLoop`, the same shape as Squat
// V2 — its 'SIDE_SEQUENCE' playback badge is preserved as metadata only,
// matching the existing Thoracic Rotation (EX074) precedent.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:glow_up/app/glow_up_app.dart';
import 'package:glow_up/onboarding/state/onboarding_controller.dart';
import 'package:glow_up/routine_player/data/routine_player_registry.dart';
import 'package:glow_up/routine_player/models/exercise_definition.dart';
import 'package:glow_up/routine_player/state/routine_player_controller.dart';
import 'package:glow_up/routing/app_router.dart';
import 'package:glow_up/workout/data/exercise_catalog.dart';
import 'package:glow_up/workout/data/workout_catalog.dart';
import 'package:glow_up/workout/models/exercise_models.dart';

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

void _expectSixFramesInOrder(ExerciseDefinition def, String folder) {
  for (var i = 0; i < 6; i++) {
    expect(def.poses[i].order, i + 1);
    expect(def.poses[i].approvedAsset, '$folder/F_0${i + 1}.png');
    expect(File(def.poses[i].approvedAsset!).existsSync(), isTrue);
  }
  expect(def.poses.map((p) => p.approvedAsset).toSet().length, 6);
}

void main() {
  group('Canonical identity and routine wiring preserved', () {
    test(
      'only one canonical Lunges (EX008) and one canonical Push-Ups (EX010) exist',
      () {
        expect(
          kRoutinePlayerExercisesById.values
              .where((e) => e.id == 'EX008')
              .length,
          1,
        );
        expect(
          kRoutinePlayerExercisesById.values
              .where((e) => e.id == 'EX010')
              .length,
          1,
        );
        expect(exerciseById('EX008')!.name, 'Lunges');
        expect(exerciseById('EX010')!.name, 'Push-Ups');
      },
    );

    test(
      'Full Body Burn retains Lunges at position 3 and Push-Ups at position 4',
      () {
        final fbb = kWorkoutCatalog.firstWhere((w) => w.id == 'full-body-burn');
        expect(fbb.exercises.map((e) => e.catalogId).toList(), [
          'EX009',
          'EX007',
          'EX008',
          'EX010',
          'EX018',
          'EX002',
        ]);
        expect(fbb.exercises[2].catalogId, 'EX008');
        expect(fbb.exercises[3].catalogId, 'EX010');
      },
    );

    test(
      'Strength Foundations and Full Body Burn reference the same canonical WorkoutExercise objects',
      () {
        final sf = kWorkoutCatalog.firstWhere(
          (w) => w.id == 'strength-foundations',
        );
        final fbb = kWorkoutCatalog.firstWhere((w) => w.id == 'full-body-burn');
        expect(identical(sf.exercises[1], fbb.exercises[2]), isTrue);
        expect(identical(sf.exercises[2], fbb.exercises[3]), isTrue);
      },
    );

    test(
      'Lunges metadata preserved: SIDE_SEQUENCE badge, 45s; Push-Ups metadata preserved: REPS, 12, 40s',
      () {
        final fbb = kWorkoutCatalog.firstWhere((w) => w.id == 'full-body-burn');
        final lungesEntry = fbb.exercises[2];
        expect(lungesEntry.playbackType, ExercisePlaybackType.sideSequence);
        expect(lungesEntry.durationSeconds, 45);
        final pushUpsEntry = fbb.exercises[3];
        expect(pushUpsEntry.playbackType, ExercisePlaybackType.reps);
        expect(pushUpsEntry.reps, 12);
        expect(pushUpsEntry.durationSeconds, 40);

        final lungesTier1 = routinePlayerExerciseById('EX008')!;
        expect(lungesTier1.playbackType, 'SIDE_SEQUENCE');
        expect(lungesTier1.durationSeconds, 45);
        final pushUpsTier1 = routinePlayerExerciseById('EX010')!;
        expect(pushUpsTier1.playbackType, 'REPS');
        expect(pushUpsTier1.reps, 12);
        expect(pushUpsTier1.durationSeconds, 40);
      },
    );
  });

  group('Asset resolution', () {
    final lunges = routinePlayerExerciseById('EX008');
    final pushUps = routinePlayerExerciseById('EX010');

    test(
      'Lunges resolves to assets/glow_up/exercises/lunges/female/v2/, never the old bilateral left/right set',
      () {
        for (final pose in lunges!.poses) {
          expect(
            pose.approvedAsset,
            startsWith('assets/glow_up/exercises/lunges/female/v2/'),
          );
          expect(
            pose.approvedAsset,
            isNot(contains('exercise_animations/lunges/')),
          );
        }
        expect(
          lunges.bilateralFrames,
          isNull,
          reason:
              'the V2 package supplies one shared 6-frame set, not a left/right pair',
        );
      },
    );

    test(
      'Push-Ups resolves to assets/glow_up/exercises/pushups/female/v2/, never v1 or EX010-legacy',
      () {
        for (final pose in pushUps!.poses) {
          expect(
            pose.approvedAsset,
            startsWith('assets/glow_up/exercises/pushups/female/v2/'),
          );
          expect(
            pose.approvedAsset,
            isNot(contains('exercises/pushups/female/v1/')),
          );
          expect(pose.approvedAsset, isNot(contains('exercises/EX010/')));
        }
      },
    );

    test(
      'both exercises load all six frames, on disk, in the correct F_01->F_06 order',
      () {
        _expectSixFramesInOrder(
          lunges!,
          'assets/glow_up/exercises/lunges/female/v2',
        );
        _expectSixFramesInOrder(
          pushUps!,
          'assets/glow_up/exercises/pushups/female/v2',
        );
      },
    );

    test(
      'sequence_preview.png is registered as the dedicated preview for both, never an active-loop frame',
      () {
        expect(
          lunges!.previewAssetPath,
          'assets/glow_up/exercises/lunges/female/v2/sequence_preview.png',
        );
        expect(File(lunges.previewAssetPath!).existsSync(), isTrue);
        expect(
          pushUps!.previewAssetPath,
          'assets/glow_up/exercises/pushups/female/v2/sequence_preview.png',
        );
        expect(File(pushUps.previewAssetPath!).existsSync(), isTrue);
        for (final pose in [...lunges.poses, ...pushUps.poses]) {
          expect(pose.approvedAsset, isNot(lunges.previewAssetPath));
          expect(pose.approvedAsset, isNot(pushUps.previewAssetPath));
        }
        final sf = kWorkoutCatalog.firstWhere(
          (w) => w.id == 'strength-foundations',
        );
        final fbb = kWorkoutCatalog.firstWhere((w) => w.id == 'full-body-burn');
        expect(sf.exercises[1].thumbnailAssetPath, lunges.previewAssetPath);
        expect(fbb.exercises[2].thumbnailAssetPath, lunges.previewAssetPath);
        expect(sf.exercises[2].thumbnailAssetPath, pushUps.previewAssetPath);
        expect(fbb.exercises[3].thumbnailAssetPath, pushUps.previewAssetPath);
      },
    );

    test(
      'playback loops smoothly for both, no pending-approval or missing-asset placeholder ever appears',
      () {
        for (final def in [lunges!, pushUps!]) {
          expect(def.loopMode, LoopMode.continuousLoop);
          for (var t = 0.0; t < def.durationSeconds; t += 0.1) {
            final pose = currentPoseFor(def, t);
            expect(pose.approvedAsset, isNotNull);
            expect(pose.label, isNot('ASSET_PENDING_APPROVAL'));
          }
          expect(currentPoseFor(def, def.loopCycleSeconds - 0.01).order, 6);
          expect(currentPoseFor(def, def.loopCycleSeconds + 0.01).order, 1);
        }
      },
    );
  });

  testWidgets(
    'Full Body Burn: RoutinePlayer shows Lunges (position 3) then Push-Ups (position 4) with the real V2 frames, never old assets or a pending placeholder',
    (tester) async {
      final container = await _bootAtWorkoutHub(tester);
      addTearDown(container.dispose);

      await tester.ensureVisible(find.text('Cardio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cardio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Full Body Burn'));
      await tester.pumpAndSettle();

      expect(find.text('Lunges'), findsOneWidget);
      expect(find.text('Push-Ups'), findsOneWidget);
      expect(
        _hasAssetImageContaining(tester, 'exercises/lunges/female/v2/'),
        isTrue,
      );
      expect(
        _hasAssetImageContaining(tester, 'exercises/pushups/female/v2/'),
        isTrue,
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);
      expect(find.text('UNVERIFIED EXERCISE ASSET'), findsNothing);

      await tester.tap(find.text('Start Workout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );
      // Skip past Jumping Jacks (1) and Squat (2) to reach Lunges (3).
      for (var i = 0; i < 2; i++) {
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
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Lunges'), findsWidgets);
      expect(
        _hasAssetImageContaining(tester, 'exercises/lunges/female/v2/'),
        isTrue,
      );
      expect(
        _hasAssetImageContaining(tester, 'exercise_animations/lunges/'),
        isFalse,
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);

      // Lunges -> Rest -> Push-Ups Active.
      controller.skipExercise();
      await tester.pump();
      controller.skipRest();
      await tester.pump();
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Pushups'), findsWidgets);
      expect(
        _hasAssetImageContaining(tester, 'exercises/pushups/female/v2/'),
        isTrue,
      );
      expect(
        _hasAssetImageContaining(tester, 'exercises/pushups/female/v1/'),
        isFalse,
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);

      controller.endSession();
    },
  );

  group('Regression: unrelated exercises/routines untouched', () {
    test('Jumping Jacks (EX009) and Squat (EX007) unchanged by this pass', () {
      final jj = routinePlayerExerciseById('EX009')!;
      expect(jj.durationSeconds, 45);
      final squat = routinePlayerExerciseById('EX007')!;
      expect(squat.durationSeconds, 45);
      expect(squat.reps, 15);
    });

    test('Strength Foundations order otherwise unchanged', () {
      final sf = kWorkoutCatalog.firstWhere(
        (w) => w.id == 'strength-foundations',
      );
      expect(sf.exercises.map((e) => e.catalogId).toList(), [
        'EX007',
        'EX008',
        'EX010',
        'EX018',
        'EX020',
        'EX021',
        'EX019',
        'EX022',
      ]);
    });
  });
}
