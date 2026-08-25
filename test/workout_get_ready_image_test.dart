// Covers the "cartoon woman with a baked-in 3 and 'We're about to start!'"
// report: every one of the 8 `workout_ready/*.png` files turned out to
// bake in a full unrelated mockup screen rather than clean character art,
// so WorkoutGetReadyScreen (the legacy pre-exercise screen, still used by
// workouts not yet wired to RoutinePlayer) no longer references them at
// all — it shows only the real current exercise's own first pose, via the
// same shared resolver every other preview surface uses.
//
// Drives WorkoutSessionController directly with small synthetic Workouts
// (built from real catalog Exercise records) rather than navigating a
// specific catalog workout's "Start Workout" button — every real category
// with a verified-image exercise (Strength, Flexibility, Mobility, Cardio)
// has now been promoted to per-exercise RoutinePlayer resolution (see
// `canUsePerExerciseResolution` in app_router.dart), so there is no longer
// any real production workout that both (a) still reaches this legacy
// screen and (b) has a verified image to show. Testing
// WorkoutGetReadyScreen directly against the controller keeps this
// regression guard alive regardless of which category is promoted next.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:glow_up/app/glow_up_app.dart';
import 'package:glow_up/onboarding/state/onboarding_controller.dart';
import 'package:glow_up/routing/app_router.dart';
import 'package:glow_up/workout/data/exercise_catalog.dart';
import 'package:glow_up/workout/models/exercise_models.dart';
import 'package:glow_up/workout/models/workout_models.dart';
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

/// True if any currently-mounted [Image] resolves to an
/// `AssetImage` whose asset name contains [needle].
bool _hasAssetImageContaining(WidgetTester tester, String needle) {
  return tester.widgetList<Image>(find.byType(Image)).any((img) {
    final provider = img.image;
    return provider is AssetImage && provider.assetName.contains(needle);
  });
}

Workout _syntheticWorkout(String id, List<String> catalogIds) {
  return Workout(
    id: id,
    category: ExerciseCategory.recovery,
    title: 'Synthetic Test Workout',
    subtitle: 'Test fixture, never shown in production navigation.',
    heroAssetPath: 'assets/glow_up/illustrations/workout-yoga-hero.png',
    difficulty: WorkoutDifficulty.beginner,
    calories: 0,
    equipment: 'None',
    exercises: [
      for (final catalogId in catalogIds)
        WorkoutExercise.fromCatalog(exerciseById(catalogId)!),
    ],
  );
}

void main() {
  testWidgets(
    'GET READY for a verified exercise (Jumping Jacks) shows its real Figma frame, never the legacy workout_ready mockup art',
    (tester) async {
      final container = await _bootAtWorkoutHub(tester);
      addTearDown(container.dispose);

      container
          .read(workoutSessionControllerProvider.notifier)
          .startSession(
            _syntheticWorkout('get-ready-verified-test', ['EX009']),
          );
      appRouter.push(AppRoutes.workoutSession);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      expect(find.text('GET READY'), findsOneWidget);
      expect(find.text('Jumping Jacks'), findsWidgets);
      expect(
        _hasAssetImageContaining(tester, 'workout_ready'),
        isFalse,
        reason:
            'must never reference the broken gender/TOD mockup illustrations',
      );
      expect(
        _hasAssetImageContaining(tester, 'exercises/jumping_jack/female/v2/'),
        isTrue,
        reason:
            'must show the real current exercise (Jumping Jacks V2), not a generic placeholder',
      );
      expect(
        _hasAssetImageContaining(tester, 'exercises/EX009/female/'),
        isFalse,
        reason: 'must never show the old legacy Tier 2 photo anymore',
      );

      container.read(workoutSessionControllerProvider.notifier).endSession();
    },
  );

  testWidgets(
    'GET READY for an exercise with no verified image renders cleanly, no crash, no mockup art',
    (tester) async {
      final container = await _bootAtWorkoutHub(tester);
      addTearDown(container.dispose);

      // EX042 is the untouched legacy "March In Place" placeholder (no
      // verified image) — still a real, valid Tier 2 catalog record, just no
      // longer referenced by any production routine after EX076 replaced it
      // in HIIT Cardio Blast. Using it here only as a synthetic "genuinely
      // unverified exercise" fixture, the same honest-failure-mode case this
      // test always covered.
      container
          .read(workoutSessionControllerProvider.notifier)
          .startSession(
            _syntheticWorkout('get-ready-unverified-test', ['EX042']),
          );
      appRouter.push(AppRoutes.workoutSession);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      expect(find.text('GET READY'), findsOneWidget);
      expect(find.text('March In Place'), findsWidgets);
      expect(_hasAssetImageContaining(tester, 'workout_ready'), isFalse);

      container.read(workoutSessionControllerProvider.notifier).endSession();
    },
  );
}
