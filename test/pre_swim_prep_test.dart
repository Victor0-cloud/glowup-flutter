// Covers the OFFICIAL V1 Pre-Swim routine (owner decision, superseding the
// earlier 8-exercise/285s version): exactly 7 exercises, 390s raw exercise
// time + 6×5s transitions = 420s (7:00) total, in the exact approved order,
// every id an existing already-approved Tier 1 registry definition (never
// renumbered, never duplicated), a real RoutinePlayer session that never
// inserts a transition after the final exercise, and that this new
// per-routine duration/transition override is opt-in only — it changes
// nothing about Recovery Flow, which shares 4 of these 7 exercise ids.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glow_up/app/glow_up_app.dart';
import 'package:glow_up/onboarding/state/onboarding_controller.dart';
import 'package:glow_up/routine_player/audio/music_manager.dart';
import 'package:glow_up/routine_player/data/routine_player_registry.dart';
import 'package:glow_up/routine_player/models/exercise_definition.dart';
import 'package:glow_up/routine_player/models/routine_player_state.dart';
import 'package:glow_up/routine_player/state/routine_player_controller.dart';
import 'package:glow_up/routine_player/voice/voice_coach.dart';
import 'package:glow_up/routine_player/voice/voice_speaker.dart';
import 'package:glow_up/routing/app_router.dart';
import 'package:glow_up/workout/brain/workout_brain.dart';
import 'package:glow_up/workout/data/workout_catalog.dart';

/// Mirrors exactly what `_routinePlayerRoutineFor` (app_router.dart) does
/// for a `useCatalogDurations` routine — same per-instance override, so
/// these controller-level tests exercise the real mechanism rather than a
/// re-invented one.
ExerciseDefinition _preSwimExercise(String catalogId) {
  final workout = workoutById('pre-swim-prep')!;
  final seconds = workout.exercises
      .firstWhere((e) => e.catalogId == catalogId)
      .durationSeconds;
  return routinePlayerExerciseById(
    catalogId,
  )!.copyWith(durationSeconds: seconds);
}

// Same direct-construction pattern as routine_player_engine_test.dart:
// a SilentSpeaker-backed controller, driven with real Timer.periodic +
// Future.delayed (no fake pump), at the controller level with no widget
// tree needed.
RoutinePlayerController _newController() => RoutinePlayerController(
  VoiceCoach(SilentSpeaker()),
  MusicManager(),
  WorkoutSignalLog(),
);

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('condition not met within $timeout');
    }
    await Future.delayed(const Duration(milliseconds: 20));
  }
}

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

/// The approved order and per-exercise seconds — order from the staging
/// design reference (assets/glow_up/exercises/pre_swim/routine_manifest.json
/// + README.md), seconds preserved exactly from that same source. The
/// 5-second transition is a separate, new owner decision, not from the
/// staging docs.
const _preSwimOrder = [
  'EX051',
  'EX079',
  'EX078',
  'EX077',
  'EX050',
  'EX052',
  'EX049',
];
const _preSwimSeconds = [45, 60, 60, 60, 45, 60, 60];
const _kTransitionSeconds = 5;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Pre-Swim Prep workout catalog — official 7-exercise / 420s spec', () {
    test('exists under Mobility with the exact approved 7-exercise order', () {
      final workout = workoutById('pre-swim-prep')!;
      expect(workout.category.name, 'mobility');
      expect(
        workout.exercises,
        hasLength(7),
        reason: 'requirement 1: seven exercises present',
      );
      expect(
        workout.exercises.map((e) => e.catalogId).toList(),
        _preSwimOrder,
        reason: 'requirement 7: approved order',
      );
    });

    test(
      'every exercise duration matches the approved staging seconds exactly, summing to 390',
      () {
        final workout = workoutById('pre-swim-prep')!;
        expect(
          workout.exercises.map((e) => e.durationSeconds).toList(),
          _preSwimSeconds,
        );
        final rawSum = workout.exercises.fold<int>(
          0,
          (sum, e) => sum + e.durationSeconds,
        );
        expect(
          rawSum,
          390,
          reason: 'requirement 2: exercise durations total exactly 390 seconds',
        );
      },
    );

    test(
      'six transitions of exactly 5 seconds each, total routine duration exactly 420 seconds',
      () {
        final workout = workoutById('pre-swim-prep')!;
        expect(
          workout.restSecondsOverride,
          _kTransitionSeconds,
          reason: 'requirement 4: every transition is exactly 5 seconds',
        );
        expect(
          workout.exercises.length - 1,
          6,
          reason:
              'requirement 3: six transitions exist between seven exercises',
        );
        expect(
          workout.totalSeconds,
          420,
          reason:
              'requirement 5: total routine duration is exactly 420 seconds',
        );
        expect(
          workout.totalMinutes,
          7,
          reason: 'the displayed routine duration is exactly 7:00',
        );
      },
    );

    test(
      'the previous 285-second 8-exercise Pre-Swim is no longer the active specification',
      () {
        final workout = workoutById('pre-swim-prep')!;
        const oldOrder = [
          'EX070',
          'EX077',
          'EX079',
          'EX051',
          'EX078',
          'EX073',
          'EX064',
          'EX069',
        ];
        expect(workout.exercises.length, isNot(8));
        expect(
          workout.exercises.map((e) => e.catalogId).toList(),
          isNot(oldOrder),
        );
        expect(
          workout.totalSeconds,
          isNot(285),
          reason: 'requirement 9/10: old 285s spec is superseded',
        );
      },
    );

    test(
      'exactly one Pre-Swim workout definition exists in the catalog — no second/staging/hidden registration',
      () {
        final matches = kWorkoutCatalog
            .where((w) => w.id == 'pre-swim-prep')
            .toList();
        expect(matches, hasLength(1));
        final byTitle = kWorkoutCatalog
            .where((w) => w.title == 'Pre-Swim Prep')
            .toList();
        expect(
          byTitle,
          hasLength(1),
          reason: 'no differently-id\'d duplicate sharing the same title',
        );
      },
    );

    test(
      'useCatalogDurations is opt-in — set for Pre-Swim only, not a blanket architecture change',
      () {
        final preSwim = workoutById('pre-swim-prep')!;
        expect(preSwim.useCatalogDurations, isTrue);
        for (final workout in kWorkoutCatalog) {
          if (workout.id == 'pre-swim-prep') continue;
          expect(
            workout.useCatalogDurations,
            isFalse,
            reason:
                '"${workout.id}" must keep its shared registry exercise durations unchanged',
          );
          expect(
            workout.restSecondsOverride,
            isNull,
            reason:
                '"${workout.id}" must keep the shared 30-second rest/transition unchanged',
          );
        }
      },
    );
  });

  group(
    'Tier 1 registration — every Pre-Swim exercise resolves with no missing assets',
    () {
      for (final id in _preSwimOrder) {
        test(
          '$id has a real Tier 1 definition with 6 distinct frames and a matching preview',
          () {
            final def = routinePlayerExerciseById(id);
            expect(
              def,
              isNotNull,
              reason:
                  'requirement 8: $id must resolve to a real registry definition',
            );
            expect(
              def!.id,
              id,
              reason:
                  '$id must resolve to itself, never a colliding/aliased definition',
            );
            expect(
              def.poses.length,
              6,
              reason:
                  'requirement 6 (assets): $id must have exactly 6 real frames',
            );
            expect(
              def.poses.map((p) => p.approvedAsset).toSet().length,
              6,
              reason: '$id must have 6 distinct frame assets',
            );
            expect(
              def.poses.every((p) => p.approvedAsset != def.previewAssetPath),
              isTrue,
            );
          },
        );
      }

      test(
        'the seven Pre-Swim catalogIds are all distinct — requirement 9: no duplicate ids introduced',
        () {
          expect(_preSwimOrder.toSet().length, 7);
        },
      );
    },
  );

  group('Workout -> Mobility -> Pre-Swim Prep -> Start Workout', () {
    testWidgets(
      'the literal owner journey: Workouts -> Mobility category card -> Pre-Swim Prep card -> seven exercises visible',
      (tester) async {
        final container = await _bootAtWorkoutHub(tester);

        // Step 2/3: the Mobility category card is visible on the Workout
        // Hub and opens the category list — a real tap, not a direct
        // `appRouter.go`, so this fails the way an owner clicking through
        // the app actually would if the card were ever hidden/unreachable.
        expect(find.text('Mobility'), findsOneWidget);
        await tester.tap(find.text('Mobility'));
        await tester.pumpAndSettle();

        // Step 4: "Pre-Swim" / "Pre-Swim Prep" is visible in that category.
        expect(find.text('Pre-Swim Prep'), findsOneWidget);

        // Step 5: opening it shows the workout detail with all 7 exercises.
        await tester.tap(find.text('Pre-Swim Prep'));
        await tester.pumpAndSettle();
        expect(
          find.text('EXERCISES (7)'),
          findsOneWidget,
          reason: 'requirement 6: the detail screen shows all seven exercises',
        );
        expect(
          find.text('Start Workout'),
          findsOneWidget,
          reason:
              'confirms the real /workout/pre-swim-prep detail screen matched, not a placeholder',
        );

        container.dispose();
      },
    );

    testWidgets(
      'Pre-Swim is reachable through the existing Workout Hub / Mobility navigation, opens on Standing Chest Opener',
      (tester) async {
        final container = await _bootAtWorkoutHub(tester);
        appRouter.go('/workout/pre-swim-prep');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Start Workout'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text('Standing Chest Opener'),
          findsWidgets,
          reason:
              'requirement 10: reachable via the existing workout navigation',
        );
        expect(find.textContaining('ASSET_PENDING_APPROVAL'), findsNothing);
        container.dispose();
      },
    );
  });

  group(
    'RoutinePlayerController — real 5-second transitions, never after the last exercise',
    () {
      final realRoutine = [
        for (final id in _preSwimOrder) _preSwimExercise(id),
      ];

      test(
        'a Pre-Swim session starts with each exercise already at its own approved duration, not the shared registry default',
        () {
          final controller = _newController();
          addTearDown(controller.dispose);
          controller.startRoutine(
            realRoutine,
            sourceWorkout: workoutById('pre-swim-prep'),
          );

          final s = controller.state!;
          expect(s.currentExercise.id, 'EX051');
          expect(
            s.currentExercise.durationSeconds,
            45,
            reason:
                "EX051 Chest Opener carries Pre-Swim's own 45s here, not its shared registry default (25s)",
          );
        },
      );

      test(
        'finishing a non-final exercise starts a REST/transition phase that is exactly 5 seconds for Pre-Swim, showing the next exercise',
        () async {
          final controller = _newController();
          addTearDown(controller.dispose);
          // A short 2-exercise routine (real Pre-Swim exercises/assets, just a
          // shorter list) keeps this test fast — the 5s override value itself
          // is what's under test, not how long a real 45-60s exercise takes.
          controller.startRoutine([
            _preSwimExercise('EX051'),
            _preSwimExercise('EX079'),
          ], sourceWorkout: workoutById('pre-swim-prep'));
          controller.skipPrepare();
          await _waitUntil(
            () => controller.state!.phase == RoutinePlayerPhase.active,
          );

          controller.skipExercise();

          final s = controller.state!;
          expect(
            s.phase,
            RoutinePlayerPhase.rest,
            reason:
                'requirement 6 (transition behavior): a transition state follows a non-final exercise',
          );
          expect(
            s.restTotalSeconds,
            _kTransitionSeconds,
            reason: 'requirement 4: exactly 5 seconds for Pre-Swim',
          );
          expect(
            s.currentExercise.id,
            'EX079',
            reason:
                'the transition shows the upcoming (next) exercise, per requirement 6',
          );
          expect(
            s.restElapsedMs,
            0,
            reason:
                'the transition clock starts fresh — the finished exercise\'s active time is never counted as transition time',
          );
        },
      );

      test(
        'finishing the LAST exercise never inserts a transition — goes straight to complete',
        () async {
          final controller = _newController();
          addTearDown(controller.dispose);
          // A single-exercise routine: index 0 is trivially the last exercise,
          // exercising the exact same `isLastExercise` gate a real 7-exercise
          // Pre-Swim session hits on its 7th exercise.
          controller.startRoutine([
            _preSwimExercise('EX049'),
          ], sourceWorkout: workoutById('pre-swim-prep'));
          controller.skipPrepare();
          await _waitUntil(
            () => controller.state!.phase == RoutinePlayerPhase.active,
          );

          controller.skipExercise();

          expect(
            controller.state!.phase,
            RoutinePlayerPhase.complete,
            reason: 'requirement 6: no transition follows the final exercise',
          );
        },
      );

      test(
        'rest/transition pause-resume behavior stays truthful with the shorter 5-second duration',
        () async {
          final controller = _newController();
          addTearDown(controller.dispose);
          controller.startRoutine([
            _preSwimExercise('EX051'),
            _preSwimExercise('EX079'),
          ], sourceWorkout: workoutById('pre-swim-prep'));
          controller.skipPrepare();
          await _waitUntil(
            () => controller.state!.phase == RoutinePlayerPhase.active,
          );
          controller.skipExercise();
          expect(controller.state!.phase, RoutinePlayerPhase.rest);

          controller.togglePause();
          expect(controller.state!.phase, RoutinePlayerPhase.restPaused);
          final pausedRemaining = controller.state!.restRemainingSeconds;
          await Future<void>.delayed(const Duration(milliseconds: 250));
          expect(
            controller.state!.restRemainingSeconds,
            pausedRemaining,
            reason: 'paused transition time must not keep counting down',
          );

          controller.togglePause();
          expect(controller.state!.phase, RoutinePlayerPhase.rest);
        },
      );
    },
  );

  group('Recovery Flow is unaffected by Pre-Swim reusing 4 of its exercises', () {
    test(
      'Recovery Flow keeps its own exact original ids, order, and shared-registry durations',
      () {
        final recovery = workoutById('recovery-flow')!;
        expect(recovery.exercises.map((e) => e.catalogId).toList(), [
          'EX049',
          'EX050',
          'EX051',
          'EX052',
        ]);
        expect(recovery.useCatalogDurations, isFalse);
        expect(recovery.restSecondsOverride, isNull);
        // These durations come from `_exercises()` -> the Tier 2 catalog,
        // which was already identical to the Tier 1 registry defaults before
        // this change (verified) — unaffected either way since Recovery
        // never opts into `useCatalogDurations`.
        expect(recovery.exercises.map((e) => e.durationSeconds).toList(), [
          40,
          40,
          25,
          40,
        ]);
      },
    );

    test(
      'EX049 Figure Four Stretch\'s own shared Tier 1 registry duration is unchanged at 40 seconds',
      () {
        expect(routinePlayerExerciseById('EX049')!.durationSeconds, 40);
        expect(routinePlayerExerciseById('EX050')!.durationSeconds, 40);
        expect(routinePlayerExerciseById('EX051')!.durationSeconds, 25);
        expect(routinePlayerExerciseById('EX052')!.durationSeconds, 40);
      },
    );
  });

  group('no network / no backend touched by this change', () {
    test(
      'workout_catalog.dart and routine_player_controller.dart never import an HTTP/Supabase client',
      () {
        for (final path in [
          'lib/workout/data/workout_catalog.dart',
          'lib/routine_player/state/routine_player_controller.dart',
        ]) {
          final content = File(path).readAsStringSync();
          expect(content.contains("import 'package:http"), isFalse);
          expect(content.toLowerCase().contains('supabase'), isFalse);
        }
      },
    );
  });
}
