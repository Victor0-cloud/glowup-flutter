import 'package:flutter/material.dart' show Color, TimeOfDay, DayPeriod;
import '../../core/tod/tod_period.dart';

enum Weekday { monday, tuesday, wednesday, thursday, friday, saturday, sunday }

extension WeekdayLabel on Weekday {
  String get shortLabel => switch (this) {
    Weekday.monday => 'M',
    Weekday.tuesday => 'T',
    Weekday.wednesday => 'W',
    Weekday.thursday => 'T',
    Weekday.friday => 'F',
    Weekday.saturday => 'S',
    Weekday.sunday => 'S',
  };
}

/// The 4 selectable swatches on 22f's "Color Theme" row (368:2101-2108),
/// confirmed via the exported Color-Ring assets: gold/pink/purple/lavender.
enum RoutineColorTheme { gold, pink, purple, lavender }

extension RoutineColorThemeColor on RoutineColorTheme {
  Color get color => switch (this) {
    RoutineColorTheme.gold => const Color(0xFFFFD043),
    RoutineColorTheme.pink => const Color(0xFFFF5E97),
    RoutineColorTheme.purple => const Color(0xFF8E54E9),
    RoutineColorTheme.lavender => const Color(0xFFC084FC),
  };
}

/// One step inside a routine (368:1990-2031 "Step-Card"). `emoji` is used
/// verbatim as Figma itself renders these as literal emoji glyphs, not SVG
/// icons — there is no asset to substitute.
class RoutineActivity {
  const RoutineActivity({
    required this.id,
    required this.emoji,
    required this.title,
    required this.durationMinutes,
  });

  final String id;
  final String emoji;
  final String title;
  final int durationMinutes;
}

class RoutineSchedule {
  const RoutineSchedule({required this.days, required this.time});

  final Set<Weekday> days;
  final TimeOfDay time;

  String get formattedTime {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}

/// A routine template (368:1637 "Routine-Card" / 368:1956 detail /
/// 368:2057 create form). `streakDays == 0` renders as "No streak" per the
/// approved card ("no streak" pill vs. the "N days" pill).
class Routine {
  const Routine({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.theme,
    required this.period,
    required this.schedule,
    required this.activities,
    this.streakDays = 0,
  });

  final String id;
  final String title;
  final String subtitle;
  final String emoji;
  final RoutineColorTheme theme;
  final TodPeriod period;
  final RoutineSchedule schedule;
  final List<RoutineActivity> activities;
  final int streakDays;

  bool get hasStreak => streakDays > 0;
  int get totalMinutes =>
      activities.fold(0, (sum, a) => sum + a.durationMinutes);

  Routine copyWith({
    String? title,
    String? subtitle,
    String? emoji,
    RoutineColorTheme? theme,
    TodPeriod? period,
    RoutineSchedule? schedule,
    List<RoutineActivity>? activities,
    int? streakDays,
  }) {
    return Routine(
      id: id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      emoji: emoji ?? this.emoji,
      theme: theme ?? this.theme,
      period: period ?? this.period,
      schedule: schedule ?? this.schedule,
      activities: activities ?? this.activities,
      streakDays: streakDays ?? this.streakDays,
    );
  }
}

/// A single day's progress through a routine's steps (368:1997 checked vs.
/// unchecked "Checkbox-Container", and the calendar's per-day status dot).
/// Keyed by [date] at day resolution (time-of-day component ignored).
class RoutineCompletion {
  const RoutineCompletion({
    required this.routineId,
    required this.date,
    this.completedActivityIds = const {},
  });

  final String routineId;
  final DateTime date;
  final Set<String> completedActivityIds;

  bool isActivityDone(String activityId) =>
      completedActivityIds.contains(activityId);

  RoutineCompletion toggling(String activityId) {
    final next = {...completedActivityIds};
    if (!next.remove(activityId)) next.add(activityId);
    return RoutineCompletion(
      routineId: routineId,
      date: date,
      completedActivityIds: next,
    );
  }
}
