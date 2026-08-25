// Covers the manual QA script's category-browsing checks against the REAL
// app + router: Workout -> Cardio -> Jumping Jacks, Workout -> Strength ->
// Lunges/Push-Ups/Squat, Workout -> Bedtime -> the approved bedtime
// sequence, Workout -> Mobility / Recovery -> their real exercises.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:glow_up/app/glow_up_app.dart';
import 'package:glow_up/onboarding/state/onboarding_controller.dart';
import 'package:glow_up/routing/app_router.dart';

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

/// Scrolls the category (7 entries) into view before tapping it — the
/// full list doesn't fit in one screenful even at the true mobile height.
Future<void> _tapCategory(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Workout -> Cardio shows real cardio routines with Jumping Jacks',
    (tester) async {
      final container = await _bootAtWorkoutHub(tester);
      addTearDown(container.dispose);

      await _tapCategory(tester, 'Cardio');
      expect(tester.takeException(), isNull);
      expect(find.text('HIIT Cardio Blast'), findsOneWidget);
      expect(find.text('Full Body Burn'), findsOneWidget);

      await tester.tap(find.text('HIIT Cardio Blast'));
      await tester.pumpAndSettle();
      expect(find.text('Jumping Jacks'), findsOneWidget);
    },
  );

  testWidgets('Workout -> Strength shows Lunges, Push-Ups, and Squat', (
    tester,
  ) async {
    final container = await _bootAtWorkoutHub(tester);
    addTearDown(container.dispose);

    await _tapCategory(tester, 'Strength');
    expect(tester.takeException(), isNull);
    expect(find.text('Strength Foundations'), findsOneWidget);

    await tester.tap(find.text('Strength Foundations'));
    await tester.pumpAndSettle();
    expect(find.text('Lunges'), findsOneWidget);
    expect(find.text('Push-Ups'), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);
  });

  testWidgets('Workout -> Bedtime shows the approved bedtime sequence', (
    tester,
  ) async {
    final container = await _bootAtWorkoutHub(tester);
    addTearDown(container.dispose);

    await _tapCategory(tester, 'Bedtime');
    expect(tester.takeException(), isNull);
    expect(find.text('Bedtime Meditation'), findsOneWidget);

    await tester.tap(find.text('Bedtime Meditation'));
    await tester.pumpAndSettle();
    for (final name in [
      'Deep Breathing',
      'Full Body Stretch',
      'Knee-to-Chest',
      'Supine Twist',
      'Ankle Circles',
      'Sit-Up Reach',
    ]) {
      expect(
        find.text(name),
        findsOneWidget,
        reason: '$name missing from Bedtime Meditation',
      );
    }
  });

  testWidgets('Workout -> Mobility shows real mobility exercises', (
    tester,
  ) async {
    final container = await _bootAtWorkoutHub(tester);
    addTearDown(container.dispose);

    await _tapCategory(tester, 'Mobility');
    expect(tester.takeException(), isNull);
    expect(find.text('Mobility Reset'), findsOneWidget);

    await tester.tap(find.text('Mobility Reset'));
    await tester.pumpAndSettle();
    expect(find.text('Shoulder Rolls'), findsOneWidget);
    expect(find.text('Arm Circles'), findsOneWidget);
  });

  testWidgets('Workout -> Recovery shows real recovery exercises', (
    tester,
  ) async {
    final container = await _bootAtWorkoutHub(tester);
    addTearDown(container.dispose);

    await _tapCategory(tester, 'Recovery');
    expect(tester.takeException(), isNull);
    expect(find.text('Recovery Flow'), findsOneWidget);

    await tester.tap(find.text('Recovery Flow'));
    await tester.pumpAndSettle();
    expect(find.text('Figure Four Stretch'), findsOneWidget);
    expect(find.text('Calf Stretch'), findsOneWidget);
  });

  testWidgets('Workout -> Core shows real core exercises', (tester) async {
    final container = await _bootAtWorkoutHub(tester);
    addTearDown(container.dispose);

    await _tapCategory(tester, 'Core');
    expect(tester.takeException(), isNull);
    expect(find.text('Core Crusher'), findsOneWidget);

    await tester.tap(find.text('Core Crusher'));
    await tester.pumpAndSettle();
    expect(find.text('Plank'), findsOneWidget);
    expect(find.text('Dead Bug'), findsOneWidget);
  });

  testWidgets(
    'Workout -> Flexibility -> Evening Stretch shows Hamstring Stretch by name in its exercise list',
    (tester) async {
      final container = await _bootAtWorkoutHub(tester);
      addTearDown(container.dispose);

      await _tapCategory(tester, 'Flexibility');
      expect(tester.takeException(), isNull);
      expect(find.text('Evening Stretch'), findsOneWidget);

      await tester.tap(find.text('Evening Stretch'));
      await tester.pumpAndSettle();
      expect(
        find.text('Hamstring Stretch'),
        findsOneWidget,
        reason:
            'EX025 must be visible by name on the real Evening Stretch detail screen',
      );
    },
  );
}
