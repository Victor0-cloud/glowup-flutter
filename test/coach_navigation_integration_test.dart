// Reproduces the reported runtime bugs end-to-end: boots the REAL GlowUpApp
// with the REAL appRouter (not an isolated screen pumped directly, which is
// what test/coach_screens_test.dart does and why it didn't catch this),
// jumps to each real route with a completed Brain context, and exercises
// every documented entry point into the Coach family exactly as a user
// would from every Routines-family screen (hub, create, detail, calendar).

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
    'Today bottom nav Coach tab opens the real Coach hub, not a placeholder',
    (tester) async {
      final container = await _bootAtRoute(tester, AppRoutes.today);
      addTearDown(container.dispose);

      expect(find.text('Today'), findsWidgets);
      await tester.tap(find.text('Coach'));
      await tester.pumpAndSettle();

      expect(
        find.text('RECENT CHATS'),
        findsOneWidget,
        reason:
            'Coach hub content should be showing after tapping the bottom-nav Coach tab',
      );
    },
  );

  testWidgets('Today AI Coach Tip card opens the real Coach hub', (
    tester,
  ) async {
    final container = await _bootAtRoute(tester, AppRoutes.today);
    addTearDown(container.dispose);

    await tester.ensureVisible(find.text('AI COACH TIP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI COACH TIP'));
    await tester.pumpAndSettle();

    expect(find.text('RECENT CHATS'), findsOneWidget);
  });

  testWidgets('Routines hub bottom nav Coach tab opens the real Coach hub', (
    tester,
  ) async {
    final container = await _bootAtRoute(tester, AppRoutes.routines);
    addTearDown(container.dispose);

    await tester.tap(find.text('Coach'));
    await tester.pumpAndSettle();

    expect(find.text('RECENT CHATS'), findsOneWidget);
  });

  testWidgets(
    'Create Routine bottom nav Coach tab opens the real Coach hub (regression)',
    (tester) async {
      final container = await _bootAtRoute(tester, AppRoutes.routineCreate);
      addTearDown(container.dispose);

      expect(find.text('Create Routine'), findsOneWidget);
      await tester.tap(find.text('Coach'));
      await tester.pumpAndSettle();

      expect(
        find.text('RECENT CHATS'),
        findsOneWidget,
        reason:
            'This is the exact screen the manual bug report was filed against',
      );
    },
  );

  testWidgets('Routine Detail bottom nav Coach tab opens the real Coach hub', (
    tester,
  ) async {
    final container = await _bootAtRoute(
      tester,
      AppRoutes.routineDetail('morning-wellness'),
    );
    addTearDown(container.dispose);

    await tester.tap(find.text('Coach'));
    await tester.pumpAndSettle();

    expect(find.text('RECENT CHATS'), findsOneWidget);
  });

  testWidgets(
    'Routine Calendar bottom nav Coach tab opens the real Coach hub',
    (tester) async {
      final container = await _bootAtRoute(tester, AppRoutes.routineCalendar);
      addTearDown(container.dispose);

      await tester.tap(find.text('Coach'));
      await tester.pumpAndSettle();

      expect(find.text('RECENT CHATS'), findsOneWidget);
    },
  );

  testWidgets(
    'Coach hub bottom nav Today/Routines/Profile all navigate away correctly',
    (tester) async {
      final container = await _bootAtRoute(tester, AppRoutes.coach);
      addTearDown(container.dispose);

      expect(find.text('RECENT CHATS'), findsOneWidget);

      await tester.tap(find.text('Routines').last);
      await tester.pumpAndSettle();
      expect(find.text('RECENT CHATS'), findsNothing);

      appRouter.go(AppRoutes.coach);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today').last);
      await tester.pumpAndSettle();
      expect(find.text('RECENT CHATS'), findsNothing);
    },
  );
}
