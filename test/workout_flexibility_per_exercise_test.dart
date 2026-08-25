// Flexibility per-exercise resolution: generalized from the Strength-only
// mechanism (`_strengthRoutineFor` -> `_perExerciseRoutineFor` in
// app_router.dart). With EX031 Cat-Cow implemented, all seven Evening
// Stretch exercises (EX025-EX031) now have real RoutinePlayer
// definitions — the per-exercise mechanism itself remains in place and
// tested (it never falls back to the legacy Tier-2 session for the whole
// workout just because one exercise in it isn't ready yet), but Evening
// Stretch no longer has any pending exercise left to demonstrate that
// specific behavior with real production data.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:glow_up/app/glow_up_app.dart';
import 'package:glow_up/onboarding/state/onboarding_controller.dart';
import 'package:glow_up/routine_player/data/routine_player_registry.dart';
import 'package:glow_up/routine_player/state/routine_player_controller.dart';
import 'package:glow_up/routing/app_router.dart';
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
    'Evening Stretch: all seven exercises (EX025-EX031) now resolve through the real production registry, every one exposing exactly 6 real frames',
    () {
      final eveningStretch = kWorkoutCatalog.firstWhere(
        (w) => w.id == 'evening-stretch',
      );
      expect(eveningStretch.category, ExerciseCategory.flexibility);
      final ids = eveningStretch.exercises.map((e) => e.catalogId).toList();
      expect(ids, [
        'EX025',
        'EX026',
        'EX027',
        'EX028',
        'EX029',
        'EX030',
        'EX031',
      ]);

      for (final entry in {
        'EX025': 'Hamstring Stretch',
        'EX026': 'Quad Stretch',
        'EX027': 'Butterfly Stretch',
        'EX028': "Child's Pose",
        'EX029': 'Cobra Stretch',
        'EX030': 'Hip Flexor Stretch',
        'EX031': 'Cat-Cow',
      }.entries) {
        final definition = routinePlayerExerciseById(entry.key);
        expect(
          definition,
          isNotNull,
          reason:
              '${entry.key} must resolve to a real RoutinePlayer definition',
        );
        expect(definition!.displayName, entry.value);
        expect(
          definition.poses.length,
          6,
          reason: '${entry.key} must expose exactly 6 visual frames',
        );
        expect(
          definition.poses.every((p) => p.approvedAsset != null),
          isTrue,
          reason:
              'every ${entry.key} pose must have a real approved asset, never a text-only placeholder frame',
        );
      }
    },
  );

  testWidgets(
    'Evening Stretch -> Start Workout opens RoutinePlayer directly, on Hamstring Stretch (approved), never the legacy session',
    (tester) async {
      final container = await _bootAtWorkoutHub(tester);
      addTearDown(container.dispose);

      await tester.ensureVisible(find.text('Flexibility'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flexibility'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Evening Stretch'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start Workout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      expect(find.text('Hamstring Stretch'), findsWidgets);
      expect(
        find.text('COACH ON'),
        findsOneWidget,
        reason:
            'must be the real RoutinePlayer, not the legacy session (which has no voice controls, and would show "Pose 1 of 7" instead)',
      );
      expect(
        find.textContaining('Pose 1 of 7'),
        findsNothing,
        reason:
            'must never show the legacy Tier-2 "Pose X of Y" workout-position label',
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
    'Evening Stretch: all seven exercises (Hamstring Stretch through Cat-Cow) show their real 6-frame images in sequence, never ASSET_PENDING_APPROVAL or Tier-2 text-only fallback',
    (tester) async {
      final container = await _bootAtWorkoutHub(tester);
      addTearDown(container.dispose);

      await tester.ensureVisible(find.text('Flexibility'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flexibility'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Evening Stretch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Workout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );
      // Prepare -> Countdown -> Active, so skipExercise() below isn't a
      // no-op (it's guarded to only fire from active/paused).
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        _hasAssetImageContaining(
          tester,
          'exercises/hamstring_stretch/female/v2/',
        ),
        isTrue,
        reason: 'EX025 must display its real approved PNG, never text-only',
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);

      // Hamstring Stretch -> Quad Stretch (both approved, index 1).
      controller.skipExercise();
      await tester.pump();
      controller.skipRest();
      await tester.pump();
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        _hasAssetImageContaining(tester, 'exercises/quad_stretch/female/v2/'),
        isTrue,
        reason: 'EX026 must display its real approved PNG, never text-only',
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);

      // Quad Stretch -> Butterfly Stretch (both approved, index 2).
      controller.skipExercise();
      await tester.pump();
      controller.skipRest();
      await tester.pump();
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        _hasAssetImageContaining(
          tester,
          'exercises/butterfly_stretch/female/v2/',
        ),
        isTrue,
        reason: 'EX027 must display its real approved PNG, never text-only',
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);

      // Butterfly Stretch -> Child's Pose (both approved, index 3).
      controller.skipExercise();
      await tester.pump();
      controller.skipRest();
      await tester.pump();
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        _hasAssetImageContaining(tester, 'exercises/childs_pose/female/v2/'),
        isTrue,
        reason: 'EX028 must display its real approved PNG, never text-only',
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);

      // Child's Pose -> Cobra Stretch (both approved, index 4).
      controller.skipExercise();
      await tester.pump();
      controller.skipRest();
      await tester.pump();
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        _hasAssetImageContaining(tester, 'exercises/cobra_stretch/female/v2/'),
        isTrue,
        reason: 'EX029 must display its real approved PNG, never text-only',
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);

      // Cobra Stretch -> Hip Flexor Stretch (both approved, index 5).
      controller.skipExercise();
      await tester.pump();
      controller.skipRest();
      await tester.pump();
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        _hasAssetImageContaining(
          tester,
          'exercises/hip_flexor_stretch/female/v2/',
        ),
        isTrue,
        reason: 'EX030 must display its real approved PNG, never text-only',
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);

      // Hip Flexor Stretch -> Cat-Cow (both approved, index 6, the last exercise).
      controller.skipExercise();
      await tester.pump();
      controller.skipRest();
      await tester.pump();
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        _hasAssetImageContaining(tester, 'exercises/cat_cow/female/v2/'),
        isTrue,
        reason: 'EX031 must display its real approved PNG, never text-only',
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);
      expect(tester.takeException(), isNull);

      controller.endSession();
    },
  );

  test(
    'Morning Yoga Flow: all six exercises — Sun Salutation (EX055), Downward Dog (EX056), Warrior I (EX057), Warrior II (EX058), Tree Pose (EX059), Savasana (EX060) — now resolve through the real production registry (not EX032/EX025, which stay reserved for Legs Up Wall/Hamstring Stretch)',
    () {
      final morningYogaFlow = kWorkoutCatalog.firstWhere(
        (w) => w.id == 'morning-yoga-flow',
      );
      expect(morningYogaFlow.category, ExerciseCategory.flexibility);
      final ids = morningYogaFlow.exercises.map((e) => e.catalogId).toList();
      expect(ids, ['EX055', 'EX056', 'EX057', 'EX058', 'EX059', 'EX060']);

      for (final entry in {
        'EX055': 'Sun Salutation',
        'EX056': 'Downward Dog',
        'EX057': 'Warrior I',
        'EX058': 'Warrior II',
        'EX059': 'Tree Pose',
        'EX060': 'Savasana',
      }.entries) {
        final definition = routinePlayerExerciseById(entry.key);
        expect(definition, isNotNull);
        expect(definition!.displayName, entry.value);
        expect(definition.poses.length, 6);
        expect(definition.poses.every((p) => p.approvedAsset != null), isTrue);
      }
      expect(
        routinePlayerExerciseById('EX032'),
        isNull,
        reason:
            'EX032 must never resolve in Tier 1 — it stays reserved for Legs Up Wall in the legacy Tier 2 catalog',
      );
      expect(
        routinePlayerExerciseById('EX025')!.displayName,
        'Hamstring Stretch',
        reason:
            'EX025 must remain Hamstring Stretch — Tree Pose is EX059, not EX025',
      );
    },
  );

  testWidgets(
    'Morning Yoga Flow -> Start Workout opens RoutinePlayer directly, on Sun Salutation (EX055, approved), never the legacy session',
    (tester) async {
      final container = await _bootAtWorkoutHub(tester);
      addTearDown(container.dispose);

      await tester.ensureVisible(find.text('Flexibility'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flexibility'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Morning Yoga Flow'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start Workout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      expect(find.text('Sun Salutation'), findsWidgets);
      expect(
        find.text('COACH ON'),
        findsOneWidget,
        reason:
            'must be the real RoutinePlayer, not the legacy session (which has no voice controls, and would show "Pose 1 of 6" instead)',
      );
      expect(
        find.textContaining('Pose 1 of 6'),
        findsNothing,
        reason:
            'must never show the legacy Tier-2 "Pose X of Y" workout-position label',
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
    'Morning Yoga Flow: all six exercises — Sun Salutation -> Downward Dog -> Warrior I -> Warrior II -> Tree Pose -> Savasana — now show their real 6-frame images, no pending stand-in left in this workout',
    (tester) async {
      final container = await _bootAtWorkoutHub(tester);
      addTearDown(container.dispose);

      await tester.ensureVisible(find.text('Flexibility'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flexibility'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Morning Yoga Flow'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Workout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        _hasAssetImageContaining(tester, 'exercises/sun_salutation/female/v2/'),
        isTrue,
        reason: 'EX055 must display its real approved PNG, never text-only',
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);

      // Sun Salutation -> Downward Dog (both approved, index 1).
      controller.skipExercise();
      await tester.pump();
      controller.skipRest();
      await tester.pump();
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        _hasAssetImageContaining(tester, 'exercises/downward_dog/female/v2/'),
        isTrue,
        reason: 'EX056 must display its real approved PNG, never text-only',
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);

      // Downward Dog -> Warrior I (both approved, index 2).
      controller.skipExercise();
      await tester.pump();
      controller.skipRest();
      await tester.pump();
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        _hasAssetImageContaining(tester, 'exercises/warrior_i/female/v2/'),
        isTrue,
        reason: 'EX057 must display its real approved PNG, never text-only',
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);

      // Warrior I -> Warrior II (both approved, index 3).
      controller.skipExercise();
      await tester.pump();
      controller.skipRest();
      await tester.pump();
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        _hasAssetImageContaining(tester, 'exercises/warrior_ii/female/v2/'),
        isTrue,
        reason: 'EX058 must display its real approved PNG, never text-only',
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);

      // Warrior II -> Tree Pose (both approved, index 4).
      controller.skipExercise();
      await tester.pump();
      controller.skipRest();
      await tester.pump();
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        _hasAssetImageContaining(tester, 'exercises/tree_pose/female/v2/'),
        isTrue,
        reason: 'EX059 must display its real approved PNG, never text-only',
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);

      // Tree Pose -> Savasana (both approved, index 5, the last exercise).
      controller.skipExercise();
      await tester.pump();
      controller.skipRest();
      await tester.pump();
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        _hasAssetImageContaining(tester, 'exercises/savasana/female/v2/'),
        isTrue,
        reason: 'EX060 must display its real approved PNG, never text-only',
      );
      expect(find.text('ASSET_PENDING_APPROVAL'), findsNothing);
      expect(tester.takeException(), isNull);

      controller.endSession();
    },
  );

  testWidgets(
    'Strength Foundations -> Start Workout still opens RoutinePlayer directly, on Squat — Strength per-exercise gate unaffected by the Flexibility generalization',
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
      expect(find.text('COACH ON'), findsOneWidget);
      expect(container.read(routinePlayerControllerProvider), isNotNull);
      expect(container.read(workoutSessionControllerProvider), isNull);

      container.read(routinePlayerControllerProvider.notifier).endSession();
    },
  );
}
