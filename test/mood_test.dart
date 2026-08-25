// Covers Mood Check-In: deterministic average/best-day/common-reason math,
// day-entry upsert-by-date, Brain event wiring (Tier 0/1 only, no AI call),
// and the "never leaves the device" guarantee.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glow_up/brain/events/learning_event.dart';
import 'package:glow_up/brain/events/learning_event_controller.dart';
import 'package:glow_up/brain/state/current_state_controller.dart';
import 'package:glow_up/mood/models/mood_models.dart';
import 'package:glow_up/mood/state/mood_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('MoodLevel', () {
    test('score is a fixed 1-5 mapping, amazing highest', () {
      expect(MoodLevel.terrible.score, 1);
      expect(MoodLevel.notGreat.score, 2);
      expect(MoodLevel.okay.score, 3);
      expect(MoodLevel.good.score, 4);
      expect(MoodLevel.amazing.score, 5);
    });

    test('every MoodLevel has a display entry in kMoodLevelDisplayOrder', () {
      expect(kMoodLevelDisplayOrder.toSet(), MoodLevel.values.toSet());
    });
  });

  group('MoodController — day entries (upsert by date)', () {
    test(
      'checking in twice the same day edits (never duplicates) the entry',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(moodControllerProvider.notifier);
        await controller.ready;

        await controller.logCheckIn(level: MoodLevel.okay);
        await controller.logCheckIn(
          level: MoodLevel.amazing,
          reasons: {'Grateful'},
        );

        final entries = container.read(moodControllerProvider).value!.entries;
        expect(entries, hasLength(1));
        expect(entries.single.level, MoodLevel.amazing);
        expect(entries.single.reasons, {'Grateful'});
      },
    );

    test(
      'a fresh controller instance reloads exactly what was saved',
      () async {
        final container1 = ProviderContainer();
        final controller1 = container1.read(moodControllerProvider.notifier);
        await controller1.ready;
        await controller1.logCheckIn(
          level: MoodLevel.good,
          energyLevel: 4,
          stressLevel: 2,
        );
        // logCheckIn's Brain event emission lazily constructs
        // CurrentStateController, whose own _init() keeps running in the
        // background after setEntry's early-return (repo not ready yet) —
        // wait for it before disposing so it never touches a disposed
        // notifier.
        await container1.read(currentStateControllerProvider.notifier).ready;
        container1.dispose();

        final container2 = ProviderContainer();
        addTearDown(container2.dispose);
        final controller2 = container2.read(moodControllerProvider.notifier);
        await controller2.ready;
        final state = container2.read(moodControllerProvider).value!;
        expect(state.entries, hasLength(1));
        expect(state.entries.single.level, MoodLevel.good);
        expect(state.entries.single.energyLevel, 4);
        expect(state.entries.single.stressLevel, 2);
      },
    );
  });

  group('deterministic mood math', () {
    test('averageScoreInLastDays is null with no entries in the window', () {
      const state = MoodState(entries: []);
      expect(state.averageScoreInLastDays(7), isNull);
    });

    test('averageScoreInLastDays is the exact mean of scores in range', () {
      final today = DateTime.now();
      final state = MoodState(
        entries: [
          MoodEntry(date: today, level: MoodLevel.amazing), // 5
          MoodEntry(
            date: today.subtract(const Duration(days: 1)),
            level: MoodLevel.okay,
          ), // 3
        ],
      );
      expect(state.averageScoreInLastDays(7), closeTo(4.0, 0.001));
    });

    test('bestDayInLastDays is the highest-scoring entry in range', () {
      final today = DateTime.now();
      final state = MoodState(
        entries: [
          MoodEntry(date: today, level: MoodLevel.okay),
          MoodEntry(
            date: today.subtract(const Duration(days: 1)),
            level: MoodLevel.amazing,
          ),
        ],
      );
      expect(state.bestDayInLastDays(7)!.level, MoodLevel.amazing);
    });

    test('mostCommonReasonInLastDays is the most frequently selected tag', () {
      final today = DateTime.now();
      final state = MoodState(
        entries: [
          MoodEntry(date: today, level: MoodLevel.good, reasons: {'Tired'}),
          MoodEntry(
            date: today.subtract(const Duration(days: 1)),
            level: MoodLevel.good,
            reasons: {'Tired', 'Stressed'},
          ),
        ],
      );
      expect(state.mostCommonReasonInLastDays(7), 'Tired');
    });

    test(
      'mostCommonReasonInLastDays is null when no entry recorded a reason',
      () {
        final state = MoodState(
          entries: [MoodEntry(date: DateTime.now(), level: MoodLevel.okay)],
        );
        expect(state.mostCommonReasonInLastDays(7), isNull);
      },
    );

    test('inLastDays excludes entries outside the window', () {
      final today = DateTime.now();
      final state = MoodState(
        entries: [
          MoodEntry(date: today, level: MoodLevel.okay),
          MoodEntry(
            date: today.subtract(const Duration(days: 10)),
            level: MoodLevel.terrible,
          ),
        ],
      );
      expect(state.inLastDays(7), hasLength(1));
      expect(state.inLastDays(7).single.level, MoodLevel.okay);
    });
  });

  group('privacy: no network at all', () {
    test(
      'mood_repository.dart and mood_controller.dart never import an HTTP/network client',
      () {
        for (final path in [
          'lib/mood/data/mood_repository.dart',
          'lib/mood/state/mood_controller.dart',
        ]) {
          final content = File(path).readAsStringSync();
          expect(content.contains("import 'package:http"), isFalse);
          expect(content.contains('supabase'), isFalse);
        }
      },
    );
  });

  group('Brain event wiring — moodCheckedIn, Tier 0/1 only, no AI call', () {
    test(
      'logCheckIn emits moodCheckedIn carrying only structured fields, never the private note text',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final events = container.read(learningEventControllerProvider.notifier);
        await events.ready;
        final controller = container.read(moodControllerProvider.notifier);
        await controller.ready;

        await controller.logCheckIn(
          level: MoodLevel.good,
          reasons: {'Calm'},
          energyLevel: 3,
          note: 'a very private secret',
        );

        final logged =
            container.read(learningEventControllerProvider).value ?? const [];
        final moodEvents = logged.where(
          (e) => e.type == LearningEventType.moodCheckedIn,
        );
        expect(moodEvents, hasLength(1));
        final payload = moodEvents.first.payload as MoodCheckInPayload;
        expect(payload.level, 'good');
        expect(payload.reasons, ['Calm']);
        expect(payload.hasNote, isTrue);
        expect(
          payload.toJson().toString().contains('a very private secret'),
          isFalse,
        );
      },
    );

    test('mood_controller.dart never imports Tier 2/3/4 Brain modules', () {
      final content = File(
        'lib/mood/state/mood_controller.dart',
      ).readAsStringSync();
      for (final banned in [
        'brain/recommendations/adaptation_engine.dart',
        'brain/expression/generative_expression_service.dart',
        'brain/batch/pattern_promotion_job.dart',
      ]) {
        expect(content.contains(banned), isFalse);
      }
    });
  });
}
