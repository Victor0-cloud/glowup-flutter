// Covers the Squat V2 asset replacement (approved package
// GlowUp_Full_Body_Burn_Squat_V2_Replacement.zip): an existing-exercise
// ASSET REPLACEMENT, not a new exercise — canonical id EX007 preserved,
// REPS/15/45s/Strength-category metadata and both routine positions
// (Strength Foundations position 1, Full Body Burn position 2, right
// after Jumping Jacks) unchanged, only the underlying imagery and
// playback mechanism replaced (old weighted "real-room" V1 photos ->
// new even-cadence approved V2 filmstrip).
//
// Audit summary (performed before any edit): EX007 is the one and only
// canonical Squat record, real in both tiers (Tier 2 legacy catalog
// `exercise_catalog.dart` and Tier 1 RoutinePlayer registry
// `routine_player_registry.dart`), referenced by exactly two routines
// (Strength Foundations position 1, Full Body Burn position 2) via the
// same shared `_squatV2` WorkoutExercise const — no duplicate
// definitions found anywhere in the repo.

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

void main() {
  group('Canonical identity and routine wiring preserved', () {
    test(
      'only one canonical Squat exercise exists, under the original id EX007',
      () {
        expect(
          kRoutinePlayerExercisesById.values
              .where((e) => e.id == 'EX007')
              .length,
          1,
        );
        expect(routinePlayerExerciseById('EX007'), isNotNull);
        expect(exerciseById('EX007')!.name, 'Squat');
      },
    );

    test(
      'Full Body Burn still contains Squat in position 2, immediately after Jumping Jacks',
      () {
        final fbb = kWorkoutCatalog.firstWhere((w) => w.id == 'full-body-burn');
        expect(fbb.exercises[0].catalogId, 'EX009');
        expect(fbb.exercises[1].catalogId, 'EX007');
        expect(fbb.exercises.map((e) => e.catalogId).toList(), [
          'EX009',
          'EX007',
          'EX008',
          'EX010',
          'EX018',
          'EX002',
        ]);
      },
    );

    test(
      'Strength Foundations position 1 and Full Body Burn position 2 both reference the same canonical WorkoutExercise object',
      () {
        final sf = kWorkoutCatalog.firstWhere(
          (w) => w.id == 'strength-foundations',
        );
        final fbb = kWorkoutCatalog.firstWhere((w) => w.id == 'full-body-burn');
        expect(sf.exercises[0].catalogId, 'EX007');
        expect(identical(sf.exercises[0], fbb.exercises[1]), isTrue);
      },
    );

    test(
      'REPS mode, 15 reps, 45 seconds, Strength category — all preserved',
      () {
        final fbb = kWorkoutCatalog.firstWhere((w) => w.id == 'full-body-burn');
        final squatEntry = fbb.exercises[1];
        expect(squatEntry.playbackType, ExercisePlaybackType.reps);
        expect(squatEntry.reps, 15);
        expect(squatEntry.durationSeconds, 45);
        final tier1 = routinePlayerExerciseById('EX007')!;
        expect(tier1.playbackType, 'REPS');
        expect(tier1.reps, 15);
        expect(tier1.durationSeconds, 45);
        expect(tier1.category, 'Strength');
      },
    );
  });

  group('Asset resolution', () {
    final def = routinePlayerExerciseById('EX007');

    test(
      'Squat resolves to assets/glow_up/exercises/squat/female/v2/, never v1, EX007-legacy, or another exercise',
      () {
        for (final pose in def!.poses) {
          expect(
            pose.approvedAsset,
            startsWith('assets/glow_up/exercises/squat/female/v2/'),
          );
          expect(
            pose.approvedAsset,
            isNot(contains('exercises/squat/female/v1/')),
          );
          expect(pose.approvedAsset, isNot(contains('exercises/EX007/')));
        }
      },
    );

    test('all six frames exist on disk in the correct F_01->F_06 order', () {
      for (var i = 0; i < 6; i++) {
        expect(def!.poses[i].order, i + 1);
        expect(
          def.poses[i].approvedAsset,
          'assets/glow_up/exercises/squat/female/v2/F_0${i + 1}.png',
        );
        expect(File(def.poses[i].approvedAsset!).existsSync(), isTrue);
      }
      expect(def!.poses.map((p) => p.approvedAsset).toSet().length, 6);
    });

    test(
      'sequence_preview.png is registered as the dedicated preview only, never an active-loop frame',
      () {
        expect(
          def!.previewAssetPath,
          'assets/glow_up/exercises/squat/female/v2/sequence_preview.png',
        );
        expect(File(def.previewAssetPath!).existsSync(), isTrue);
        for (final pose in def.poses) {
          expect(pose.approvedAsset, isNot(def.previewAssetPath));
        }
        final sf = kWorkoutCatalog.firstWhere(
          (w) => w.id == 'strength-foundations',
        );
        final fbb = kWorkoutCatalog.firstWhere((w) => w.id == 'full-body-burn');
        expect(sf.exercises[0].thumbnailAssetPath, def.previewAssetPath);
        expect(fbb.exercises[1].thumbnailAssetPath, def.previewAssetPath);
      },
    );

    test(
      'playback loops smoothly F_01->F_06->F_01, no pending-approval or missing-asset placeholder ever appears',
      () {
        expect(def!.loopMode, LoopMode.continuousLoop);
        for (var t = 0.0; t < def.durationSeconds; t += 0.1) {
          final pose = currentPoseFor(def, t);
          expect(pose.approvedAsset, isNotNull);
          expect(pose.label, isNot('ASSET_PENDING_APPROVAL'));
        }
        expect(currentPoseFor(def, def.loopCycleSeconds - 0.01).order, 6);
        expect(currentPoseFor(def, def.loopCycleSeconds + 0.01).order, 1);
      },
    );
  });

  testWidgets(
    'Full Body Burn detail and RoutinePlayer both show the V2 preview/frames for Squat, never the old real-room image or a pending placeholder',
    (tester) async {
      final container = await _bootAtWorkoutHub(tester);
      addTearDown(container.dispose);

      await tester.ensureVisible(find.text('Cardio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cardio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Full Body Burn'));
      await tester.pumpAndSettle();

      expect(find.text('Squat'), findsOneWidget);
      expect(
        _hasAssetImageContaining(tester, 'exercises/squat/female/v2/'),
        isTrue,
      );
      expect(
        _hasAssetImageContaining(tester, 'exercises/squat/female/v1/'),
        isFalse,
      );
      expect(_hasAssetImageContaining(tester, 'exercises/EX007/'), isFalse);
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
      // Skip past Jumping Jacks (position 1) into Squat (position 2).
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));
      controller.skipExercise();
      await tester.pump();
      controller.skipRest();
      await tester.pump();
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Squat'), findsWidgets);
      expect(
        _hasAssetImageContaining(tester, 'exercises/squat/female/v2/'),
        isTrue,
      );
      expect(
        _hasAssetImageContaining(tester, 'exercises/squat/female/v1/'),
        isFalse,
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);

      controller.endSession();
    },
  );

  group('Regression: unrelated exercises/routines untouched', () {
    test('Jumping Jacks (EX009) unchanged by this pass', () {
      final jj = routinePlayerExerciseById('EX009')!;
      expect(jj.durationSeconds, 45);
      expect(jj.poses.first.approvedAsset, contains('jumping_jack/female/v2/'));
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
