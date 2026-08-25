// Regression coverage for the reported Period & Cycle back-navigation bug:
// the real root cause was that PC03 Cycle Home (unlike every other Cycle
// page) rendered no back affordance at all and `CycleEntryScreen` never
// forwarded its own `onBack` down to it — so once tracking was enabled
// there was no in-app way back on a platform with no OS back gesture
// (Windows). These tests drive the REAL GlowUpApp + real appRouter exactly
// as an owner would, tapping the real back button on every page rather than
// calling `Navigator.pop` programmatically, so a missing/misrouted back
// affordance fails here the same way it would for a real user.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glow_up/app/glow_up_app.dart';
import 'package:glow_up/cycle/models/cycle_models.dart';
import 'package:glow_up/cycle/state/cycle_controller.dart';
import 'package:glow_up/onboarding/state/onboarding_controller.dart';
import 'package:glow_up/routing/app_router.dart';

Future<ProviderContainer> _bootAtCoachPlan(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(402, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer();
  container.read(onboardingControllerProvider.notifier).completeOnboarding();
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const GlowUpApp()),
  );
  appRouter.go(AppRoutes.coachPlan);
  await tester.pumpAndSettle();
  return container;
}

/// Boots straight onto Cycle Home (PC03) by pre-enabling tracking in real
/// controller state before navigating — the same real [CycleController]
/// every screen reads/writes, never a mock.
Future<ProviderContainer> _bootAtCycleHome(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(402, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer();
  container.read(onboardingControllerProvider.notifier).completeOnboarding();
  final cycle = container.read(cycleControllerProvider.notifier);
  await cycle.ready;
  await cycle.updateSettings(const CycleSettings(trackingEnabled: true));
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const GlowUpApp()),
  );
  appRouter.go(AppRoutes.cycle);
  await tester.pumpAndSettle();
  expect(
    find.text('Your rhythm, energy and wellness — connected.'),
    findsOneWidget,
    reason: 'must land on real Cycle Home, not the Awareness opt-in screen',
  );
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Home -> Period & Cycle -> Back -> original screen', () {
    testWidgets(
      'Coach Plan -> Period & Cycle -> Back returns to Coach Plan, not a placeholder',
      (tester) async {
        final container = await _bootAtCoachPlan(tester);
        addTearDown(container.dispose);

        expect(find.text('Your AI Plan'), findsOneWidget);
        await tester.tap(find.text('Period & Cycle'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // Fresh state: tracking never set up/declined -> lands on Awareness (PC01).
        expect(find.text('Make your plan cycle-aware?'), findsOneWidget);

        await tester.tap(find.bySemanticsLabel('Back'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.text('Your AI Plan'),
          findsOneWidget,
          reason:
              'requirement 2: the top-level Period & Cycle page must return to the screen that opened it',
        );
        expect(find.text('Make your plan cycle-aware?'), findsNothing);
      },
    );
  });

  group('Cycle Home -> child page -> Back -> Cycle Home', () {
    testWidgets('Log Period', (tester) async {
      final container = await _bootAtCycleHome(tester);
      addTearDown(container.dispose);

      await tester.tap(find.text('Log period'));
      await tester.pumpAndSettle();
      expect(find.text('Log Period'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text('Your rhythm, energy and wellness — connected.'),
        findsOneWidget,
      );
      expect(find.text('Log Period'), findsNothing);
    });

    testWidgets('Daily Check-In', (tester) async {
      final container = await _bootAtCycleHome(tester);
      addTearDown(container.dispose);

      await tester.tap(find.text('How I feel'));
      await tester.pumpAndSettle();
      expect(find.text('Daily Check-In'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text('Your rhythm, energy and wellness — connected.'),
        findsOneWidget,
      );
    });

    testWidgets('Calendar', (tester) async {
      final container = await _bootAtCycleHome(tester);
      addTearDown(container.dispose);

      await tester.tap(find.text('Calendar ›'));
      await tester.pumpAndSettle();
      expect(find.text('My Calendar'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text('Your rhythm, energy and wellness — connected.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'Notebook (via Calendar) -> Back -> Calendar -> Back -> Cycle Home, no loop',
      (tester) async {
        final container = await _bootAtCycleHome(tester);
        addTearDown(container.dispose);

        await tester.tap(find.text('Calendar ›'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byWidgetPredicate(
            (w) =>
                w is Text &&
                w.data != null &&
                w.data!.startsWith('Open ') &&
                w.data!.endsWith(' notebook'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Daily Notebook'), findsOneWidget);

        await tester.tap(find.bySemanticsLabel('Back'));
        await tester.pumpAndSettle();
        expect(
          find.text('My Calendar'),
          findsOneWidget,
          reason:
              'requirement 1: Notebook returns to Calendar, its real parent, never a placeholder or the wrong page',
        );

        await tester.tap(find.bySemanticsLabel('Back'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.text('Your rhythm, energy and wellness — connected.'),
          findsOneWidget,
        );
        expect(
          find.text('My Calendar'),
          findsNothing,
          reason: 'requirement 4: no navigation loop back into Calendar',
        );
      },
    );

    testWidgets('Insights', (tester) async {
      final container = await _bootAtCycleHome(tester);
      addTearDown(container.dispose);

      await tester.tap(find.text('Cycle insights'));
      await tester.pumpAndSettle();
      expect(find.text('Cycle Insights'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text('Your rhythm, energy and wellness — connected.'),
        findsOneWidget,
      );
    });

    testWidgets('Privacy (via the settings gear)', (tester) async {
      final container = await _bootAtCycleHome(tester);
      addTearDown(container.dispose);

      await tester.tap(find.bySemanticsLabel('Cycle privacy settings'));
      await tester.pumpAndSettle();
      expect(find.text('Cycle Privacy'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text('Your rhythm, energy and wellness — connected.'),
        findsOneWidget,
      );
    });
  });

  group('no navigation loops across the full module', () {
    testWidgets(
      'Home -> Log Period -> Back -> Home -> Insights -> Back -> Home -> Back -> Coach Plan, each step lands exactly once',
      (tester) async {
        final container = await _bootAtCoachPlan(tester);
        addTearDown(container.dispose);
        final cycle = container.read(cycleControllerProvider.notifier);
        await cycle.ready;
        await cycle.updateSettings(const CycleSettings(trackingEnabled: true));

        await tester.tap(find.text('Period & Cycle'));
        await tester.pumpAndSettle();
        expect(
          find.text('Your rhythm, energy and wellness — connected.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Log period'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Back'));
        await tester.pumpAndSettle();
        expect(
          find.text('Your rhythm, energy and wellness — connected.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Cycle insights'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Back'));
        await tester.pumpAndSettle();
        expect(
          find.text('Your rhythm, energy and wellness — connected.'),
          findsOneWidget,
        );

        await tester.tap(find.bySemanticsLabel('Back'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.text('Your AI Plan'),
          findsOneWidget,
          reason:
              'the whole round trip terminates back at Coach Plan exactly once, not stuck in a loop',
        );
        expect(
          find.text('Your rhythm, energy and wellness — connected.'),
          findsNothing,
        );
      },
    );
  });

  group('persisted state remains after back navigation', () {
    testWidgets('a period logged on Log Period survives Back to Cycle Home', (
      tester,
    ) async {
      final container = await _bootAtCycleHome(tester);
      addTearDown(container.dispose);

      await tester.tap(find.text('Log period'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Heavy'));
      await tester.pump();
      await tester.tap(find.text('Save period log'));
      await tester.pumpAndSettle();
      // Log Period's own onSaved pops back to Cycle Home.
      expect(
        find.text('Your rhythm, energy and wellness — connected.'),
        findsOneWidget,
      );

      final today = container
          .read(cycleControllerProvider)
          .value!
          .dayEntryFor(DateTime.now());
      expect(
        today?.flow,
        FlowLevel.heavy,
        reason:
            'the real controller state must still hold the saved flow after returning to Cycle Home',
      );

      await tester.tap(find.bySemanticsLabel('Cycle privacy settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();

      final afterRoundTrip = container
          .read(cycleControllerProvider)
          .value!
          .dayEntryFor(DateTime.now());
      expect(
        afterRoundTrip?.flow,
        FlowLevel.heavy,
        reason:
            'requirement 5: back navigation must never reset saved Period & Cycle state',
      );
    });
  });
}
