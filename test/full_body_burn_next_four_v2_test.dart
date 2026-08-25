// Covers the four approved female V2 exercise asset sequences (approved
// package GlowUp_Cardio_Next_Four_V2.zip): Glute Bridge, Full Body
// Stretch (Cardio version), March In Place, and High Knees. All four
// preserve their existing canonical exercise IDs — no new EX numbers were
// minted (unlike EX076 March In Place's original registration in an
// earlier pass, which is untouched here beyond a real asset refresh):
//
// - Glute Bridge: EX018, unchanged Strength category, REPS/15/40s,
//   Full Body Burn position 5. Its Tier1 definition already existed but
//   pointed at filenames that never existed on disk
//   (`glute_bridge_female_0N_*.png`) — replaced with the real, verified
//   `F_0N.png` set at the same already-declared `glute_bridge/female/v1/`
//   path.
// - Full Body Stretch (Cardio): EX002, Full Body Burn position 6. EX002
//   previously had only an image-less "(Unverified)" Tier1 stub, orphaned
//   from any production workout even though Full Body Burn's routine
//   entry already referenced it by catalogId — now upgraded in place to
//   a real, approved exercise at `full_body_stretch/female/v1/`.
//   Distinct from Bedtime Meditation's own "Full Body Stretch" (EX061,
//   `full_body_stretch/female/v2/`) — EX061 itself is explicitly untouched
//   by this task either way, per its own explicit scope restriction; its
//   real assets were separately delivered by their own dedicated,
//   unrelated audit. EX002's Tier1 displayName is
//   disambiguated to "Full Body Stretch (Cardio)" solely to satisfy the
//   "Tier 1 display names are unique" invariant against EX061's identical
//   name; the routine-detail list row still shows the clean, unqualified
//   "Full Body Stretch" title (from the raw WorkoutExercise entry's own
//   `.title`, independent of the Tier1 displayName).
// - March In Place: EX076, unchanged Cardio category, TIMER/40s, HIIT
//   Cardio Blast position 2. Its previous V2 asset set (~304x864,
//   registered in an earlier pass) is replaced with a new approved
//   326x804 V2 set from this package, at the same `march_in_place/
//   female/v2/` path.
// - High Knees: EX043, unchanged Cardio category, TIMER/35s, HIIT Cardio
//   Blast position 3. Previously had no Tier1 definition at all (resolved
//   to the honest ASSET_PENDING_APPROVAL stand-in) — now a real, approved
//   exercise at `high_knees/female/v2/`, reusing its existing Tier2
//   catalog id rather than minting a new one.

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

void _expectSixFramesInOrder(ExerciseDefinition def, String folder) {
  for (var i = 0; i < 6; i++) {
    expect(def.poses[i].order, i + 1);
    expect(def.poses[i].approvedAsset, '$folder/F_0${i + 1}.png');
    expect(File(def.poses[i].approvedAsset!).existsSync(), isTrue);
  }
  expect(def.poses.map((p) => p.approvedAsset).toSet().length, 6);
}

void main() {
  group('Canonical identity and metadata preserved', () {
    test(
      'no new EX numbers were minted — all four reuse their existing canonical ids',
      () {
        expect(
          kRoutinePlayerExercisesById.values
              .where((e) => e.id == 'EX018')
              .length,
          1,
        );
        expect(
          kRoutinePlayerExercisesById.values
              .where((e) => e.id == 'EX002')
              .length,
          1,
        );
        expect(
          kRoutinePlayerExercisesById.values
              .where((e) => e.id == 'EX076')
              .length,
          1,
        );
        expect(
          kRoutinePlayerExercisesById.values
              .where((e) => e.id == 'EX043')
              .length,
          1,
        );
        expect(exerciseById('EX018')!.name, 'Glute Bridge');
        expect(exerciseById('EX002')!.name, 'Full Body Stretch');
        expect(exerciseById('EX043')!.name, 'High Knees');
      },
    );

    test(
      'Glute Bridge: REPS, 15 reps, 40 seconds, Strength category, Full Body Burn position 5',
      () {
        final def = routinePlayerExerciseById('EX018')!;
        expect(def.playbackType, 'REPS');
        expect(def.reps, 15);
        expect(def.durationSeconds, 40);
        expect(def.category, 'Strength');
        final fbb = kWorkoutCatalog.firstWhere((w) => w.id == 'full-body-burn');
        expect(fbb.exercises[4].catalogId, 'EX018');
        expect(fbb.exercises[4].title, 'Glute Bridge');
      },
    );

    test(
      'Full Body Stretch (Cardio): SEQUENCE_LOOP, 45 seconds, Full Body Burn position 6',
      () {
        final def = routinePlayerExerciseById('EX002')!;
        expect(def.playbackType, 'SEQUENCE_LOOP');
        expect(def.durationSeconds, 45);
        final fbb = kWorkoutCatalog.firstWhere((w) => w.id == 'full-body-burn');
        expect(fbb.exercises[5].catalogId, 'EX002');
        expect(
          fbb.exercises[5].title,
          'Full Body Stretch',
          reason: 'the routine-detail list title stays clean/unqualified',
        );
      },
    );

    test('March In Place: TIMER, 40 seconds, HIIT Cardio Blast position 2', () {
      final def = routinePlayerExerciseById('EX076')!;
      expect(def.playbackType, 'TIMER');
      expect(def.durationSeconds, 40);
      final hiit = kWorkoutCatalog.firstWhere(
        (w) => w.id == 'hiit-cardio-blast',
      );
      expect(hiit.exercises[1].catalogId, 'EX076');
      expect(hiit.exercises[1].title, 'March In Place');
    });

    test('High Knees: TIMER, 35 seconds, HIIT Cardio Blast position 3', () {
      final def = routinePlayerExerciseById('EX043')!;
      expect(def.playbackType, 'TIMER');
      expect(def.durationSeconds, 35);
      final hiit = kWorkoutCatalog.firstWhere(
        (w) => w.id == 'hiit-cardio-blast',
      );
      expect(hiit.exercises[2].catalogId, 'EX043');
      expect(hiit.exercises[2].title, 'High Knees');
    });

    test(
      'Full Body Burn order fully preserved: Jumping Jacks, Squat, Lunges, Push-Ups, Glute Bridge, Full Body Stretch',
      () {
        final fbb = kWorkoutCatalog.firstWhere((w) => w.id == 'full-body-burn');
        expect(fbb.exercises.map((e) => e.title).toList(), [
          'Jumping Jacks',
          'Squat',
          'Lunges',
          'Push-Ups',
          'Glute Bridge',
          'Full Body Stretch',
        ]);
      },
    );

    test(
      'HIIT Cardio Blast beginning fully preserved: Jumping Jacks, March In Place, High Knees',
      () {
        final hiit = kWorkoutCatalog.firstWhere(
          (w) => w.id == 'hiit-cardio-blast',
        );
        expect(hiit.exercises.take(3).map((e) => e.title).toList(), [
          'Jumping Jacks',
          'March In Place',
          'High Knees',
        ]);
      },
    );
  });

  group('Asset resolution', () {
    test(
      'Glute Bridge resolves to glute_bridge/female/v1/, all six frames in order',
      () {
        final def = routinePlayerExerciseById('EX018')!;
        for (final pose in def.poses) {
          expect(
            pose.approvedAsset,
            startsWith('assets/glow_up/exercises/glute_bridge/female/v1/'),
          );
        }
        _expectSixFramesInOrder(
          def,
          'assets/glow_up/exercises/glute_bridge/female/v1',
        );
      },
    );

    test(
      'Full Body Stretch (Cardio) resolves to full_body_stretch/female/v1/ — explicitly v1, never auto-selecting v2',
      () {
        final def = routinePlayerExerciseById('EX002')!;
        for (final pose in def.poses) {
          expect(
            pose.approvedAsset,
            startsWith('assets/glow_up/exercises/full_body_stretch/female/v1/'),
          );
          expect(pose.approvedAsset, isNot(contains('/v2/')));
        }
        _expectSixFramesInOrder(
          def,
          'assets/glow_up/exercises/full_body_stretch/female/v1',
        );
      },
    );

    test(
      'March In Place resolves to march_in_place/female/v2/, all six frames in order',
      () {
        final def = routinePlayerExerciseById('EX076')!;
        for (final pose in def.poses) {
          expect(
            pose.approvedAsset,
            startsWith('assets/glow_up/exercises/march_in_place/female/v2/'),
          );
        }
        _expectSixFramesInOrder(
          def,
          'assets/glow_up/exercises/march_in_place/female/v2',
        );
      },
    );

    test(
      'High Knees resolves to high_knees/female/v2/, all six frames in order',
      () {
        final def = routinePlayerExerciseById('EX043')!;
        for (final pose in def.poses) {
          expect(
            pose.approvedAsset,
            startsWith('assets/glow_up/exercises/high_knees/female/v2/'),
          );
        }
        _expectSixFramesInOrder(
          def,
          'assets/glow_up/exercises/high_knees/female/v2',
        );
      },
    );

    test(
      'sequence_preview.png is registered as the dedicated preview for all four, never an active-loop frame',
      () {
        for (final id in ['EX018', 'EX002', 'EX076', 'EX043']) {
          final def = routinePlayerExerciseById(id)!;
          expect(
            def.previewAssetPath,
            isNotNull,
            reason: '$id has no previewAssetPath',
          );
          expect(File(def.previewAssetPath!).existsSync(), isTrue);
          for (final pose in def.poses) {
            expect(pose.approvedAsset, isNot(def.previewAssetPath));
          }
        }
      },
    );

    test(
      'playback loops smoothly for all four, no pending-approval or missing-asset placeholder ever appears',
      () {
        for (final id in ['EX018', 'EX002', 'EX076', 'EX043']) {
          final def = routinePlayerExerciseById(id)!;
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

  group('Bedtime Full Body Stretch (EX061) left unchanged', () {
    test(
      'EX061 is not silently mapped to the Cardio v1 assets — its own v2 assets are separately real and unaffected by this task either way',
      () {
        final bedtimeStretch = routinePlayerExerciseById('EX061')!;
        expect(bedtimeStretch.displayName, 'Full Body Stretch');
        expect(bedtimeStretch.category, 'Bedtime');
        for (final pose in bedtimeStretch.poses) {
          expect(
            pose.approvedAsset,
            isNot(contains('full_body_stretch/female/v1/')),
            reason: 'Bedtime must never be pointed at the Cardio v1 assets',
          );
          expect(pose.approvedAsset, contains('full_body_stretch/female/v2/'));
        }
        // Not a claim this task fixed or fabricated anything for EX061 —
        // its own real v2 assets were separately delivered (by their own
        // dedicated, unrelated audit) at the exact filenames the registry
        // already referenced. This test only confirms the two Full Body
        // Stretch exercises still never share or cross-resolve an asset.
      },
    );

    test(
      'Bedtime Meditation never references EX002, and EX002 never carries the Bedtime EX061 displayName',
      () {
        final bedtime = kWorkoutCatalog.firstWhere(
          (w) => w.id == 'bedtime-meditation',
        );
        expect(
          bedtime.exercises.map((e) => e.catalogId),
          isNot(contains('EX002')),
        );
        final cardioStretch = routinePlayerExerciseById('EX002')!;
        expect(cardioStretch.displayName, isNot('Full Body Stretch'));
      },
    );
  });

  testWidgets(
    'Full Body Burn: RoutinePlayer shows Glute Bridge (position 5) then Full Body Stretch (position 6) with real V2 frames, never a pending placeholder',
    (tester) async {
      final container = await _bootAtWorkoutHub(tester);
      addTearDown(container.dispose);

      await tester.ensureVisible(find.text('Cardio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cardio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Full Body Burn'));
      await tester.pumpAndSettle();

      expect(find.text('Glute Bridge'), findsOneWidget);
      expect(find.text('Full Body Stretch'), findsOneWidget);
      expect(
        _hasAssetImageContaining(tester, 'exercises/glute_bridge/female/v1/'),
        isTrue,
      );
      expect(
        _hasAssetImageContaining(
          tester,
          'exercises/full_body_stretch/female/v1/',
        ),
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
      // Skip past Jumping Jacks/Squat/Lunges/Push-Ups (1-4) to reach Glute Bridge (5).
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
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Glute Bridge'), findsWidgets);
      expect(
        _hasAssetImageContaining(tester, 'exercises/glute_bridge/female/v1/'),
        isTrue,
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);

      // Glute Bridge -> Rest -> Full Body Stretch Active.
      controller.skipExercise();
      await tester.pump();
      controller.skipRest();
      await tester.pump();
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));

      // The live RoutinePlayer header shows the Tier1 displayName, which is
      // disambiguated to "Full Body Stretch (Cardio)" against EX061's
      // identical plain name — a substring match still confirms the right
      // exercise is active.
      expect(find.textContaining('Full Body Stretch'), findsWidgets);
      expect(
        _hasAssetImageContaining(
          tester,
          'exercises/full_body_stretch/female/v1/',
        ),
        isTrue,
      );
      expect(
        _hasAssetImageContaining(
          tester,
          'exercises/full_body_stretch/female/v2/',
        ),
        isFalse,
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);

      controller.endSession();
    },
  );

  testWidgets(
    'HIIT Cardio Blast: RoutinePlayer shows March In Place (position 2) then High Knees (position 3) with real V2 frames, never a pending placeholder',
    (tester) async {
      final container = await _bootAtWorkoutHub(tester);
      addTearDown(container.dispose);

      await tester.ensureVisible(find.text('Cardio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cardio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HIIT Cardio Blast'));
      await tester.pumpAndSettle();

      expect(find.text('March In Place'), findsOneWidget);
      expect(find.text('High Knees'), findsOneWidget);
      expect(
        _hasAssetImageContaining(tester, 'exercises/march_in_place/female/v2/'),
        isTrue,
      );
      expect(
        _hasAssetImageContaining(tester, 'exercises/high_knees/female/v2/'),
        isTrue,
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);

      await tester.tap(find.text('Start Workout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );
      // Skip Jumping Jacks (1) -> March In Place (2).
      await _clearCountdown(tester, controller);
      controller.skipExercise();
      await tester.pump();
      controller.skipRest();
      await tester.pump();
      await _clearCountdown(tester, controller);

      expect(find.text('March In Place'), findsWidgets);
      expect(
        _hasAssetImageContaining(tester, 'exercises/march_in_place/female/v2/'),
        isTrue,
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);

      // March In Place -> Rest -> High Knees Active.
      controller.skipExercise();
      await tester.pump();
      controller.skipRest();
      await tester.pump();
      await _clearCountdown(tester, controller);

      expect(find.text('High Knees'), findsWidgets);
      expect(
        _hasAssetImageContaining(tester, 'exercises/high_knees/female/v2/'),
        isTrue,
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);

      controller.endSession();
    },
  );

  group('Regression: unrelated exercises/routines untouched', () {
    test('Jumping Jacks, Squat, Lunges, Push-Ups unchanged by this pass', () {
      expect(routinePlayerExerciseById('EX009')!.durationSeconds, 45);
      expect(routinePlayerExerciseById('EX007')!.durationSeconds, 45);
      expect(routinePlayerExerciseById('EX008')!.durationSeconds, 45);
      expect(routinePlayerExerciseById('EX010')!.durationSeconds, 40);
    });
  });
}
