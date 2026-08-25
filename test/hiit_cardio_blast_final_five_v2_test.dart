// Covers the final five approved HIIT Cardio Blast exercises: Butt Kicks
// (EX044), Step Jacks (EX045), Skaters (EX046), Shadow Boxing (EX047),
// and Side Steps (EX048) — positions 4-8, completing the routine after
// Jumping Jacks/March In Place/High Knees. All five reuse their existing
// canonical Tier 2 catalog ids — no new EX numbers were minted — and were
// previously registered nowhere in Tier 1 (they resolved to the honest
// ASSET_PENDING_APPROVAL stand-in via `_perExerciseRoutineFor`). Assets
// live under `assets/glow_up/exercises/<slug>/female/v2/`, the same
// lavender-uniform Glow Up Cardio visual system (326x804 real frames,
// 1956x804 sequence_preview.png) as every other exercise approved this
// session. Only a female pose set was supplied for any of the five — no
// male folder exists anywhere in this project for any exercise, so this
// matches the established convention rather than being an omission.

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

const _ids = ['EX044', 'EX045', 'EX046', 'EX047', 'EX048'];
const _slugs = {
  'EX044': 'butt_kicks',
  'EX045': 'step_jacks',
  'EX046': 'skaters',
  'EX047': 'shadow_boxing',
  'EX048': 'side_steps',
};
const _names = {
  'EX044': 'Butt Kicks',
  'EX045': 'Step Jacks',
  'EX046': 'Skaters',
  'EX047': 'Shadow Boxing',
  'EX048': 'Side Steps',
};

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
  group('Canonical identity and no duplicates', () {
    test(
      'all five reuse their existing EX044-EX048 ids — no new EX numbers, no duplicates',
      () {
        for (final id in _ids) {
          expect(
            kRoutinePlayerExercisesById.values.where((e) => e.id == id).length,
            1,
            reason: '$id must be registered exactly once',
          );
          expect(exerciseById(id)!.name, _names[id]);
        }
        // Sanity: no accidental collision with Jumping Jacks or any other
        // jump/step/side-step/skating/boxing/kick exercise elsewhere.
        final allDisplayNames = kRoutinePlayerExercisesById.values
            .map((e) => e.displayName)
            .toList();
        expect(allDisplayNames.toSet().length, allDisplayNames.length);
      },
    );

    test(
      'metadata preserved from the Tier 2 catalog: durations and playback types',
      () {
        final expectedDuration = {
          'EX044': 35,
          'EX045': 35,
          'EX046': 40,
          'EX047': 45,
          'EX048': 30,
        };
        final expectedPlayback = {
          'EX044': 'TIMER',
          'EX045': 'TIMER',
          'EX046': 'TIMER',
          'EX047': 'SEQUENCE_LOOP',
          'EX048': 'TIMER',
        };
        for (final id in _ids) {
          final def = routinePlayerExerciseById(id)!;
          expect(def.durationSeconds, expectedDuration[id]);
          expect(def.playbackType, expectedPlayback[id]);
          expect(def.category, 'Cardio');
        }
      },
    );
  });

  group('HIIT Cardio Blast order preserved', () {
    test(
      'positions 4-8 are Butt Kicks, Step Jacks, Skaters, Shadow Boxing, Side Steps, in order, right after Jumping Jacks/March In Place/High Knees',
      () {
        final hiit = kWorkoutCatalog.firstWhere(
          (w) => w.id == 'hiit-cardio-blast',
        );
        expect(hiit.exercises.map((e) => e.catalogId).toList(), [
          'EX009',
          'EX076',
          'EX043',
          'EX044',
          'EX045',
          'EX046',
          'EX047',
          'EX048',
        ]);
        expect(hiit.exercises.map((e) => e.title).toList(), [
          'Jumping Jacks',
          'March In Place',
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
      'Full Body Burn and every other routine are untouched by this pass',
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
      },
    );
  });

  group('Asset resolution', () {
    test(
      'each exercise resolves to its own approved folder, all six frames in order, never a legacy or cross-mapped path',
      () {
        for (final id in _ids) {
          final def = routinePlayerExerciseById(id)!;
          final slug = _slugs[id]!;
          final folder = 'assets/glow_up/exercises/$slug/female/v2';
          for (var i = 0; i < 6; i++) {
            expect(def.poses[i].order, i + 1);
            expect(def.poses[i].approvedAsset, '$folder/F_0${i + 1}.png');
            expect(File(def.poses[i].approvedAsset!).existsSync(), isTrue);
          }
          expect(def.poses.map((p) => p.approvedAsset).toSet().length, 6);
          // Never cross-mapped to a sibling exercise in this batch.
          for (final otherId in _ids.where((o) => o != id)) {
            expect(
              def.poses.every(
                (p) => !p.approvedAsset!.contains(_slugs[otherId]!),
              ),
              isTrue,
              reason: '$id must never resolve to $otherId\'s folder',
            );
          }
        }
      },
    );

    test(
      'sequence_preview.png is registered as the dedicated preview for all five, never an active-loop frame',
      () {
        for (final id in _ids) {
          final def = routinePlayerExerciseById(id)!;
          final slug = _slugs[id]!;
          expect(
            def.previewAssetPath,
            'assets/glow_up/exercises/$slug/female/v2/sequence_preview.png',
          );
          expect(File(def.previewAssetPath!).existsSync(), isTrue);
          for (final pose in def.poses) {
            expect(pose.approvedAsset, isNot(def.previewAssetPath));
          }
          final hiit = kWorkoutCatalog.firstWhere(
            (w) => w.id == 'hiit-cardio-blast',
          );
          final entry = hiit.exercises.firstWhere((e) => e.catalogId == id);
          expect(entry.thumbnailAssetPath, def.previewAssetPath);
        }
      },
    );

    test(
      'playback loops smoothly for all five, no pending-approval or missing-asset placeholder ever appears',
      () {
        for (final id in _ids) {
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

  testWidgets(
    'HIIT Cardio Blast: RoutinePlayer shows all five exercises with real frames, correct order, pause/skip/previous all work, no pending placeholder',
    (tester) async {
      final container = await _bootAtWorkoutHub(tester);
      addTearDown(container.dispose);

      await tester.ensureVisible(find.text('Cardio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cardio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HIIT Cardio Blast'));
      await tester.pumpAndSettle();

      for (final id in _ids) {
        final slug = _slugs[id]!;
        expect(find.text(_names[id]!), findsOneWidget);
        expect(
          _hasAssetImageContaining(tester, 'exercises/$slug/female/v2/'),
          isTrue,
        );
      }
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);

      await tester.tap(find.text('Start Workout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );
      // Skip Jumping Jacks/March In Place/High Knees (1-3) to reach Butt
      // Kicks (4).
      for (var i = 0; i < 3; i++) {
        await _clearCountdown(tester, controller);
        controller.skipExercise();
        await tester.pump();
        controller.skipRest();
        await tester.pump();
      }
      await _clearCountdown(tester, controller);
      expect(find.text('Butt Kicks'), findsWidgets);
      expect(
        _hasAssetImageContaining(tester, 'exercises/butt_kicks/female/v2/'),
        isTrue,
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);

      // Pause/resume preserves elapsed time.
      controller.togglePause();
      await tester.pump();
      expect(
        container.read(routinePlayerControllerProvider)!.phase,
        RoutinePlayerPhase.paused,
      );
      final frozen = container
          .read(routinePlayerControllerProvider)!
          .activeElapsedMs;
      await tester.pump(const Duration(seconds: 1));
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

      // Skip forward to Step Jacks (5).
      controller.skipExercise();
      await tester.pump();
      controller.skipRest();
      await tester.pump();
      await _clearCountdown(tester, controller);
      expect(find.text('Step Jacks'), findsWidgets);
      expect(
        _hasAssetImageContaining(tester, 'exercises/step_jacks/female/v2/'),
        isTrue,
      );

      // Previous returns to Butt Kicks.
      controller.previousExercise();
      await tester.pump();
      expect(
        container.read(routinePlayerControllerProvider)!.currentExercise.id,
        'EX044',
        reason: 'previousExercise must return to Butt Kicks',
      );

      controller.endSession();
      expect(
        container.read(routinePlayerControllerProvider),
        isNull,
        reason: 'disposal must leave no active timers/animation/speech behind',
      );
    },
  );

  group('Regression: unrelated exercises/routines untouched', () {
    test(
      'Jumping Jacks, March In Place, High Knees unchanged by this pass',
      () {
        expect(routinePlayerExerciseById('EX009')!.durationSeconds, 45);
        expect(routinePlayerExerciseById('EX076')!.durationSeconds, 40);
        expect(routinePlayerExerciseById('EX043')!.durationSeconds, 35);
      },
    );
  });
}
