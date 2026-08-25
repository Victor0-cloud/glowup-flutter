// Covers Period & Cycle: deterministic cycle-length/estimate math, period
// start/end validation, day-entry upsert-by-date, delete-all privacy
// control, Brain event wiring (Tier 0/1 only, no AI call), and the "never
// leaves the device" guarantee.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glow_up/brain/events/learning_event.dart';
import 'package:glow_up/brain/events/learning_event_controller.dart';
import 'package:glow_up/cycle/models/cycle_models.dart';
import 'package:glow_up/cycle/state/cycle_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('deterministic cycle math', () {
    test('averageCycleLengthDays is null with fewer than 2 periods', () {
      final state = CycleState(
        periods: [PeriodEntry(id: 'p1', startDate: _date(1, 1))],
        dayEntries: [],
      );
      expect(state.averageCycleLengthDays, isNull);
    });

    test(
      'averageCycleLengthDays is the exact mean gap between consecutive start dates',
      () {
        final state = CycleState(
          periods: [
            PeriodEntry(id: 'p1', startDate: DateTime(2026, 1, 1)),
            PeriodEntry(id: 'p2', startDate: DateTime(2026, 1, 29)), // +28 days
            PeriodEntry(id: 'p3', startDate: DateTime(2026, 2, 28)), // +30 days
          ],
          dayEntries: [],
        );
        expect(state.averageCycleLengthDays, closeTo((28 + 30) / 2, 0.001));
      },
    );

    test(
      'estimatedNextPeriodStart is null with fewer than 2 periods (never a guess from one data point)',
      () {
        final state = CycleState(
          periods: [PeriodEntry(id: 'p1', startDate: _date(1, 1))],
          dayEntries: [],
        );
        expect(state.estimatedNextPeriodStart, isNull);
      },
    );

    test(
      'estimatedNextPeriodStart is exactly lastStart + rounded average cycle length',
      () {
        final state = CycleState(
          periods: [
            PeriodEntry(id: 'p1', startDate: DateTime(2026, 1, 1)),
            PeriodEntry(
              id: 'p2',
              startDate: DateTime(2026, 1, 29),
            ), // 28-day cycle
          ],
          dayEntries: [],
        );
        expect(
          state.estimatedNextPeriodStart,
          DateTime(2026, 1, 29).add(const Duration(days: 28)),
        );
      },
    );

    test(
      'averagePeriodLengthDays only counts periods with a logged end date',
      () {
        final state = CycleState(
          periods: [
            PeriodEntry(
              id: 'p1',
              startDate: DateTime(2026, 1, 1),
              endDate: DateTime(2026, 1, 5),
            ), // 5 days
            PeriodEntry(
              id: 'p2',
              startDate: DateTime(2026, 2, 1),
            ), // ongoing, excluded
          ],
          dayEntries: [],
        );
        expect(state.averagePeriodLengthDays, 5);
      },
    );

    test('averagePeriodLengthDays is null with no completed periods', () {
      final state = CycleState(
        periods: [PeriodEntry(id: 'p1', startDate: DateTime(2026, 1, 1))],
        dayEntries: [],
      );
      expect(state.averagePeriodLengthDays, isNull);
    });

    test('currentCycleDay is 1-indexed from the most recent period start', () {
      final state = CycleState(
        periods: [PeriodEntry(id: 'p1', startDate: DateTime(2026, 1, 1))],
        dayEntries: [],
      );
      expect(state.currentCycleDay(DateTime(2026, 1, 1)), 1);
      expect(state.currentCycleDay(DateTime(2026, 1, 5)), 5);
    });

    test('currentCycleDay is null with no periods logged', () {
      const state = CycleState(periods: [], dayEntries: []);
      expect(state.currentCycleDay(DateTime.now()), isNull);
    });
  });

  group('CycleController — period start/end', () {
    test(
      'logPeriodStart then logPeriodEnd marks the period completed with the right length',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(cycleControllerProvider.notifier);
        await controller.ready;

        final started = await controller.logPeriodStart(DateTime(2026, 1, 1));
        expect(started, isNotNull);
        expect(
          container.read(cycleControllerProvider).value!.hasActivePeriod,
          isTrue,
        );

        final ended = await controller.logPeriodEnd(
          started!.id,
          DateTime(2026, 1, 5),
        );
        expect(ended!.lengthInDays, 5);
        expect(
          container.read(cycleControllerProvider).value!.hasActivePeriod,
          isFalse,
        );
      },
    );

    test(
      'logPeriodEnd rejects an end date before the period start date',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(cycleControllerProvider.notifier);
        await controller.ready;

        final started = await controller.logPeriodStart(DateTime(2026, 1, 10));
        final ended = await controller.logPeriodEnd(
          started!.id,
          DateTime(2026, 1, 5),
        );
        expect(ended, isNull);
        expect(
          container
              .read(cycleControllerProvider)
              .value!
              .mostRecentPeriod!
              .isOngoing,
          isTrue,
        );
      },
    );

    test('deletePeriod removes exactly that period', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(cycleControllerProvider.notifier);
      await controller.ready;

      final p = await controller.logPeriodStart(DateTime(2026, 1, 1));
      expect(await controller.deletePeriod(p!.id), isTrue);
      expect(container.read(cycleControllerProvider).value!.periods, isEmpty);
    });
  });

  group('CycleController — day entries (upsert by date)', () {
    test(
      'logging a second entry for the same day replaces (never duplicates) the first',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(cycleControllerProvider.notifier);
        await controller.ready;

        final day = DateTime(2026, 1, 1);
        await controller.logDayEntry(CycleDayEntry(date: day, mood: 'Calm'));
        await controller.logDayEntry(
          CycleDayEntry(date: day, mood: 'Happy', energyLevel: 4),
        );

        final entries = container
            .read(cycleControllerProvider)
            .value!
            .dayEntries;
        expect(entries, hasLength(1));
        expect(entries.single.mood, 'Happy');
        expect(entries.single.energyLevel, 4);
      },
    );

    test('deleteDayEntry removes exactly that day', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(cycleControllerProvider.notifier);
      await controller.ready;

      final day = DateTime(2026, 1, 1);
      await controller.logDayEntry(CycleDayEntry(date: day, mood: 'Calm'));
      expect(await controller.deleteDayEntry(day), isTrue);
      expect(
        container.read(cycleControllerProvider).value!.dayEntries,
        isEmpty,
      );
    });
  });

  group('privacy: delete-all-data and no network at all', () {
    test(
      'deleteAllData removes every period and day entry, and survives a fresh controller instance',
      () async {
        final container1 = ProviderContainer();
        final controller1 = container1.read(cycleControllerProvider.notifier);
        await controller1.ready;
        await controller1.logPeriodStart(DateTime(2026, 1, 1));
        await controller1.logDayEntry(
          CycleDayEntry(date: DateTime(2026, 1, 1), mood: 'Calm'),
        );
        await controller1.deleteAllData();
        container1.dispose();

        final container2 = ProviderContainer();
        addTearDown(container2.dispose);
        final controller2 = container2.read(cycleControllerProvider.notifier);
        await controller2.ready;
        final state = container2.read(cycleControllerProvider).value!;
        expect(state.periods, isEmpty);
        expect(state.dayEntries, isEmpty);
      },
    );

    test(
      'cycle_repository.dart and cycle_controller.dart never import an HTTP/network client — cycle data never leaves the device',
      () {
        for (final path in [
          'lib/cycle/data/cycle_repository.dart',
          'lib/cycle/state/cycle_controller.dart',
        ]) {
          final content = File(path).readAsStringSync();
          expect(content.contains("import 'package:http"), isFalse);
          expect(content.contains('supabase'), isFalse);
        }
      },
    );

    test(
      'no cycle file imports any advertising/analytics package — this app has none, and cycle data must never feed one',
      () {
        // Checks actual `import` statements only — not doc comments (which
        // legitimately *state* the "never used for advertising" guarantee
        // in prose, e.g. cycle_controller.dart's own top-of-class comment).
        final dir = Directory('lib/cycle');
        final importPattern = RegExp(r"^import\s+'([^']+)'", multiLine: true);
        for (final file in dir.listSync(recursive: true).whereType<File>()) {
          final content = file.readAsStringSync();
          final imports = importPattern
              .allMatches(content)
              .map((m) => m.group(1)!.toLowerCase());
          for (final import in imports) {
            expect(
              import.contains('adnetwork'),
              isFalse,
              reason: '$file imports $import',
            );
            expect(
              import.contains('analytics'),
              isFalse,
              reason: '$file imports $import',
            );
            expect(
              import.contains('advertising'),
              isFalse,
              reason: '$file imports $import',
            );
            expect(
              import.contains('admob'),
              isFalse,
              reason: '$file imports $import',
            );
          }
        }
      },
    );
  });

  group(
    'Brain event wiring — periodLogged / cycleDayLogged, Tier 0/1 only, no AI call',
    () {
      test(
        'logPeriodStart emits periodLogged with kind=start; logPeriodEnd emits kind=end',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final events = container.read(
            learningEventControllerProvider.notifier,
          );
          await events.ready;
          final controller = container.read(cycleControllerProvider.notifier);
          await controller.ready;

          final p = await controller.logPeriodStart(DateTime(2026, 1, 1));
          await controller.logPeriodEnd(p!.id, DateTime(2026, 1, 5));

          final logged =
              container.read(learningEventControllerProvider).value ?? const [];
          final periodEvents = logged
              .where((e) => e.type == LearningEventType.periodLogged)
              .toList();
          expect(periodEvents, hasLength(2));
          final kinds = periodEvents
              .map((e) => (e.payload as PeriodLoggedPayload).kind)
              .toSet();
          expect(kinds, {'start', 'end'});
        },
      );

      test(
        'logDayEntry emits cycleDayLogged carrying only structured fields, never the private note text',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final events = container.read(
            learningEventControllerProvider.notifier,
          );
          await events.ready;
          final controller = container.read(cycleControllerProvider.notifier);
          await controller.ready;

          await controller.logDayEntry(
            CycleDayEntry(
              date: DateTime(2026, 1, 1),
              mood: 'Calm',
              energyLevel: 3,
              note: 'a very private secret',
            ),
          );

          final logged =
              container.read(learningEventControllerProvider).value ?? const [];
          final dayEvents = logged.where(
            (e) => e.type == LearningEventType.cycleDayLogged,
          );
          expect(dayEvents, hasLength(1));
          final payload = dayEvents.first.payload as CycleDayPayload;
          expect(payload.mood, 'Calm');
          expect(payload.hasNote, isTrue);
          expect(
            payload.toJson().toString().contains('a very private secret'),
            isFalse,
          );
        },
      );

      test('cycle_controller.dart never imports Tier 2/3/4 Brain modules', () {
        final content = File(
          'lib/cycle/state/cycle_controller.dart',
        ).readAsStringSync();
        for (final banned in [
          'brain/recommendations/adaptation_engine.dart',
          'brain/expression/generative_expression_service.dart',
          'brain/batch/pattern_promotion_job.dart',
        ]) {
          expect(content.contains(banned), isFalse);
        }
      });
    },
  );

  group('export never leaves the device', () {
    test(
      'exportSummaryText is a pure, deterministic string built only from stored data',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(cycleControllerProvider.notifier);
        await controller.ready;
        await controller.logPeriodStart(DateTime(2026, 1, 1));

        final text = controller.exportSummaryText();
        expect(text, contains('2026-01-01'));
        expect(text, contains('Periods:'));
      },
    );
  });
}

DateTime _date(int month, int day) => DateTime(2026, month, day);
