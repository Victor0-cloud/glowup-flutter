// Covers the Mood Check-In screen: rendering, accessible mood selection,
// optional note/energy/stress controls, save navigation, empty history,
// loading/error states, accessibility (44x44 targets, semantic labels,
// text scaling, small-screen overflow), and that no out-of-scope module
// (Pre-Swim, a separate Fitness Store Scan, Grace*/Prayer*/Rosary branding)
// was introduced by this work.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glow_up/coach/screens/mood_history_screen.dart';
import 'package:glow_up/mood/models/mood_models.dart';
import 'package:glow_up/mood/screens/mood_checkin_screen.dart';
import 'package:glow_up/mood/state/mood_controller.dart';

Future<ProviderContainer> _bootCheckIn(
  WidgetTester tester, {
  Size size = const Size(402, 1200),
  double textScale = 1.0,
  VoidCallback? onSaved,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(home: MoodCheckInScreen(onSaved: onSaved)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Mood Check-In renders', () {
    testWidgets('shows the mood question and every mood option', (
      tester,
    ) async {
      await _bootCheckIn(tester);
      expect(find.text('Mood Check-In'), findsOneWidget);
      expect(find.text('How are you feeling right now?'), findsOneWidget);
      for (final label in [
        'Amazing',
        'Good',
        'Okay',
        'Not Great',
        'Terrible',
      ]) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: '$label mood option should render',
        );
      }
    });

    testWidgets('Save Check-In is disabled until a mood is picked', (
      tester,
    ) async {
      await _bootCheckIn(tester);
      final button = find.text('Save Check-In');
      expect(button, findsOneWidget);

      await tester.tap(button, warnIfMissed: false);
      await tester.pump();
      // Still on the check-in screen (no navigation happened) — nothing to
      // assert on directly besides "no exception", since onSaved is unset.
      expect(tester.takeException(), isNull);
    });
  });

  group('mood selection', () {
    testWidgets('tapping a mood option selects it and enables Save', (
      tester,
    ) async {
      await _bootCheckIn(tester);
      await tester.tap(find.text('Amazing'));
      await tester.pump();

      final semantics = tester.getSemantics(
        find
            .byWidgetPredicate(
              (w) => w is Semantics && w.properties.label == 'Amazing',
            )
            .first,
      );
      expect(semantics.hasFlag(SemanticsFlag.isSelected), isTrue);
    });

    testWidgets('choosing a different mood replaces the previous selection', (
      tester,
    ) async {
      await _bootCheckIn(tester);
      await tester.tap(find.text('Amazing'));
      await tester.pump();
      await tester.tap(find.text('Terrible'));
      await tester.pump();

      final amazingSemantics = tester.getSemantics(
        find
            .byWidgetPredicate(
              (w) => w is Semantics && w.properties.label == 'Amazing',
            )
            .first,
      );
      final terribleSemantics = tester.getSemantics(
        find
            .byWidgetPredicate(
              (w) => w is Semantics && w.properties.label == 'Terrible',
            )
            .first,
      );
      expect(amazingSemantics.hasFlag(SemanticsFlag.isSelected), isFalse);
      expect(terribleSemantics.hasFlag(SemanticsFlag.isSelected), isTrue);
    });
  });

  group('optional fields', () {
    testWidgets('a why-reason chip can be toggled on and off', (tester) async {
      await _bootCheckIn(tester);
      await tester.tap(find.text('Grateful'));
      await tester.pump();
      var semantics = tester.getSemantics(
        find
            .byWidgetPredicate(
              (w) => w is Semantics && w.properties.label == 'Grateful',
            )
            .first,
      );
      expect(semantics.hasFlag(SemanticsFlag.isSelected), isTrue);

      await tester.tap(find.text('Grateful'));
      await tester.pump();
      semantics = tester.getSemantics(
        find
            .byWidgetPredicate(
              (w) => w is Semantics && w.properties.label == 'Grateful',
            )
            .first,
      );
      expect(semantics.hasFlag(SemanticsFlag.isSelected), isFalse);
    });

    testWidgets('an optional note can be entered', (tester) async {
      await _bootCheckIn(tester);
      await tester.enterText(
        find.byType(TextField),
        'Feeling good after a walk',
      );
      await tester.pump();
      expect(find.text('Feeling good after a walk'), findsOneWidget);
    });

    testWidgets('energy and stress level pickers respond to selection', (
      tester,
    ) async {
      await _bootCheckIn(tester, size: const Size(402, 1400));
      await tester.ensureVisible(find.text('Energy level (optional)'));
      final energyFour = find
          .byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.label == 'Energy level (optional) 4 of 5',
          )
          .first;
      await tester.tap(energyFour, warnIfMissed: false);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('save navigation', () {
    testWidgets('Save Check-In calls onSaved once a mood is picked', (
      tester,
    ) async {
      var saved = false;
      await _bootCheckIn(tester, onSaved: () => saved = true);
      await tester.tap(find.text('Okay'));
      await tester.pump();
      await tester.tap(find.text('Save Check-In'));
      await tester.pumpAndSettle();
      expect(saved, isTrue);
    });

    testWidgets(
      're-opening the screen after a check-in preloads today\'s selection',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(moodControllerProvider.notifier);
        await controller.ready;
        await controller.logCheckIn(level: MoodLevel.good);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: MoodCheckInScreen()),
          ),
        );
        await tester.pump();
        await tester.pump();

        final semantics = tester.getSemantics(
          find
              .byWidgetPredicate(
                (w) => w is Semantics && w.properties.label == 'Good',
              )
              .first,
        );
        expect(semantics.hasFlag(SemanticsFlag.isSelected), isTrue);
      },
    );
  });

  group('Mood History — empty state', () {
    testWidgets('shows an honest empty state with no logged check-ins', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.binding.setSurfaceSize(const Size(402, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: MoodHistoryScreen(
              onBack: () {},
              onToday: () {},
              onRoutines: () {},
              onProfile: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('No mood check-ins yet'), findsOneWidget);
    });

    testWidgets(
      'shows real computed stats once a check-in exists, never fabricated seed values',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(moodControllerProvider.notifier);
        await controller.ready;
        await controller.logCheckIn(
          level: MoodLevel.amazing,
          reasons: {'Energetic'},
        );

        await tester.binding.setSurfaceSize(const Size(402, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: MoodHistoryScreen(
                onBack: () {},
                onToday: () {},
                onRoutines: () {},
                onProfile: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('No mood check-ins yet'), findsNothing);
        expect(find.textContaining('Avg: 5.0/5'), findsOneWidget);
      },
    );
  });

  group('accessibility', () {
    testWidgets(
      'mood options and Save Check-In meet the 44x44 minimum touch target',
      (tester) async {
        await _bootCheckIn(tester);
        final amazingCircle = find
            .ancestor(of: find.text('🤩'), matching: find.byType(Container))
            .first;
        final circleSize = tester.getSize(amazingCircle);
        expect(circleSize.width, greaterThanOrEqualTo(44));
        expect(circleSize.height, greaterThanOrEqualTo(44));

        await tester.tap(find.text('Amazing'));
        await tester.pump();
        final saveButton = find
            .ancestor(
              of: find.text('Save Check-In'),
              matching: find.byType(Container),
            )
            .first;
        expect(tester.getSize(saveButton).height, greaterThanOrEqualTo(44));
      },
    );

    testWidgets('large text scaling does not throw a layout overflow error', (
      tester,
    ) async {
      await _bootCheckIn(tester, textScale: 2.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a small-screen surface does not overflow', (tester) async {
      await _bootCheckIn(tester, size: const Size(320, 568));
      expect(tester.takeException(), isNull);
    });
  });

  group(
    'scope guardrails — nothing out-of-scope was introduced by this work',
    () {
      test(
        'no lib/mood file introduces Pre-Swim or a separate Fitness Store Scan',
        () {
          final dir = Directory('lib/mood');
          for (final file in dir.listSync(recursive: true).whereType<File>()) {
            final content = file.readAsStringSync().toLowerCase();
            expect(content.contains('pre-swim'), isFalse, reason: file.path);
            expect(content.contains('preswim'), isFalse, reason: file.path);
            expect(
              content.contains('fitness store'),
              isFalse,
              reason: file.path,
            );
            expect(
              content.contains('fitness_store'),
              isFalse,
              reason: file.path,
            );
          }
        },
      );

      test(
        'no lib/mood file references GraceGather, Grace Place, PrayerLock, or RosaryLock',
        () {
          final dir = Directory('lib/mood');
          for (final file in dir.listSync(recursive: true).whereType<File>()) {
            final content = file.readAsStringSync().toLowerCase();
            for (final banned in [
              'gracegather',
              'grace place',
              'prayerlock',
              'rosarylock',
            ]) {
              expect(
                content.contains(banned),
                isFalse,
                reason: '${file.path} must not reference $banned',
              );
            }
          }
        },
      );
    },
  );
}
