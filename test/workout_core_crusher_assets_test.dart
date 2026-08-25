// Covers the Core Crusher workout-detail asset regression: the reported
// broken hero image and broken Plank thumbnail. Verifies real asset
// resolution against the canonical exercise catalog/registry (never
// cross-mapped to another exercise), that the detail screen renders
// without asset exceptions, and that a genuinely-missing asset degrades to
// the branded fallback instead of Flutter's red/broken-image box.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:glow_up/app/glow_up_app.dart';
import 'package:glow_up/onboarding/state/onboarding_controller.dart';
import 'package:glow_up/routine_player/data/routine_player_registry.dart';
import 'package:glow_up/routing/app_router.dart';
import 'package:glow_up/workout/data/workout_catalog.dart';
import 'package:glow_up/workout/models/exercise_models.dart';
import 'package:glow_up/workout/models/workout_models.dart';
import 'package:glow_up/workout/screens/workout_detail_screen.dart';
import 'package:glow_up/workout/widgets/workout_widgets.dart';

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

Workout get _coreCrusher =>
    kWorkoutCatalog.firstWhere((w) => w.id == 'core-crusher');

void main() {
  group('Core Crusher asset resolution', () {
    test('1. Core Crusher hero does not resolve to a missing asset', () {
      // heroAssetPath must point at a file that is actually bundled — this
      // repo has no asset-existence-check tool at the unit level, so the
      // real regression coverage is the widget test below (renders without
      // an Image.asset exception). This test locks the exact path in place
      // so a future accidental rename shows up as a diff here.
      expect(
        _coreCrusher.heroAssetPath,
        'assets/glow_up/illustrations/workout-yoga-hero.png',
      );
    });

    test(
      '2. Plank thumbnail resolves to a valid, real Plank asset (not null, not another exercise)',
      () {
        final plankRow = _coreCrusher.exercises.firstWhere(
          (e) => e.catalogId == 'EX011',
        );
        final assetPath = resolvePoseAssetPath(plankRow, step: 1);
        expect(
          assetPath,
          isNotNull,
          reason:
              'Plank (EX011) has hasVerifiedImages=true, so step 1 must resolve',
        );
        expect(assetPath, 'assets/glow_up/exercises/EX011/female/01.png');
      },
    );

    test('3. exercise thumbnails never cross-map to another exercise', () {
      for (final row in _coreCrusher.exercises) {
        final assetPath = resolvePoseAssetPath(row, step: 1);
        if (assetPath == null) {
          continue; // no verified image yet — fine, must stay text-only, never a substitute
        }
        // Every verified-image exercise resolves either via the Tier 2
        // legacy EX0XX id folder, or (added for exercises Tier 2 has no
        // entry for at all, e.g. Dead Bug here) via its own Tier 1
        // registry entry for that exact catalogId — checked by asserting
        // the path is literally one of that id's own approved Tier 1
        // poses, not by string-matching the id into the filename (Tier 1
        // filenames don't always embed the numeric id, e.g. Dead Bug's
        // predate this convention).
        final tier1 = routinePlayerExerciseById(row.catalogId!);
        final isOwnTier1Asset =
            tier1 != null &&
            tier1.poses.any((p) => p.approvedAsset == assetPath);
        expect(
          assetPath.contains('${row.catalogId}/') || isOwnTier1Asset,
          isTrue,
          reason:
              '${row.title} must resolve to its own exercise\'s image, never another exercise\'s',
        );
      }
    });

    test(
      '6. Dead Bug EX012 resolves to V2 in the RoutinePlayer registry, and its Core Crusher thumbnail now correctly shows that real image (fixed alongside the Morning Yoga thumbnail repair — same root cause: resolvePoseAssetPath previously had no Tier 1 fallback)',
      () {
        final routinePlayerDeadBug = kRoutinePlayerPhase1Qa.firstWhere(
          (e) => e.id == 'EX012',
        );
        for (final pose in routinePlayerDeadBug.poses) {
          expect(
            pose.approvedAsset,
            contains('assets/glow_up/exercises/dead_bug/female/v2/'),
          );
        }
        // Core Crusher's own EX012 row (legacy `lib/workout` catalog) has no
        // verified image (hasVerifiedImages defaults to false for EX012 in
        // exercise_catalog.dart), so Tier 2 has nothing — resolvePoseAssetPath
        // now falls back to Dead Bug's real Tier 1 image instead of leaving
        // the card blank.
        final deadBugRow = _coreCrusher.exercises.firstWhere(
          (e) => e.catalogId == 'EX012',
        );
        expect(
          resolvePoseAssetPath(deadBugRow, step: 1),
          routinePlayerDeadBug.poses.first.approvedAsset,
        );
      },
    );
  });

  group('Core Crusher detail screen rendering', () {
    testWidgets(
      '4. Workout -> Core -> Core Crusher renders with zero asset exceptions',
      (tester) async {
        final container = await _bootAtWorkoutHub(tester);
        addTearDown(container.dispose);

        await tester.ensureVisible(find.text('Core'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Core'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Core Crusher'));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason:
              'no Image.asset exception (e.g. missing hero/thumbnail) may reach the widget tree',
        );

        expect(find.text('Core Crusher'), findsWidgets);
        expect(find.text('Plank'), findsOneWidget);
        expect(find.text('Dead Bug'), findsOneWidget);

        // No broken-image fallback should have been needed for the real,
        // verified production assets.
        expect(find.byKey(const Key('workout_hero_fallback')), findsNothing);
      },
    );

    testWidgets(
      '6. Workout -> Core -> Core Crusher detail screen lists all 8 exercises by name, including Leg Raises and Bird Dog',
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

        expect(find.text('EXERCISES (8)'), findsOneWidget);

        final names = [
          'Plank',
          'Dead Bug',
          'Bicycle Crunch',
          'Leg Raises',
          'Russian Twist',
          'Bird Dog',
          'Mountain Climbers',
          'Fire Hydrant',
        ];
        for (final name in names) {
          final finder = find.text(name);
          await tester.scrollUntilVisible(
            finder,
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(
            finder,
            findsOneWidget,
            reason:
                '"$name" must render on the real Core Crusher detail screen exercise list',
          );
        }
      },
    );

    testWidgets(
      '5. optional hero fallback renders cleanly (no red/broken-image box) when the hero asset is genuinely missing',
      (tester) async {
        final brokenWorkout = Workout(
          id: 'test-broken-hero',
          category: ExerciseCategory.core,
          title: 'Test Workout',
          subtitle: 'For asset-fallback testing only.',
          heroAssetPath: 'assets/glow_up/illustrations/does-not-exist.png',
          difficulty: WorkoutDifficulty.beginner,
          calories: 0,
          equipment: 'None',
          exercises: const [],
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: WorkoutDetailScreen(
                workout: brokenWorkout,
                onBack: () {},
                onStart: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason:
              'a missing hero asset must never surface as an uncaught exception',
        );
        expect(
          find.byKey(const Key('workout_hero_fallback')),
          findsOneWidget,
          reason:
              'must show the branded placeholder, never Flutter\'s red/broken-image box',
        );
      },
    );
  });
}
