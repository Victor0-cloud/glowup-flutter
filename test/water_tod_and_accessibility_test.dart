// Covers the Water Tracker's shared time-of-day variant architecture (all
// 4 periods + Auto/local-time resolution, dev selector debug-only gating),
// unchanged 4-tab navigation, and accessibility requirements: touch target
// size, semantic labels/announcements, non-color-only state, large-text
// scaling, small-screen overflow safety, and reduced-motion.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glow_up/core/tod/tod_period.dart';
import 'package:glow_up/core/widgets/bottom_nav_bar.dart';
import 'package:glow_up/water/screens/water_history_screen.dart';
import 'package:glow_up/water/screens/water_tracker_screen.dart';
import 'package:glow_up/water/state/water_controller.dart';
import 'package:glow_up/water/theme/water_variant_config.dart';
import 'package:glow_up/water/widgets/water_bottle_level.dart';
import 'package:glow_up/water/widgets/water_progress_ring.dart';

Future<ProviderContainer> _bootWith(
  WidgetTester tester, {
  TodPeriod? period,
  Size size = const Size(402, 1200),
  double textScale = 1.0,
  bool disableAnimations = false,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer();
  addTearDown(container.dispose);
  if (period != null) {
    container.read(devTodPeriodOverrideProvider.notifier).state = period;
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: const MaterialApp(home: WaterTrackerScreen()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('time-of-day variants', () {
    for (final period in TodPeriod.values) {
      testWidgets(
        '${period.name} variant renders with its configured accent/ring gradient',
        (tester) async {
          await _bootWith(tester, period: period);

          final ring = tester.widget<WaterProgressRing>(
            find.byType(WaterProgressRing),
          );
          final expected = WaterVariantConfig.byPeriod[period]!;
          expect(ring.gradientColors, expected.ringGradient);
        },
      );
    }

    test(
      'Auto (no dev override) resolves from the real local clock via TodPeriodResolver, never a hardcoded period',
      () {
        const resolver = TodPeriodResolver();
        expect(resolver.resolve(DateTime(2026, 1, 1, 7)), TodPeriod.morning);
        expect(resolver.resolve(DateTime(2026, 1, 1, 13)), TodPeriod.afternoon);
        expect(resolver.resolve(DateTime(2026, 1, 1, 18)), TodPeriod.evening);
        expect(resolver.resolve(DateTime(2026, 1, 1, 23)), TodPeriod.night);
        expect(resolver.resolve(DateTime(2026, 1, 1, 2)), TodPeriod.night);
      },
    );

    test(
      'every TodPeriod has a Water variant config — no period silently falls back',
      () {
        for (final period in TodPeriod.values) {
          expect(
            WaterVariantConfig.byPeriod.containsKey(period),
            isTrue,
            reason: '$period is missing a WaterVariantConfig',
          );
        }
      },
    );

    test(
      'water blue stays the identity color regardless of the accent used per period',
      () {
        for (final entry in WaterVariantConfig.byPeriod.entries) {
          expect(
            entry.value.ringGradient.contains(WaterColors.brandBlue),
            isTrue,
            reason:
                '${entry.key} ring gradient must still include the constant hydration blue',
          );
        }
      },
    );
  });

  group('dev TOD selector is debug-build only', () {
    test(
      'both Water screens gate DevTodPicker behind kDebugMode, never render it unconditionally',
      () {
        for (final path in [
          'lib/water/screens/water_tracker_screen.dart',
          'lib/water/screens/water_history_screen.dart',
        ]) {
          final content = File(path).readAsStringSync();
          expect(
            content.contains('if (kDebugMode) const DevTodPicker()'),
            isTrue,
            reason: '$path must gate DevTodPicker behind kDebugMode',
          );
        }
      },
    );
  });

  group('navigation stays 4-tab, no Water tab added', () {
    test('AppNavTab is exactly today/routines/coach/profile', () {
      expect(AppNavTab.values, [
        AppNavTab.today,
        AppNavTab.routines,
        AppNavTab.coach,
        AppNavTab.profile,
      ]);
    });

    test(
      'WaterTrackerScreen does not embed its own BottomNavBar (it is a pushed sub-screen, not a 5th tab)',
      () {
        final content = File(
          'lib/water/screens/water_tracker_screen.dart',
        ).readAsStringSync();
        expect(content.contains('BottomNavBar'), isFalse);
      },
    );
  });

  group('accessibility', () {
    testWidgets(
      'the progress ring exposes a real semantic percent/amount announcement, not just a decorative shape',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _bootWith(tester);
        final semantics = tester.getSemantics(find.byType(WaterProgressRing));
        expect(semantics.label, contains('water progress'));
        expect(semantics.value, contains('percent of goal'));
        handle.dispose();
      },
    );

    testWidgets(
      'quick-add chips and the Add Water button meet the 44x44 minimum touch target',
      (tester) async {
        await _bootWith(tester);

        final chip = find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Add 250 ml of water',
        );
        final chipSize = tester.getSize(chip);
        expect(chipSize.height, greaterThanOrEqualTo(44));

        final addWaterButton = find.text('Add Water');
        final buttonAncestor = find
            .ancestor(of: addWaterButton, matching: find.byType(SizedBox))
            .first;
        final buttonSize = tester.getSize(buttonAncestor);
        expect(buttonSize.height, greaterThanOrEqualTo(44));
      },
    );

    testWidgets(
      'the empty log state is conveyed through text, not color alone',
      (tester) async {
        await _bootWith(tester);
        expect(
          find.textContaining('No water logged yet today'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'reduced motion collapses the progress ring and bottle-level animations to zero duration',
      (tester) async {
        await _bootWith(tester, disableAnimations: true);
        // Both the ring and the bottle-level visualization animate their fill
        // via a TweenAnimationBuilder<double> — every instance must respect
        // reduced motion, not just the first one found.
        final tweens = tester.widgetList<TweenAnimationBuilder<double>>(
          find.byType(TweenAnimationBuilder<double>),
        );
        expect(tweens, isNotEmpty);
        for (final tween in tweens) {
          expect(tween.duration, Duration.zero);
        }
      },
    );

    testWidgets('large text scaling does not throw a layout overflow error', (
      tester,
    ) async {
      await _bootWith(tester, textScale: 2.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a small-screen surface does not overflow', (tester) async {
      await _bootWith(tester, size: const Size(320, 568));
      expect(tester.takeException(), isNull);
    });
  });

  group('Water History screen', () {
    Future<ProviderContainer> bootHistory(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(402, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: WaterHistoryScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();
      return container;
    }

    testWidgets('shows an honest empty state with no logged history', (
      tester,
    ) async {
      await bootHistory(tester);
      expect(find.text('No history yet'), findsOneWidget);
    });

    testWidgets(
      'shows daily totals and weekly completion once entries exist, never inventing values',
      (tester) async {
        final container = await bootHistory(tester);
        final water = container.read(waterControllerProvider.notifier);
        await water.ready;
        await water.addEntry(2500); // above the default 2000ml goal

        await tester.pump();
        await tester.pump();

        expect(find.text('No history yet'), findsNothing);
        expect(find.text('This Week'), findsOneWidget);
        expect(find.text('Daily Totals'), findsOneWidget);
        expect(find.textContaining('2500 ml'), findsOneWidget);
      },
    );
  });

  group('approved design reference alignment', () {
    testWidgets(
      'the water-level bottle visualization renders alongside the progress ring',
      (tester) async {
        await _bootWith(tester);
        expect(find.byType(WaterBottleLevel), findsOneWidget);
        expect(find.byType(WaterProgressRing), findsOneWidget);
      },
    );

    testWidgets(
      'View History is reachable as a link next to Today\'s Log, not only a bottom button',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await tester.binding.setSurfaceSize(const Size(402, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var historyTapped = false;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: WaterTrackerScreen(
                onViewHistory: () => historyTapped = true,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        final link = find.text('View History');
        expect(link, findsOneWidget);
        await tester.tap(link);
        expect(historyTapped, isTrue);
      },
    );

    test(
      'no mascot, achievements, or tip-card content was added — only the 9 approved sections',
      () {
        final content = File(
          'lib/water/screens/water_tracker_screen.dart',
        ).readAsStringSync();
        expect(
          content.contains('Achievements'),
          isFalse,
          reason:
              'gamification badges are not in the approved 9-section content list',
        );
        expect(
          content.contains('Did you know'),
          isFalse,
          reason:
              'the mascot tip card conflicts with the explicit "no mascots" rule',
        );
      },
    );
  });
}
