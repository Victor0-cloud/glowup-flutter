import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/tod/tod_period.dart';
import '../models/routine_models.dart';

const _weekdays = {
  Weekday.monday,
  Weekday.tuesday,
  Weekday.wednesday,
  Weekday.thursday,
  Weekday.friday,
};

/// Seed routines, one-to-one with the cards shown on 22a-22d (368:1618,
/// 1697, 1776, 1855). Only "Morning Wellness" has its steps specified by
/// Figma (368:1956's detail frame) — the other 11 routines' step lists
/// aren't detailed anywhere in the approved file, so their steps are
/// reasonable placeholders consistent with each routine's name and the
/// step-count Figma *does* show on its hub card, not invented from
/// nothing. Streak counts, times, and step counts all come straight from
/// the hub cards.
List<Routine> _seedRoutines() => [
  Routine(
    id: 'morning-wellness',
    title: 'Morning Wellness',
    subtitle: 'Kickstart your morning glow',
    emoji: '🧘‍♀️',
    theme: RoutineColorTheme.gold,
    period: TodPeriod.morning,
    schedule: const RoutineSchedule(
      days: _weekdays,
      time: TimeOfDay(hour: 6, minute: 30),
    ),
    streakDays: 12,
    activities: const [
      RoutineActivity(
        id: 'mw-1',
        emoji: '💧',
        title: 'Drink Water',
        durationMinutes: 2,
      ),
      RoutineActivity(
        id: 'mw-2',
        emoji: '🧘‍♀️',
        title: 'Stretch',
        durationMinutes: 5,
      ),
      RoutineActivity(
        id: 'mw-3',
        emoji: '🧠',
        title: 'Meditation',
        durationMinutes: 10,
      ),
      RoutineActivity(
        id: 'mw-4',
        emoji: '✨',
        title: 'Skincare',
        durationMinutes: 5,
      ),
      RoutineActivity(
        id: 'mw-5',
        emoji: '📝',
        title: 'Plan Day',
        durationMinutes: 3,
      ),
    ],
  ),
  Routine(
    id: 'quick-stretch',
    title: 'Quick Stretch',
    subtitle: 'A short reset to start moving',
    emoji: '🤸',
    theme: RoutineColorTheme.gold,
    period: TodPeriod.morning,
    schedule: const RoutineSchedule(
      days: _weekdays,
      time: TimeOfDay(hour: 7, minute: 0),
    ),
    activities: const [
      RoutineActivity(
        id: 'qs-1',
        emoji: '🤸',
        title: 'Full Body Stretch',
        durationMinutes: 2,
      ),
      RoutineActivity(
        id: 'qs-2',
        emoji: '🫁',
        title: 'Deep Breaths',
        durationMinutes: 1,
      ),
      RoutineActivity(
        id: 'qs-3',
        emoji: '💪',
        title: 'Shoulder Rolls',
        durationMinutes: 1,
      ),
    ],
  ),
  Routine(
    id: 'mindful-start',
    title: 'Mindful Start',
    subtitle: 'Center yourself before the day',
    emoji: '🧠',
    theme: RoutineColorTheme.gold,
    period: TodPeriod.morning,
    schedule: const RoutineSchedule(
      days: _weekdays,
      time: TimeOfDay(hour: 7, minute: 30),
    ),
    activities: const [
      RoutineActivity(
        id: 'ms-1',
        emoji: '🧠',
        title: 'Breathing Exercise',
        durationMinutes: 3,
      ),
      RoutineActivity(
        id: 'ms-2',
        emoji: '📝',
        title: 'Set Intentions',
        durationMinutes: 2,
      ),
      RoutineActivity(
        id: 'ms-3',
        emoji: '☕',
        title: 'Mindful Coffee',
        durationMinutes: 3,
      ),
      RoutineActivity(
        id: 'ms-4',
        emoji: '🎵',
        title: 'Calm Music',
        durationMinutes: 2,
      ),
    ],
  ),
  Routine(
    id: 'midday-reset',
    title: 'Midday Reset',
    subtitle: 'Refresh your energy for the afternoon',
    emoji: '⚡',
    theme: RoutineColorTheme.lavender,
    period: TodPeriod.afternoon,
    schedule: const RoutineSchedule(
      days: _weekdays,
      time: TimeOfDay(hour: 12, minute: 30),
    ),
    streakDays: 8,
    activities: const [
      RoutineActivity(
        id: 'mr-1',
        emoji: '🥗',
        title: 'Mindful Lunch',
        durationMinutes: 15,
      ),
      RoutineActivity(
        id: 'mr-2',
        emoji: '🚶',
        title: 'Short Walk',
        durationMinutes: 10,
      ),
      RoutineActivity(
        id: 'mr-3',
        emoji: '💧',
        title: 'Hydrate',
        durationMinutes: 1,
      ),
      RoutineActivity(
        id: 'mr-4',
        emoji: '🫁',
        title: 'Reset Breathing',
        durationMinutes: 2,
      ),
    ],
  ),
  Routine(
    id: 'power-walk',
    title: 'Power Walk',
    subtitle: 'Get your steps and sunlight in',
    emoji: '🚶',
    theme: RoutineColorTheme.lavender,
    period: TodPeriod.afternoon,
    schedule: const RoutineSchedule(
      days: _weekdays,
      time: TimeOfDay(hour: 13, minute: 0),
    ),
    activities: const [
      RoutineActivity(
        id: 'pw-1',
        emoji: '🚶',
        title: 'Brisk Walk',
        durationMinutes: 15,
      ),
      RoutineActivity(
        id: 'pw-2',
        emoji: '🎵',
        title: 'Energizing Playlist',
        durationMinutes: 1,
      ),
      RoutineActivity(
        id: 'pw-3',
        emoji: '💧',
        title: 'Water Break',
        durationMinutes: 1,
      ),
    ],
  ),
  Routine(
    id: 'hydration-check',
    title: 'Hydration Check',
    subtitle: 'A quick reminder to drink up',
    emoji: '💧',
    theme: RoutineColorTheme.lavender,
    period: TodPeriod.afternoon,
    schedule: const RoutineSchedule(
      days: _weekdays,
      time: TimeOfDay(hour: 14, minute: 0),
    ),
    activities: const [
      RoutineActivity(
        id: 'hc-1',
        emoji: '💧',
        title: 'Drink a Glass',
        durationMinutes: 1,
      ),
      RoutineActivity(
        id: 'hc-2',
        emoji: '📝',
        title: 'Log Intake',
        durationMinutes: 1,
      ),
    ],
  ),
  Routine(
    id: 'evening-wind-down',
    title: 'Evening Wind Down',
    subtitle: 'Ease into a calmer evening',
    emoji: '🌅',
    theme: RoutineColorTheme.pink,
    period: TodPeriod.evening,
    schedule: const RoutineSchedule(
      days: _weekdays,
      time: TimeOfDay(hour: 18, minute: 0),
    ),
    streakDays: 15,
    activities: const [
      RoutineActivity(
        id: 'ew-1',
        emoji: '🍽',
        title: 'Light Dinner',
        durationMinutes: 20,
      ),
      RoutineActivity(
        id: 'ew-2',
        emoji: '🧘',
        title: 'Gentle Stretch',
        durationMinutes: 10,
      ),
      RoutineActivity(
        id: 'ew-3',
        emoji: '📵',
        title: 'Screen Wind-down',
        durationMinutes: 5,
      ),
      RoutineActivity(
        id: 'ew-4',
        emoji: '🕯',
        title: 'Dim the Lights',
        durationMinutes: 2,
      ),
      RoutineActivity(
        id: 'ew-5',
        emoji: '📖',
        title: 'Read a Few Pages',
        durationMinutes: 10,
      ),
    ],
  ),
  Routine(
    id: 'gentle-yoga',
    title: 'Gentle Yoga',
    subtitle: 'Loosen up before bed',
    emoji: '🧘',
    theme: RoutineColorTheme.pink,
    period: TodPeriod.evening,
    schedule: const RoutineSchedule(
      days: _weekdays,
      time: TimeOfDay(hour: 19, minute: 0),
    ),
    activities: const [
      RoutineActivity(
        id: 'gy-1',
        emoji: '🧘',
        title: "Cat-Cow Pose",
        durationMinutes: 3,
      ),
      RoutineActivity(
        id: 'gy-2',
        emoji: '🧘‍♀️',
        title: "Child's Pose",
        durationMinutes: 3,
      ),
      RoutineActivity(
        id: 'gy-3',
        emoji: '🫁',
        title: 'Deep Breathing',
        durationMinutes: 4,
      ),
      RoutineActivity(
        id: 'gy-4',
        emoji: '😌',
        title: 'Final Relaxation',
        durationMinutes: 5,
      ),
    ],
  ),
  Routine(
    id: 'gratitude-journal',
    title: 'Gratitude Journal',
    subtitle: 'Reflect on the good parts of today',
    emoji: '📓',
    theme: RoutineColorTheme.pink,
    period: TodPeriod.evening,
    schedule: const RoutineSchedule(
      days: _weekdays,
      time: TimeOfDay(hour: 20, minute: 0),
    ),
    activities: const [
      RoutineActivity(
        id: 'gj-1',
        emoji: '📓',
        title: 'Write 3 Things',
        durationMinutes: 2,
      ),
      RoutineActivity(
        id: 'gj-2',
        emoji: '🙏',
        title: 'Reflect',
        durationMinutes: 1,
      ),
    ],
  ),
  Routine(
    id: 'bedtime-ritual',
    title: 'Bedtime Ritual',
    subtitle: 'Wind all the way down for sleep',
    emoji: '🌙',
    theme: RoutineColorTheme.purple,
    period: TodPeriod.night,
    schedule: const RoutineSchedule(
      days: _weekdays,
      time: TimeOfDay(hour: 21, minute: 30),
    ),
    streakDays: 20,
    activities: const [
      RoutineActivity(
        id: 'br-1',
        emoji: '🚿',
        title: 'Warm Shower',
        durationMinutes: 10,
      ),
      RoutineActivity(
        id: 'br-2',
        emoji: '✨',
        title: 'Night Skincare',
        durationMinutes: 5,
      ),
      RoutineActivity(
        id: 'br-3',
        emoji: '🦷',
        title: 'Brush Teeth',
        durationMinutes: 3,
      ),
      RoutineActivity(
        id: 'br-4',
        emoji: '📵',
        title: 'Phone Away',
        durationMinutes: 1,
      ),
      RoutineActivity(
        id: 'br-5',
        emoji: '🧘',
        title: 'Calming Stretch',
        durationMinutes: 5,
      ),
      RoutineActivity(
        id: 'br-6',
        emoji: '😴',
        title: 'Lights Out',
        durationMinutes: 1,
      ),
    ],
  ),
  Routine(
    id: 'sleep-meditation',
    title: 'Sleep Meditation',
    subtitle: 'Guided calm to fall asleep',
    emoji: '🌙',
    theme: RoutineColorTheme.purple,
    period: TodPeriod.night,
    schedule: const RoutineSchedule(
      days: _weekdays,
      time: TimeOfDay(hour: 22, minute: 0),
    ),
    activities: const [
      RoutineActivity(
        id: 'sm-1',
        emoji: '🌙',
        title: 'Guided Meditation',
        durationMinutes: 10,
      ),
      RoutineActivity(
        id: 'sm-2',
        emoji: '🫁',
        title: 'Slow Breathing',
        durationMinutes: 3,
      ),
      RoutineActivity(
        id: 'sm-3',
        emoji: '😴',
        title: 'Settle In',
        durationMinutes: 2,
      ),
    ],
  ),
  Routine(
    id: 'dream-journal',
    title: 'Dream Journal',
    subtitle: 'Set an intention for tonight',
    emoji: '📔',
    theme: RoutineColorTheme.purple,
    period: TodPeriod.night,
    schedule: const RoutineSchedule(
      days: _weekdays,
      time: TimeOfDay(hour: 22, minute: 30),
    ),
    activities: const [
      RoutineActivity(
        id: 'dj-1',
        emoji: '📔',
        title: 'Jot Down Thoughts',
        durationMinutes: 2,
      ),
      RoutineActivity(
        id: 'dj-2',
        emoji: '🌙',
        title: 'Set Sleep Intention',
        durationMinutes: 1,
      ),
    ],
  ),
];

/// All routine templates. State-driven — screens read this rather than
/// hardcoding any single routine, and [addRoutine] lets 22f actually grow
/// this list at runtime.
class RoutinesController extends StateNotifier<List<Routine>> {
  RoutinesController() : super(_seedRoutines());

  void addRoutine(Routine routine) => state = [...state, routine];

  void updateRoutine(Routine routine) {
    state = [for (final r in state) r.id == routine.id ? routine : r];
  }

  List<Routine> forPeriod(TodPeriod period) =>
      state.where((r) => r.period == period).toList();

  /// The routine Today's "Up Next" card should surface for [period] — the
  /// one with the active streak if there is one, else the earliest
  /// scheduled. Returns null if no routine exists for that period yet.
  Routine? featuredFor(TodPeriod period) {
    final routines = forPeriod(period);
    if (routines.isEmpty) return null;
    routines.sort((a, b) {
      if (a.hasStreak != b.hasStreak) return a.hasStreak ? -1 : 1;
      final aMinutes = a.schedule.time.hour * 60 + a.schedule.time.minute;
      final bMinutes = b.schedule.time.hour * 60 + b.schedule.time.minute;
      return aMinutes.compareTo(bMinutes);
    });
    return routines.first;
  }
}

final routinesControllerProvider =
    StateNotifierProvider<RoutinesController, List<Routine>>(
      (ref) => RoutinesController(),
    );

/// Per-day completion tracking, keyed by "routineId|yyyy-mm-dd". Seeded
/// with a small illustrative history (matching the pattern of completed/
/// missed/in-progress days shown on 22g's calendar mock) so the calendar
/// isn't empty on first run — this is placeholder history, not real
/// persisted data, until a backend exists.
class RoutineCompletionsController
    extends StateNotifier<Map<String, RoutineCompletion>> {
  RoutineCompletionsController() : super(_seedCompletions());

  static String _key(String routineId, DateTime date) =>
      '$routineId|${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static Map<String, RoutineCompletion> _seedCompletions() {
    final today = DateTime.now();
    final map = <String, RoutineCompletion>{};
    DateTime dayOffset(int daysAgo) {
      final d = today.subtract(Duration(days: daysAgo));
      return DateTime(d.year, d.month, d.day);
    }

    // Morning Wellness: steps 1-2 done today, matching 22e's mock exactly.
    map[_key('morning-wellness', dayOffset(0))] = RoutineCompletion(
      routineId: 'morning-wellness',
      date: dayOffset(0),
      completedActivityIds: const {'mw-1', 'mw-2'},
    );
    // A short illustrative history backing the 12-day streak and the
    // calendar's completed/missed dots — placeholder until a backend
    // tracks real history; matches the mix of states 22g's mock shows.
    const allFive = {'mw-1', 'mw-2', 'mw-3', 'mw-4', 'mw-5'};
    for (final daysAgo in [1, 2, 4, 5, 6]) {
      map[_key('morning-wellness', dayOffset(daysAgo))] = RoutineCompletion(
        routineId: 'morning-wellness',
        date: dayOffset(daysAgo),
        completedActivityIds: allFive,
      );
    }
    map[_key('morning-wellness', dayOffset(3))] = RoutineCompletion(
      routineId: 'morning-wellness',
      date: dayOffset(3),
      completedActivityIds: const {},
    );
    return map;
  }

  RoutineCompletion completionFor(String routineId, DateTime date) {
    final key = _key(routineId, date);
    return state[key] ??
        RoutineCompletion(
          routineId: routineId,
          date: DateTime(date.year, date.month, date.day),
        );
  }

  void toggleActivity(String routineId, DateTime date, String activityId) {
    final key = _key(routineId, date);
    final current = completionFor(routineId, date);
    state = {...state, key: current.toggling(activityId)};
  }
}

final routineCompletionsControllerProvider =
    StateNotifierProvider<
      RoutineCompletionsController,
      Map<String, RoutineCompletion>
    >((ref) => RoutineCompletionsController());
