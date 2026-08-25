// Covers the Core Crusher -> Start Workout -> RoutinePlayer wiring: the
// real 8-exercise sequence shown on the detail screen must be exactly what
// gets passed to the existing RoutinePlayer engine (never a duplicate
// player, never a dropped/substituted exercise), and Dead Bug/Fire Hydrant
// must land on their real V2 definitions through that same path.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:glow_up/app/glow_up_app.dart';
import 'package:glow_up/onboarding/state/onboarding_controller.dart';
import 'package:glow_up/routine_player/data/routine_player_registry.dart';
import 'package:glow_up/routine_player/state/routine_player_controller.dart';
import 'package:glow_up/routing/app_router.dart';
import 'package:glow_up/workout/data/workout_catalog.dart';
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

void main() {
  group('Core Crusher exercise sequence resolves through the canonical registry', () {
    test(
      'exact 8 Core Crusher exercises, in order, each resolving through routinePlayerExerciseById',
      () {
        final coreCrusher = kWorkoutCatalog.firstWhere(
          (w) => w.id == 'core-crusher',
        );
        final ids = coreCrusher.exercises.map((e) => e.catalogId).toList();
        expect(ids, [
          'EX011',
          'EX012',
          'EX013',
          'EX014',
          'EX015',
          'EX016',
          'EX017',
          'EX054',
        ]);

        final names = coreCrusher.exercises.map((e) => e.title).toList();
        expect(names, [
          'Plank',
          'Dead Bug',
          'Bicycle Crunch',
          'Leg Raises',
          'Russian Twist',
          'Bird Dog',
          'Mountain Climbers',
          'Fire Hydrant',
        ]);

        for (final id in ids) {
          final definition = routinePlayerExerciseById(id!);
          expect(
            definition,
            isNotNull,
            reason:
                '$id must resolve to a real RoutinePlayer definition, not fall back to the legacy session flow',
          );
          expect(
            definition!.id,
            id,
            reason: 'must never resolve to a different exercise\'s definition',
          );
        }
      },
    );

    test(
      'Leg Raises (EX014) resolves to its real V2 definition through the exact same lookup Core Crusher uses',
      () {
        final definition = routinePlayerExerciseById('EX014')!;
        expect(definition.displayName, 'Leg Raises');
        expect(definition.poses.length, 6);
        expect(definition.poses.every((p) => p.approvedAsset != null), isTrue);
        for (final pose in definition.poses) {
          expect(
            pose.approvedAsset,
            contains('assets/glow_up/exercises/leg_raises/female/v2/'),
          );
        }
      },
    );

    test(
      'Russian Twist (EX015) resolves to its real V2 definition through the exact same lookup Core Crusher uses',
      () {
        final definition = routinePlayerExerciseById('EX015')!;
        expect(definition.displayName, 'Russian Twist');
        expect(definition.poses.length, 6);
        expect(definition.poses.every((p) => p.approvedAsset != null), isTrue);
        for (final pose in definition.poses) {
          expect(
            pose.approvedAsset,
            contains('assets/glow_up/exercises/russian_twist/female/v2/'),
          );
        }
      },
    );

    test(
      'Bird Dog (EX016) resolves to its real V2 definition through the exact same lookup Core Crusher uses',
      () {
        final definition = routinePlayerExerciseById('EX016')!;
        expect(definition.displayName, 'Bird Dog');
        expect(definition.poses.length, 6);
        expect(definition.poses.every((p) => p.approvedAsset != null), isTrue);
        for (final pose in definition.poses) {
          expect(
            pose.approvedAsset,
            contains('assets/glow_up/exercises/bird_dog/female/v2/'),
          );
        }
      },
    );

    test(
      'Dead Bug (EX012) resolves to its real V2 definition through the exact same lookup Core Crusher uses',
      () {
        final definition = routinePlayerExerciseById('EX012')!;
        expect(definition.displayName, 'Dead Bug');
        expect(definition.customLoopOrder, [1, 2, 3, 4, 5, 6, 4, 1]);
        for (final pose in definition.poses) {
          expect(
            pose.approvedAsset,
            contains('assets/glow_up/exercises/dead_bug/female/v2/'),
          );
        }
      },
    );

    test(
      'Bicycle Crunch (EX013) resolves to its real V2 definition through the exact same lookup Core Crusher uses, immediately after Dead Bug',
      () {
        final coreCrusher = kWorkoutCatalog.firstWhere(
          (w) => w.id == 'core-crusher',
        );
        final ids = coreCrusher.exercises.map((e) => e.catalogId).toList();
        expect(
          ids.indexOf('EX013'),
          ids.indexOf('EX012') + 1,
          reason:
              'Bicycle Crunch must sit immediately after Dead Bug in the routine order',
        );

        final definition = routinePlayerExerciseById('EX013')!;
        expect(definition.displayName, 'Bicycle Crunch');
        expect(definition.poses.length, 6);
        expect(definition.poses.every((p) => p.approvedAsset != null), isTrue);
        for (final pose in definition.poses) {
          expect(
            pose.approvedAsset,
            contains('assets/glow_up/exercises/bicycle_crunch/female/v2/'),
          );
        }
      },
    );

    test(
      'Fire Hydrant (EX054) resolves to its real V2 definition through the exact same lookup Core Crusher uses',
      () {
        final definition = routinePlayerExerciseById('EX054')!;
        expect(definition.displayName, 'Fire Hydrant');
        final order = definition.poses.map((p) => p.poseId).toList();
        expect(currentPoseFor(definition, 0).poseId, order[0]);
        for (final pose in definition.poses) {
          expect(
            pose.approvedAsset,
            contains('assets/glow_up/exercises/fire_hydrant/female/v2/'),
          );
        }
      },
    );
  });

  group('Core Crusher Start Workout opens the real RoutinePlayer', () {
    testWidgets(
      'Workout -> Core -> Core Crusher -> Start Workout lands in RoutinePlayer (not the legacy session), on exercise 1 of 8 (Plank), with voice controls visible',
      (tester) async {
        final container = await _bootAtWorkoutHub(tester);
        addTearDown(container.dispose);

        await tester.ensureVisible(find.text('Core'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Core'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Core Crusher'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Start Workout'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);

        // RoutinePlayer-only markers — none of these exist in the legacy
        // workout session screens.
        expect(find.text('EXERCISE 1 OF 8'), findsOneWidget);
        expect(find.text('Plank'), findsWidgets);
        expect(find.text('COACH ON'), findsOneWidget);
        expect(find.text('CUES ONLY'), findsOneWidget);
        expect(find.text('SILENT'), findsOneWidget);

        // Confirm it's really the RoutinePlayer controller driving this, not
        // the legacy workoutSessionController (which must stay untouched/null).
        expect(container.read(routinePlayerControllerProvider), isNotNull);
        expect(
          container.read(workoutSessionControllerProvider),
          isNull,
          reason:
              'Core Crusher must not also start a legacy session in parallel',
        );

        container.read(routinePlayerControllerProvider.notifier).endSession();
      },
    );
  });
}
