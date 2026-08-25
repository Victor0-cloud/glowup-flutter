// Phase 1 Strength asset cleanup, step 2: Strength workouts resolve
// per-exercise (never the all-or-nothing gate every other category still
// uses) — an approved exercise uses its real Tier 1 RoutinePlayer assets,
// a pending one shows the generic ASSET_PENDING_APPROVAL state, and the
// whole session runs through the one shared RoutinePlayer with working
// Skip/Previous. Never falls back to a legacy Strength image.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:glow_up/app/glow_up_app.dart';
import 'package:glow_up/onboarding/state/onboarding_controller.dart';
import 'package:glow_up/routine_player/data/routine_player_registry.dart';
import 'package:glow_up/routine_player/state/routine_player_controller.dart';
import 'package:glow_up/routing/app_router.dart';
import 'package:glow_up/workout/data/exercise_catalog.dart';
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

/// True if any currently-mounted [Image] resolves to an `AssetImage`
/// whose asset name contains [needle].
bool _hasAssetImageContaining(WidgetTester tester, String needle) {
  return tester.widgetList<Image>(find.byType(Image)).any((img) {
    final provider = img.image;
    return provider is AssetImage && provider.assetName.contains(needle);
  });
}

void main() {
  test(
    'Strength Foundations contains Wall Push-Ups (EX019) and Donkey Kicks (EX022), moved from Advanced Strength Circuit, both resolving through the production registry',
    () {
      final strengthFoundations = kWorkoutCatalog.firstWhere(
        (w) => w.id == 'strength-foundations',
      );
      final ids = strengthFoundations.exercises
          .map((e) => e.catalogId)
          .toList();
      expect(ids, [
        'EX007',
        'EX008',
        'EX010',
        'EX018',
        'EX020',
        'EX021',
        'EX019',
        'EX022',
      ]);

      for (final id in ['EX019', 'EX022']) {
        final definition = routinePlayerExerciseById(id);
        expect(
          definition,
          isNotNull,
          reason:
              '$id must resolve to a real RoutinePlayer definition through the production registry',
        );
        expect(definition!.id, id);
      }

      // No duplicate placement — Advanced Strength Circuit must no longer
      // list either exercise, so each has exactly one authoritative routine.
      final advancedCircuit = kWorkoutCatalog.firstWhere(
        (w) => w.id == 'advanced-strength-circuit',
      );
      final advancedIds = advancedCircuit.exercises
          .map((e) => e.catalogId)
          .toList();
      expect(advancedIds, isNot(contains('EX019')));
      expect(advancedIds, isNot(contains('EX022')));
      expect(advancedIds, ['EX023', 'EX024']);
    },
  );

  testWidgets(
    'Strength Foundations -> Start Workout opens RoutinePlayer directly, on Squat (approved), never the legacy session',
    (tester) async {
      final container = await _bootAtWorkoutHub(tester);
      addTearDown(container.dispose);

      await tester.ensureVisible(find.text('Strength'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Strength'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Strength Foundations'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start Workout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      expect(find.text('Squat'), findsWidgets);
      expect(
        find.text('COACH ON'),
        findsOneWidget,
        reason:
            'must be the real RoutinePlayer, not the legacy session (which has no voice controls)',
      );
      expect(container.read(routinePlayerControllerProvider), isNotNull);
      expect(
        container.read(workoutSessionControllerProvider),
        isNull,
        reason: 'must never also start a legacy session',
      );

      container.read(routinePlayerControllerProvider.notifier).endSession();
    },
  );

  testWidgets(
    'Strength Foundations: approved exercises (Squat/Lunges/Push-Ups/Glute Bridge) show real frames, never a legacy image, as the session advances',
    (tester) async {
      final container = await _bootAtWorkoutHub(tester);
      addTearDown(container.dispose);

      await tester.ensureVisible(find.text('Strength'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Strength'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Strength Foundations'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Workout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );
      // Prepare -> Countdown -> Active, so Squat's skipExercise() below
      // isn't a no-op (it's guarded to only fire from active/paused).
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        _hasAssetImageContaining(tester, 'exercises/squat/female/v2/'),
        isTrue,
      );
      expect(
        _hasAssetImageContaining(tester, 'exercises/squat/female/v1/'),
        isFalse,
        reason: 'the old real-room V1 set must never appear anymore',
      );
      expect(
        _hasAssetImageContaining(tester, 'exercises/EX007/'),
        isFalse,
        reason: 'must never show the legacy Squat photo',
      );

      // Squat -> Rest -> Lunges Prepare -> Lunges Active.
      controller.skipExercise();
      await tester.pump();
      controller.skipRest();
      await tester.pump();
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
        reason: 'the old bilateral left/right V1 set must never appear anymore',
      );
      expect(
        _hasAssetImageContaining(tester, 'exercises/EX008/'),
        isFalse,
        reason: 'must never show the legacy Lunges photo',
      );

      // Lunges -> Rest -> Push-Ups Prepare -> Push-Ups Active.
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
        reason: 'the old real-room V1 set must never appear anymore',
      );
      expect(
        _hasAssetImageContaining(tester, 'exercises/EX010/'),
        isFalse,
        reason: 'must never show the legacy Push-Ups photo',
      );

      controller.endSession();
    },
  );

  test(
    'Advanced Strength Circuit contains Shoulder Taps (EX023) and Superman (EX024), both resolving through the production registry — kStrengthAssetPendingApproval is now empty, every Strength exercise is approved',
    () {
      expect(
        kStrengthAssetPendingApproval,
        isEmpty,
        reason:
            'all 10 Strength exercises are now Tier 1-approved; nothing should remain marked pending',
      );

      final advancedCircuit = kWorkoutCatalog.firstWhere(
        (w) => w.id == 'advanced-strength-circuit',
      );
      final ids = advancedCircuit.exercises.map((e) => e.catalogId).toList();
      expect(ids, ['EX023', 'EX024']);

      for (final id in ['EX023', 'EX024']) {
        final definition = routinePlayerExerciseById(id);
        expect(
          definition,
          isNotNull,
          reason:
              '$id must resolve to a real RoutinePlayer definition through the production registry',
        );
        expect(definition!.id, id);
      }
    },
  );

  testWidgets(
    'Advanced Strength Circuit: Shoulder Taps and Superman (both approved) show real frames, never ASSET_PENDING_APPROVAL, as the session advances',
    (tester) async {
      // Wall Push-Ups (EX019) and Donkey Kicks (EX022) moved into Strength
      // Foundations (see workout_catalog.dart). Shoulder Taps (EX023) and
      // Superman (EX024) are also now approved, so Advanced Strength
      // Circuit — like Strength Foundations — no longer has any pending
      // exercise left to demonstrate the ASSET_PENDING_APPROVAL stand-in.
      final container = await _bootAtWorkoutHub(tester);
      addTearDown(container.dispose);

      await tester.ensureVisible(find.text('Strength'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Strength'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Advanced Strength Circuit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Workout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );
      controller.skipPrepare(); // Shoulder Taps: Prepare -> Countdown -> Active
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        _hasAssetImageContaining(tester, 'exercises/shoulder_taps/female/v2/'),
        isTrue,
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);

      // Shoulder Taps -> Superman.
      controller.skipExercise();
      await tester.pump();
      controller.skipRest();
      await tester.pump();
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Superman'), findsWidgets);
      expect(
        _hasAssetImageContaining(tester, 'exercises/superman/female/v2/'),
        isTrue,
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);
      expect(tester.takeException(), isNull);

      controller.endSession();
    },
  );
}
