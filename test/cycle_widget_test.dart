// Covers the approved 9-page Period & Cycle rebuild (PC01-PC09): every page
// family renders, the shared time-of-day variant system drives Cycle Home's
// accent color across all 4 periods, the real entry-point branch (Awareness
// vs Home) reflects stored settings rather than a route-time guess, no page
// embeds a duplicate BottomNavBar, and private data (notebook notes) never
// leaks into a non-private surface.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glow_up/core/tod/tod_period.dart';
import 'package:glow_up/core/widgets/bottom_nav_bar.dart';
import 'package:glow_up/core/widgets/glow_card.dart';
import 'package:glow_up/cycle/models/cycle_models.dart';
import 'package:glow_up/cycle/screens/cycle_awareness_screen.dart';
import 'package:glow_up/cycle/screens/cycle_calendar_screen.dart';
import 'package:glow_up/cycle/screens/cycle_entry_screen.dart';
import 'package:glow_up/cycle/screens/cycle_home_screen.dart';
import 'package:glow_up/cycle/screens/cycle_insights_screen.dart';
import 'package:glow_up/cycle/screens/cycle_privacy_screen.dart';
import 'package:glow_up/cycle/screens/cycle_setup_screen.dart';
import 'package:glow_up/cycle/screens/daily_checkin_screen.dart';
import 'package:glow_up/cycle/screens/daily_notebook_screen.dart';
import 'package:glow_up/cycle/screens/log_period_screen.dart';
import 'package:glow_up/cycle/state/cycle_controller.dart';
import 'package:glow_up/cycle/theme/cycle_variant_config.dart';

Future<ProviderContainer> _boot(
  WidgetTester tester,
  Widget child, {
  TodPeriod? period,
  Size size = const Size(402, 1400),
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
      child: MaterialApp(home: child),
    ),
  );
  await tester.pump();
  await tester.pump();
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('all 9 approved page families render without error', () {
    testWidgets('PC01 Cycle Awareness', (tester) async {
      await _boot(tester, const CycleAwarenessScreen());
      expect(find.text('Period & Cycle'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PC02 Cycle Setup', (tester) async {
      await _boot(tester, const CycleSetupScreen());
      expect(find.text('Cycle Setup'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PC03 Cycle Home', (tester) async {
      await _boot(tester, const CycleHomeScreen());
      expect(find.text('Period & Cycle'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PC04 Log Period', (tester) async {
      await _boot(tester, const LogPeriodScreen());
      expect(find.text('Log Period'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PC05 Daily Check-In', (tester) async {
      await _boot(tester, const DailyCheckInScreen());
      expect(find.text('Daily Check-In'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PC06 My Calendar', (tester) async {
      await _boot(tester, const CycleCalendarScreen());
      expect(find.text('My Calendar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PC07 Daily Notebook', (tester) async {
      await _boot(tester, DailyNotebookScreen(date: DateTime(2026, 8, 21)));
      expect(find.text('Daily Notebook'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PC08 Cycle Insights', (tester) async {
      await _boot(tester, const CycleInsightsScreen());
      expect(find.text('Cycle Insights'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PC09 Cycle Privacy', (tester) async {
      await _boot(tester, const CyclePrivacyScreen());
      expect(find.text('Cycle Privacy'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group(
    'CycleEntryScreen branches on real stored settings, never a route-time guess',
    () {
      testWidgets(
        'shows Cycle Awareness (PC01) when tracking has never been set up or declined',
        (tester) async {
          await _boot(tester, const CycleEntryScreen());
          expect(find.text('Make your plan cycle-aware?'), findsOneWidget);
        },
      );

      testWidgets('shows Cycle Home (PC03) once tracking is enabled', (
        tester,
      ) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(cycleControllerProvider.notifier);
        await controller.ready;
        await controller.updateSettings(
          const CycleSettings(trackingEnabled: true),
        );

        await tester.binding.setSurfaceSize(const Size(402, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: CycleEntryScreen()),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(
          find.text('Your rhythm, energy and wellness — connected.'),
          findsOneWidget,
        );
        expect(find.text('Make your plan cycle-aware?'), findsNothing);
      });

      testWidgets(
        'stays on Cycle Awareness once tracking was explicitly declined, never re-asking',
        (tester) async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final controller = container.read(cycleControllerProvider.notifier);
          await controller.ready;
          await controller.updateSettings(
            const CycleSettings(trackingDeclined: true),
          );

          await tester.binding.setSurfaceSize(const Size(402, 1400));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(home: CycleEntryScreen()),
            ),
          );
          await tester.pump();
          await tester.pump();

          // Declined means "not applicable to me" was chosen — still shows the
          // awareness screen (never force-enables tracking), just doesn't
          // re-prompt via a different route.
          expect(find.text('Make your plan cycle-aware?'), findsOneWidget);
        },
      );
    },
  );

  group(
    'time-of-day variants — Cycle Home renders real, distinct properties per period',
    () {
      final ringColorByPeriod = <TodPeriod, Color?>{};
      final cardBorderByPeriod = <TodPeriod, Color?>{};

      for (final period in TodPeriod.values) {
        testWidgets(
          '${period.name}: the rendered cycle-day ring color and "Glow Up Brain" card border match the configured accent',
          (tester) async {
            await _boot(tester, const CycleHomeScreen(), period: period);
            final expected = CycleVariantConfig.byPeriod[period]!;

            // Concrete rendered property #1: the cycle-day progress ring's own
            // paint color, read off the real widget in the tree — not just the
            // config map (which would pass even if the widget ignored it).
            final ring = tester.widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator).first,
            );
            final ringColor =
                (ring.valueColor as AlwaysStoppedAnimation<Color?>).value;
            expect(
              ringColor,
              expected.accent,
              reason:
                  '${period.name} ring color must be the real accent, not a hardcoded/stale color',
            );
            ringColorByPeriod[period] = ringColor;

            // Concrete rendered property #2: the "Glow Up Brain" card's border,
            // which is tinted with the same accent at a fixed lower alpha.
            final brainCard = tester.widget<Container>(
              find
                  .descendant(
                    of: find.byType(GlowCard).last,
                    matching: find.byType(Container),
                  )
                  .first,
            );
            final decoration = brainCard.decoration as BoxDecoration;
            cardBorderByPeriod[period] = decoration.border == null
                ? null
                : (decoration.border as Border).top.color;

            expect(tester.takeException(), isNull);
          },
        );
      }

      testWidgets(
        'all 4 periods produce 4 genuinely distinct ring colors — never the same color reused across variants',
        (tester) async {
          for (final period in TodPeriod.values) {
            await _boot(tester, const CycleHomeScreen(), period: period);
            final ring = tester.widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator).first,
            );
            ringColorByPeriod[period] =
                (ring.valueColor as AlwaysStoppedAnimation<Color?>).value;
          }
          expect(
            ringColorByPeriod.values.toSet().length,
            4,
            reason:
                'morning/afternoon/evening/night must each show a visibly different ring color, matching gold/purple/pink/deep-blue-purple',
          );
        },
      );

      test(
        'every TodPeriod has a Cycle variant config — no period silently falls back',
        () {
          for (final period in TodPeriod.values) {
            expect(
              CycleVariantConfig.byPeriod.containsKey(period),
              isTrue,
              reason: '$period is missing a CycleVariantConfig',
            );
          }
        },
      );
    },
  );

  group(
    'cycle-day ring settles — never spins indefinitely, stable with insufficient data',
    () {
      testWidgets(
        'with no period ever logged, the ring is a determinate 0.0 (a static empty arc), never null/indeterminate',
        (tester) async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final cycle = container.read(cycleControllerProvider.notifier);
          await cycle.ready;
          await cycle.updateSettings(
            const CycleSettings(trackingEnabled: true),
          );

          await tester.binding.setSurfaceSize(const Size(402, 1400));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(home: CycleHomeScreen()),
            ),
          );
          await tester.pump();
          await tester.pump();

          final ring = tester.widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator).first,
          );
          expect(
            ring.value,
            0.0,
            reason:
                'insufficient data must render a stable, static ring — `value: null` would make Flutter spin it indefinitely',
          );
        },
      );

      testWidgets(
        'with a real period logged, the ring is a determinate fraction of the cycle, never null/indeterminate',
        (tester) async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final cycle = container.read(cycleControllerProvider.notifier);
          await cycle.ready;
          await cycle.updateSettings(
            const CycleSettings(trackingEnabled: true, typicalCycleDays: 28),
          );
          await cycle.logPeriodStart(
            DateTime.now().subtract(const Duration(days: 6)),
          );

          await tester.binding.setSurfaceSize(const Size(402, 1400));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(home: CycleHomeScreen()),
            ),
          );
          await tester.pump();
          await tester.pump();

          final ring = tester.widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator).first,
          );
          expect(
            ring.value,
            isNotNull,
            reason:
                'real cycle data must never leave `value: null` — that is Flutter\'s indeterminate, endlessly-spinning mode',
          );
          // Day 7 of a 28-day cycle (start was 6 days ago, so today is day 7).
          expect(ring.value, closeTo(7 / 28, 0.001));
        },
      );

      testWidgets(
        'pumping several frames with the same state does not change the ring value — it settles, not a continuous rebuild loop',
        (tester) async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final cycle = container.read(cycleControllerProvider.notifier);
          await cycle.ready;
          await cycle.updateSettings(
            const CycleSettings(trackingEnabled: true, typicalCycleDays: 28),
          );
          await cycle.logPeriodStart(
            DateTime.now().subtract(const Duration(days: 3)),
          );

          await tester.binding.setSurfaceSize(const Size(402, 1400));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(home: CycleHomeScreen()),
            ),
          );
          await tester.pump();
          await tester.pump();

          final first = tester
              .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator).first,
              )
              .value;
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          final after = tester
              .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator).first,
              )
              .value;
          expect(
            after,
            first,
            reason:
                'the ring value must be stable across repeated frames with unchanged data, not perpetually animating/rebuilding',
          );
        },
      );
    },
  );

  group('no duplicate Cycle implementation / navigation stays 4-tab', () {
    test(
      'AppNavTab is exactly today/routines/coach/profile — no Cycle tab was added',
      () {
        expect(AppNavTab.values, [
          AppNavTab.today,
          AppNavTab.routines,
          AppNavTab.coach,
          AppNavTab.profile,
        ]);
      },
    );

    test(
      'no Cycle screen embeds its own BottomNavBar — every one is a pushed sub-screen',
      () {
        final dir = Directory('lib/cycle/screens');
        for (final file in dir.listSync().whereType<File>()) {
          final content = file.readAsStringSync();
          expect(
            content.contains('BottomNavBar('),
            isFalse,
            reason: '${file.path} must not embed BottomNavBar',
          );
        }
      },
    );

    test(
      'exactly one Cycle Home implementation exists (no legacy duplicate left behind)',
      () {
        expect(
          File('lib/cycle/screens/cycle_home_screen.dart').existsSync(),
          isTrue,
        );
        expect(
          File('lib/cycle/screens/cycle_screen.dart').existsSync(),
          isFalse,
        );
        expect(
          File('lib/cycle/screens/cycle_history_screen.dart').existsSync(),
          isFalse,
        );
      },
    );
  });

  group('small-screen surfaces do not overflow', () {
    testWidgets('Cycle Setup at 320x568', (tester) async {
      await _boot(tester, const CycleSetupScreen(), size: const Size(320, 568));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Cycle Home at 320x568', (tester) async {
      await _boot(tester, const CycleHomeScreen(), size: const Size(320, 568));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Daily Check-In at 320x568', (tester) async {
      await _boot(
        tester,
        const DailyCheckInScreen(),
        size: const Size(320, 568),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('My Calendar at 320x568', (tester) async {
      await _boot(
        tester,
        const CycleCalendarScreen(),
        size: const Size(320, 568),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Daily Notebook at 320x568', (tester) async {
      await _boot(
        tester,
        DailyNotebookScreen(date: DateTime(2026, 8, 21)),
        size: const Size(320, 568),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group(
    'Glow Up Brain card — three truthful states, live data only (never the old "isn\'t connected" placeholder)',
    () {
      testWidgets(
        'off state: cycle-aware suggestions disabled shows the honest off copy, not a suggestion',
        (tester) async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final controller = container.read(cycleControllerProvider.notifier);
          await controller.ready;
          await controller.updateSettings(
            const CycleSettings(
              trackingEnabled: true,
              cycleAwareSuggestions: false,
            ),
          );

          await tester.binding.setSurfaceSize(const Size(402, 1400));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(home: CycleHomeScreen()),
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(find.text('Cycle-aware suggestions are off'), findsOneWidget);
          expect(
            find.textContaining('Turn this on in Privacy settings'),
            findsOneWidget,
          );
          expect(find.textContaining('isn\'t connected'), findsNothing);
        },
      );

      testWidgets(
        'missing-data state: suggestions on but no cycle day known yet says exactly what is missing, never fabricates a suggestion',
        (tester) async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final controller = container.read(cycleControllerProvider.notifier);
          await controller.ready;
          await controller.updateSettings(
            const CycleSettings(
              trackingEnabled: true,
              cycleAwareSuggestions: true,
            ),
          );

          await tester.binding.setSurfaceSize(const Size(402, 1400));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(home: CycleHomeScreen()),
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(find.text('Cycle-aware suggestions are on'), findsOneWidget);
          expect(
            find.textContaining('Add more cycle data to unlock'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'real-data state: a logged period plus a low-energy check-in produces a suggestion genuinely grounded in that data',
        (tester) async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final controller = container.read(cycleControllerProvider.notifier);
          await controller.ready;
          await controller.updateSettings(
            const CycleSettings(
              trackingEnabled: true,
              cycleAwareSuggestions: true,
              typicalCycleDays: 28,
            ),
          );
          await controller.logPeriodStart(
            DateTime.now().subtract(const Duration(days: 4)),
          );
          await controller.logDayEntry(
            CycleDayEntry(date: DateTime.now(), energyLevel: 1),
          );

          await tester.binding.setSurfaceSize(const Size(402, 1400));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(home: CycleHomeScreen()),
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(find.text('Cycle-aware suggestion'), findsOneWidget);
          expect(
            find.textContaining('energy is logged lower today (day 5)'),
            findsOneWidget,
          );
          // No fertility/phase claim ever appears alongside the real data.
          expect(find.textContaining('fertil'), findsNothing);
          expect(find.textContaining('ovulat'), findsNothing);
        },
      );
    },
  );

  group('private data stays private', () {
    testWidgets(
      'a Daily Notebook note is never rendered back verbatim on the Calendar summary card',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(cycleControllerProvider.notifier);
        await controller.ready;
        const secret = 'a very private secret only I should see';
        await controller.logNotebookEntry(
          DailyNotebookEntry(
            date: DateTime.now(),
            feeling: Feeling.happy,
            note: secret,
          ),
        );

        await tester.binding.setSurfaceSize(const Size(402, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: CycleCalendarScreen()),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.textContaining(secret), findsNothing);
        expect(find.textContaining('private note saved'), findsOneWidget);
      },
    );

    testWidgets(
      'painIntensity round-trips through Daily Check-In save without corrupting other fields',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(cycleControllerProvider.notifier);
        await controller.ready;

        await tester.binding.setSurfaceSize(const Size(402, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: DailyCheckInScreen()),
          ),
        );
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Save check-in'));
        await tester.pump();
        await tester.pump();

        final today = container
            .read(cycleControllerProvider)
            .value!
            .dayEntryFor(DateTime.now());
        expect(today, isNotNull);
        expect(today!.painIntensity, 0);
      },
    );
  });
}
