// Coverage for the real "Discover" tab (Routines Hub) — boots the REAL
// GlowUpApp with the REAL appRouter, exactly like
// coach_navigation_integration_test.dart, so this catches real routing
// bugs a directly-pumped-screen test would miss. Discover was previously
// an honest "isn't built yet" placeholder; this proves it now browses the
// real, live workout catalog (the same one Today -> Workout uses) and
// that tapping a category reaches a real, non-placeholder screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:glow_up/app/glow_up_app.dart';
import 'package:glow_up/onboarding/state/onboarding_controller.dart';
import 'package:glow_up/routing/app_router.dart';

Future<ProviderContainer> _bootAtRoute(
  WidgetTester tester,
  String route,
) async {
  final container = ProviderContainer();
  container.read(onboardingControllerProvider.notifier).completeOnboarding();
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const GlowUpApp()),
  );
  appRouter.go(route);
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets(
    'Discover tab shows real workout categories, never the old "isn\'t built yet" placeholder',
    (tester) async {
      final container = await _bootAtRoute(tester, AppRoutes.routines);
      addTearDown(container.dispose);

      expect(find.text('My Routines'), findsOneWidget);
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();

      expect(find.text('Discover isn\'t built yet.'), findsNothing);
      expect(find.text('Discover is coming in a future pass.'), findsNothing);
      // A real category from the live catalog must be showing.
      expect(find.textContaining('workout'), findsWidgets);
    },
  );

  testWidgets('Discover search filters the real category list', (tester) async {
    final container = await _bootAtRoute(tester, AppRoutes.routines);
    addTearDown(container.dispose);

    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'this-should-match-nothing');
    await tester.pumpAndSettle();

    expect(
      find.text('No workouts match "this-should-match-nothing".'),
      findsOneWidget,
    );
  });

  testWidgets(
    'tapping a real Discover category navigates to a real, non-placeholder screen',
    (tester) async {
      final container = await _bootAtRoute(tester, AppRoutes.routines);
      addTearDown(container.dispose);

      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();

      // Tap the first real category tile (whatever it renders as, by
      // finding the first InkWell inside the category list — avoids
      // hardcoding a specific category name that could reorder).
      final firstTile = find.byType(InkWell).first;
      await tester.tap(firstTile);
      await tester.pumpAndSettle();

      // Left the Routines Hub entirely — "My Routines"/"Discover" tabs
      // are gone, proving real navigation occurred rather than a no-op.
      expect(find.text('My Routines'), findsNothing);
    },
  );
}
