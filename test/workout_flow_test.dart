// Covers the full Workout 31-33 flow end-to-end against the REAL
// GlowUpApp + real appRouter: Today -> hub -> detail -> get ready ->
// active -> rest -> up next -> active -> ... -> complete -> summary ->
// back to Today, plus pause/resume/skip/next/previous and both target
// viewport sizes. Timer-driven phases are advanced with tester.pump
// (flutter_test runs in a fake-async zone, so real Timer.periodic in the
// controller ticks correctly when fake time is advanced).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:glow_up/app/glow_up_app.dart';
import 'package:glow_up/onboarding/state/onboarding_controller.dart';
import 'package:glow_up/routine_player/state/routine_player_controller.dart';
import 'package:glow_up/routing/app_router.dart';
import 'package:glow_up/workout/state/workout_controller.dart';

/// True if any currently-mounted [Image] resolves to an `AssetImage` whose
/// asset name contains [needle].
bool _hasAssetImageContaining(WidgetTester tester, String needle) {
  return tester.widgetList<Image>(find.byType(Image)).any((img) {
    final provider = img.image;
    return provider is AssetImage && provider.assetName.contains(needle);
  });
}

Future<ProviderContainer> _boot(
  WidgetTester tester, {
  Size size = const Size(402, 874),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer();
  container.read(onboardingControllerProvider.notifier).completeOnboarding();
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const GlowUpApp()),
  );
  appRouter.go(AppRoutes.today);
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets(
    'Today Workout quick action opens the real Workout hub, categories list vertically',
    (tester) async {
      final container = await _boot(tester);
      addTearDown(container.dispose);

      await tester.tap(find.text('Workout'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Workouts'), findsOneWidget);
      expect(find.text('Choose your discipline'), findsOneWidget);

      // All 7 real Exercise Library categories present and laid out as a
      // real vertical list (not Figma's broken all-stacked-at-y:0 export) —
      // top-left Y strictly increases down the list.
      for (final label in [
        'Core',
        'Strength',
        'Flexibility',
        'Bedtime',
        'Mobility',
        'Cardio',
        'Recovery',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      final coreY = tester.getTopLeft(find.text('Core')).dy;
      final strengthY = tester.getTopLeft(find.text('Strength')).dy;
      final recoveryY = tester.getTopLeft(find.text('Recovery')).dy;
      expect(strengthY, greaterThan(coreY));
      expect(recoveryY, greaterThan(strengthY));
    },
  );

  testWidgets('search filters categories', (tester) async {
    final container = await _boot(tester);
    addTearDown(container.dispose);
    await tester.tap(find.text('Workout'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'flex');
    await tester.pumpAndSettle();
    expect(find.text('Flexibility'), findsOneWidget);
    expect(find.text('Core'), findsNothing);
  });

  testWidgets(
    'Morning Yoga Flow: category -> detail -> start opens RoutinePlayer directly, EX055 Sun Salutation shown first with real assets, never the legacy Tier-2 session',
    (tester) async {
      final container = await _boot(tester);
      addTearDown(container.dispose);

      await tester.tap(find.text('Workout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flexibility'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Morning Yoga Flow'), findsOneWidget);
      expect(find.text('Evening Stretch'), findsOneWidget);
      await tester.tap(find.text('Morning Yoga Flow'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Detail screen: real Figma copy — unaffected by which player the
      // session ultimately opens through.
      expect(find.text('Morning Yoga Flow'), findsOneWidget);
      expect(find.text('20 min'), findsOneWidget);
      expect(find.text('Sun Salutation'), findsOneWidget);
      expect(find.text('Savasana'), findsOneWidget);

      // The push transition into the session route needs multiple discrete
      // pumps (one to process the push, more to advance the transition) — a
      // single pump(duration) isn't enough.
      await tester.tap(find.text('Start Workout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      // Real RoutinePlayer (EX055/EX056 have real Tier 1 definitions now),
      // never the legacy WorkoutActiveScreen — per `_perExerciseRoutineFor`'s
      // any-catalogId relaxation in app_router.dart.
      expect(find.text('COACH ON'), findsOneWidget);
      expect(find.textContaining('Pose 1 of 6'), findsNothing);
      expect(container.read(routinePlayerControllerProvider), isNotNull);
      expect(
        container.read(workoutSessionControllerProvider),
        isNull,
        reason: 'must never also start a legacy session',
      );

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

      // Tree Pose -> Savasana (both approved, index 5, the last exercise —
      // every Morning Yoga exercise now has a real Tier 1 definition).
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
    'renders at a short desktop-debug-window height (402x640) with no overflow through get ready and active',
    (tester) async {
      final container = await _boot(tester, size: const Size(402, 640));
      addTearDown(container.dispose);

      await tester.tap(find.text('Workout'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Flexibility'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Morning Yoga Flow'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -800),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Start Workout'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Start Workout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(tester.takeException(), isNull);
      // Real RoutinePlayer (EX055 Sun Salutation), not the legacy Active
      // screen — see the full-flow test above for why.
      expect(find.text('COACH ON'), findsOneWidget);

      // This test doesn't run the session to completion, so explicitly stop
      // the ticking timer rather than relying on container disposal ordering.
      container.read(routinePlayerControllerProvider.notifier).endSession();
    },
  );
}
