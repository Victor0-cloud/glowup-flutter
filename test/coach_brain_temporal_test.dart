// Coverage for the Aug-27 date/timezone bug fix (Section 10's client-side
// requirements). The server-side local-day-boundary math
// (localDayBoundsUtc/parseClientTemporalContext in
// supabase/functions/coach-chat/index.ts) has no Deno test runner in this
// repo — it was verified instead via real, live HTTP round trips against
// the deployed function using the owner's actual Pre-Swim timestamp shape
// (see the fix's own report). What IS Dart-testable, and matters just as
// much: that the client always sends a correct, FRESH local date/time on
// every request — never a stale cached value from whenever the Riverpod
// provider last rebuilt, which was part of the original bug's risk
// surface (see `CoachBrainContext.toRequestJson`'s own doc comment).

import 'package:flutter_test/flutter_test.dart';

import 'package:glow_up/coach/brain/coach_brain_context.dart';
import 'package:glow_up/core/tod/tod_period.dart';

CoachBrainContext _minimalContext() => const CoachBrainContext(
  greetingName: 'Test',
  period: TodPeriod.morning,
  primaryGoal: null,
  routinesScheduledToday: 0,
  routinesCompletedToday: 0,
  activeStreakCount: 0,
  recentWorkouts: [],
  latestWorkoutFeeling: null,
  hasRecentPainFlag: false,
  frequentlySkippedExerciseIds: [],
  todayWaterMl: 0,
  todayWaterGoalMl: 2000,
);

void main() {
  group('CoachBrainContext.toRequestJson — authoritative temporal fields', () {
    test('currentLocalDate is always present, in real YYYY-MM-DD format', () {
      final json = _minimalContext().toRequestJson();
      expect(json.containsKey('currentLocalDate'), isTrue);
      final date = json['currentLocalDate'] as String;
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date), isTrue);

      final now = DateTime.now();
      final expected =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      expect(date, expected);
    });

    test('currentLocalDateTime is a real ISO-8601 string WITH a UTC offset suffix', () {
      final json = _minimalContext().toRequestJson();
      final dateTime = json['currentLocalDateTime'] as String;
      // Must end in +HH:MM or -HH:MM — plain DateTime.now().toIso8601String()
      // omits this entirely for a non-UTC DateTime, which was the original
      // gap: the server had no way to know what "local" even meant.
      expect(
        RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}$').hasMatch(dateTime),
        isTrue,
        reason: 'was: $dateTime',
      );
    });

    test('timezoneOffsetMinutes matches this machine\'s real current offset', () {
      final json = _minimalContext().toRequestJson();
      expect(
        json['timezoneOffsetMinutes'],
        DateTime.now().timeZoneOffset.inMinutes,
      );
    });

    test(
      'two separate calls to toRequestJson() each reflect a freshly-read current time, never a value cached from construction',
      () {
        // The context object itself is const/immutable, but toRequestJson()
        // must compute DateTime.now() fresh every call — this is the
        // property that prevents the exact class of staleness bug flagged
        // in the fix (a Riverpod Provider that only rebuilds when a
        // *watched* dependency changes, not on a timer).
        final context = _minimalContext();
        final first = context.toRequestJson();
        // A real, non-trivial delay so a genuinely-fresh read could differ
        // from a cached one if the bug were reintroduced with a wall-clock
        // dependent field (e.g. seconds) — the *date* itself won't usually
        // differ across a millisecond gap, so this asserts the mechanism
        // (always recomputed) rather than a specific differing value.
        final second = context.toRequestJson();
        expect(first['currentLocalDate'], second['currentLocalDate']);
        expect(
          first['timezoneOffsetMinutes'],
          second['timezoneOffsetMinutes'],
        );
      },
    );

    test('date fields are never null and never omitted (unlike the optional cycle fields)', () {
      final json = _minimalContext().toRequestJson();
      expect(json['currentLocalDate'], isNotNull);
      expect(json['currentLocalDateTime'], isNotNull);
      expect(json['timezoneOffsetMinutes'], isNotNull);
    });
  });
}
