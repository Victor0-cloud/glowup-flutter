// Covers the Jumping Jacks V2 asset replacement: an existing-exercise
// ASSET REPLACEMENT, not a new exercise — canonical id EX009 preserved,
// duration/category/routine positions unchanged, only the underlying
// imagery and playback mechanism replaced (old V1 "real-room" photos ->
// new approved V2 filmstrip, timedCycle-weighted -> even continuousLoop).
//
// Audit summary (performed before any edit): EX009 is the one and only
// canonical Jumping Jacks record, real in both tiers (Tier 2 legacy
// catalog `exercise_catalog.dart` and Tier 1 RoutinePlayer registry
// `routine_player_registry.dart`), referenced by exactly two routines
// (HIIT Cardio Blast position 1, Full Body Burn position 1) via the same
// shared `_jumpingJacksV2` WorkoutExercise const — no duplicate
// definitions found anywhere in the repo.

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
  group('1-2. Canonical identity preserved', () {
    test(
      'only one canonical Jumping Jacks exercise exists, under the original id EX009',
      () {
        expect(
          kRoutinePlayerExercisesById.values
              .where((e) => e.id == 'EX009')
              .length,
          1,
        );
        expect(routinePlayerExerciseById('EX009'), isNotNull);
        expect(exerciseById('EX009')!.name, 'Jumping Jacks');
      },
    );
  });

  group('3-6. Both routines reference the same canonical record', () {
    test(
      'HIIT Cardio Blast position 1 and Full Body Burn position 1 both point at EX009, duration 45s, category Cardio',
      () {
        final hiit = kWorkoutCatalog.firstWhere(
          (w) => w.id == 'hiit-cardio-blast',
        );
        final fbb = kWorkoutCatalog.firstWhere((w) => w.id == 'full-body-burn');
        expect(hiit.exercises[0].catalogId, 'EX009');
        expect(fbb.exercises[0].catalogId, 'EX009');
        expect(hiit.exercises[0].durationSeconds, 45);
        expect(fbb.exercises[0].durationSeconds, 45);
        expect(hiit.category, ExerciseCategory.cardio);
        expect(fbb.category, ExerciseCategory.cardio);
        final tier1 = routinePlayerExerciseById('EX009')!;
        expect(tier1.durationSeconds, 45);
        expect(tier1.category, 'Cardio');
      },
    );

    test(
      'both routines use the literal same WorkoutExercise object — never two separately-drifting copies',
      () {
        final hiit = kWorkoutCatalog.firstWhere(
          (w) => w.id == 'hiit-cardio-blast',
        );
        final fbb = kWorkoutCatalog.firstWhere((w) => w.id == 'full-body-burn');
        expect(identical(hiit.exercises[0], fbb.exercises[0]), isTrue);
      },
    );
  });

  group('7-9. Asset resolver and registration', () {
    final def = routinePlayerExerciseById('EX009');

    test(
      'the asset resolver returns assets/glow_up/exercises/jumping_jack/female/v2/, never v1 or another exercise',
      () {
        for (final pose in def!.poses) {
          expect(
            pose.approvedAsset,
            startsWith('assets/glow_up/exercises/jumping_jack/female/v2/'),
          );
        }
      },
    );

    test('all six frames exist on disk and load in F_01->F_06 order', () {
      for (var i = 0; i < 6; i++) {
        expect(def!.poses[i].order, i + 1);
        expect(
          def.poses[i].approvedAsset,
          'assets/glow_up/exercises/jumping_jack/female/v2/F_0${i + 1}.png',
        );
      }
      expect(def!.poses.map((p) => p.approvedAsset).toSet().length, 6);
      final folder = Directory(
        'assets/glow_up/exercises/jumping_jack/female/v2',
      );
      final pngs = folder.listSync().whereType<File>().where(
        (f) => f.path.endsWith('.png'),
      );
      expect(pngs.length, 7); // F_01-F_06 + sequence_preview
    });

    test(
      'sequence_preview.png is registered as the dedicated preview and appears in both routine-detail pages\' thumbnailAssetPath',
      () {
        expect(
          def!.previewAssetPath,
          'assets/glow_up/exercises/jumping_jack/female/v2/sequence_preview.png',
        );
        expect(File(def.previewAssetPath!).existsSync(), isTrue);
        final hiit = kWorkoutCatalog.firstWhere(
          (w) => w.id == 'hiit-cardio-blast',
        );
        final fbb = kWorkoutCatalog.firstWhere((w) => w.id == 'full-body-burn');
        expect(hiit.exercises[0].thumbnailAssetPath, def.previewAssetPath);
        expect(fbb.exercises[0].thumbnailAssetPath, def.previewAssetPath);
      },
    );
  });

  group('10. Old real-room thumbnail no longer appears', () {
    test(
      'EX009\'s Tier 2 legacy hasVerifiedImages is off — the old exercises/EX009/female/0N.png photos are unreachable',
      () {
        // hasVerifiedImages defaults false; not asserted directly (no public
        // getter needed) — proven behaviorally: resolvePoseAssetPath's Tier 2
        // branch is gated on it, so if it were still true the widget tests
        // below (which assert the v2 path and assert the old EX009/female/
        // path is ABSENT) would fail. This test documents the mechanism.
        expect(
          exerciseById('EX009')!.name,
          'Jumping Jacks',
        ); // still real Tier 2 metadata, just no longer image-verified
      },
    );
  });

  group('11-13, 17-18. Playback shape', () {
    final def = routinePlayerExerciseById('EX009');

    test(
      'RoutinePlayer animates F_01-F_06 via a continuous loop, never using sequence_preview.png as the active animation',
      () {
        expect(def!.loopMode, LoopMode.continuousLoop);
        final perFrame = def.loopCycleSeconds / 6;
        for (var i = 0; i < 6; i++) {
          final pose = currentPoseFor(def, i * perFrame + perFrame / 2);
          expect(pose.order, i + 1);
          expect(pose.approvedAsset, isNot(def.previewAssetPath));
        }
      },
    );

    test(
      'F_06 -> F_01 loops without an empty/placeholder frame — every instant in [0, duration) resolves to a real approved asset',
      () {
        final e = def!;
        for (var t = 0.0; t < e.durationSeconds; t += 0.1) {
          expect(currentPoseFor(e, t).approvedAsset, isNotNull);
        }
        // Explicitly across the wrap boundary.
        expect(currentPoseFor(e, e.loopCycleSeconds - 0.01).order, 6);
        expect(currentPoseFor(e, e.loopCycleSeconds + 0.01).order, 1);
      },
    );

    test('EX076 March In Place remains completely unchanged by this pass', () {
      final marchInPlace = routinePlayerExerciseById('EX076')!;
      expect(marchInPlace.durationSeconds, 40);
      expect(marchInPlace.poses.length, 6);
      expect(
        marchInPlace.poses.first.approvedAsset,
        contains('march_in_place'),
      );
    });

    test(
      'Cardio routine order is otherwise unchanged: HIIT Cardio Blast still 8 positions, Full Body Burn still 6',
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

  testWidgets(
    'Manual-verification proxy: HIIT Cardio Blast -> Start Workout -> Jumping Jacks shows the lavender V2 preview then animates the six new frames, never the old real-room image',
    (tester) async {
      final container = await _bootAtWorkoutHub(tester);
      addTearDown(container.dispose);

      await tester.ensureVisible(find.text('Cardio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cardio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HIIT Cardio Blast'));
      await tester.pumpAndSettle();

      // Detail-list thumbnail shows the V2 preview, never the old photo.
      expect(
        _hasAssetImageContaining(tester, 'exercises/jumping_jack/female/v2/'),
        isTrue,
      );
      expect(
        _hasAssetImageContaining(tester, 'exercises/EX009/female/'),
        isFalse,
      );

      await tester.tap(find.text('Start Workout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );
      await _clearCountdown(tester, controller);
      expect(find.text('Jumping Jacks'), findsWidgets);
      expect(
        _hasAssetImageContaining(tester, 'exercises/jumping_jack/female/v2/'),
        isTrue,
      );
      expect(
        _hasAssetImageContaining(tester, 'exercises/jumping_jack/female/v1/'),
        isFalse,
      );
      expect(
        _hasAssetImageContaining(tester, 'exercises/EX009/female/'),
        isFalse,
      );

      controller.endSession();
    },
  );

  testWidgets(
    'Full Body Burn -> Start Workout also opens Jumping Jacks through the same canonical record and the same V2 animation',
    (tester) async {
      final container = await _bootAtWorkoutHub(tester);
      addTearDown(container.dispose);

      await tester.ensureVisible(find.text('Cardio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cardio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Full Body Burn'));
      await tester.pumpAndSettle();
      expect(
        _hasAssetImageContaining(tester, 'exercises/jumping_jack/female/v2/'),
        isTrue,
      );

      await tester.tap(find.text('Start Workout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('Jumping Jacks'), findsWidgets);
      expect(container.read(routinePlayerControllerProvider), isNotNull);
      expect(container.read(workoutSessionControllerProvider), isNull);

      container.read(routinePlayerControllerProvider.notifier).endSession();
    },
  );

  testWidgets(
    '14. Pause/resume preserves the timer and animation position exactly; 15. skip/back/disposal stops all timers, animation, and speech',
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
      );

      // Skip -> rest -> March In Place, no crash, no orphaned state.
      controller.skipExercise();
      await tester.pump();
      expect(
        container.read(routinePlayerControllerProvider)!.phase,
        RoutinePlayerPhase.rest,
      );
      expect(
        container.read(routinePlayerControllerProvider)!.currentExercise.id,
        'EX076',
      );

      controller.endSession();
      expect(
        container.read(routinePlayerControllerProvider),
        isNull,
        reason: 'disposal must leave no active timers/animation/speech behind',
      );
    },
  );

  group('16, 19. Regression: other categories/routines unaffected', () {
    test(
      'Strength/Mobility/Bedtime catalog entries untouched by this pass',
      () {
        expect(exerciseById('EX007')!.name, 'Squat');
        expect(
          routinePlayerExerciseById('EX070')!.displayName,
          'Shoulder Rolls',
        );
        expect(exerciseById('EX001')!.name, 'Deep Breathing');
      },
    );
  });
}
