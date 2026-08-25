import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Self-reported mood level — never inferred, always exactly what the user
/// tapped. [score] is a fixed 1 (lowest) - 5 (highest) mapping used for
/// deterministic averages/trends, matching the approved Figma reference
/// (assets/glow_up/design_reference/mood_checkin/45_mood_checkin.png).
enum MoodLevel { terrible, notGreat, okay, good, amazing }

extension MoodLevelX on MoodLevel {
  String get label => switch (this) {
    MoodLevel.amazing => 'Amazing',
    MoodLevel.good => 'Good',
    MoodLevel.okay => 'Okay',
    MoodLevel.notGreat => 'Not Great',
    MoodLevel.terrible => 'Terrible',
  };

  String get emoji => switch (this) {
    MoodLevel.amazing => '🤩',
    MoodLevel.good => '🙂',
    MoodLevel.okay => '😐',
    MoodLevel.notGreat => '🙁',
    MoodLevel.terrible => '😖',
  };

  /// 1 (terrible) - 5 (amazing) — deterministic, used for every average
  /// shown in history, never a heuristic or model output.
  int get score => switch (this) {
    MoodLevel.terrible => 1,
    MoodLevel.notGreat => 2,
    MoodLevel.okay => 3,
    MoodLevel.good => 4,
    MoodLevel.amazing => 5,
  };

  Color get color => switch (this) {
    MoodLevel.amazing => AppColors.purple,
    MoodLevel.good => AppColors.success,
    MoodLevel.okay => AppColors.gold,
    MoodLevel.notGreat => AppColors.orange,
    MoodLevel.terrible => AppColors.ctaStart,
  };
}

/// Display (and selection) order — Amazing first, matching the approved
/// reference. [MoodLevel]'s own declaration order stays ascending by score
/// so [MoodLevelX.score] reads naturally; this is the separate order the UI
/// actually renders in.
const kMoodLevelDisplayOrder = [
  MoodLevel.amazing,
  MoodLevel.good,
  MoodLevel.okay,
  MoodLevel.notGreat,
  MoodLevel.terrible,
];

/// Fixed-vocabulary "why do you feel this way" chips — never free text, so
/// (like [kCycleSymptoms] in Period & Cycle) this can never become a place
/// personal narrative accidentally leaks into a Brain event payload. The
/// optional [MoodEntry.note] stays local-only and is never placed in an
/// event payload.
const kMoodReasons = [
  'Grateful',
  'Energetic',
  'Calm',
  'Stressed',
  'Tired',
  'Other',
];

/// One calendar day's mood check-in. At most one entry per calendar day
/// (upserted by date, matching [CycleDayEntry]'s and this app's daily-log
/// convention) — checking in again the same day edits today's entry rather
/// than creating a second one.
class MoodEntry {
  const MoodEntry({
    required this.date,
    required this.level,
    this.reasons = const {},
    this.energyLevel,
    this.stressLevel,
    this.note,
  });

  final DateTime date;
  final MoodLevel level;
  final Set<String> reasons;

  /// 1 (lowest) - 5 (highest), self-reported.
  final int? energyLevel;

  /// 1 (lowest) - 5 (highest), self-reported.
  final int? stressLevel;

  /// Private, local-only note — never placed in a Brain event payload.
  final String? note;

  String get dateKey =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  MoodEntry copyWith({
    MoodLevel? level,
    Set<String>? reasons,
    int? energyLevel,
    bool clearEnergyLevel = false,
    int? stressLevel,
    bool clearStressLevel = false,
    String? note,
    bool clearNote = false,
  }) => MoodEntry(
    date: date,
    level: level ?? this.level,
    reasons: reasons ?? this.reasons,
    energyLevel: clearEnergyLevel ? null : (energyLevel ?? this.energyLevel),
    stressLevel: clearStressLevel ? null : (stressLevel ?? this.stressLevel),
    note: clearNote ? null : (note ?? this.note),
  );

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'level': level.name,
    if (reasons.isNotEmpty) 'reasons': reasons.toList(),
    if (energyLevel != null) 'energyLevel': energyLevel,
    if (stressLevel != null) 'stressLevel': stressLevel,
    if (note != null) 'note': note,
  };

  factory MoodEntry.fromJson(Map<String, dynamic> j) => MoodEntry(
    date: DateTime.parse(j['date'] as String),
    level: MoodLevel.values.byName(j['level'] as String),
    reasons: ((j['reasons'] as List?)?.cast<String>() ?? const []).toSet(),
    energyLevel: j['energyLevel'] as int?,
    stressLevel: j['stressLevel'] as int?,
    note: j['note'] as String?,
  );
}
