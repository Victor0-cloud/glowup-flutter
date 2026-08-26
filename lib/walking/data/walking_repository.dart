import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/walking_models.dart';

String dateKeyFor(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Durable on-device storage for Walking & Steps — same
/// [SharedPreferences]-backed pattern as `WaterRepository`/
/// `WorkoutHistoryRepository`. Two real, separate concerns (Section 5 of
/// the approved spec):
///
/// 1. **Daily steps baseline** — the phone's step sensor only ever
///    reports a cumulative count *since the device last booted*, never
///    "steps today" directly. This stores the cumulative value observed
///    at the start of the current calendar day, so `today = cumulative -
///    baseline`. Known, disclosed MVP simplification: if the phone
///    reboots mid-day, the cumulative counter resets and the portion of
///    today's steps taken *before* the reboot is lost (the baseline is
///    simply re-anchored to the new, lower post-reboot value) — correct
///    reboot-recovery would need tracking a running "today total" through
///    every reading rather than a single baseline snapshot; not built for
///    this MVP pass, and not verifiable without a real device anyway.
/// 2. **Walk session history** — real, saved [WalkSession] records, one
///    per finished "Start Walk," entirely separate from the daily
///    baseline (Section 5: never double-counted on top of it — a walk's
///    own step count is a *slice* of the same cumulative stream, read at
///    session start/end, never summed onto the daily total separately).
class WalkingRepository {
  WalkingRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _goalKey = 'walk_step_goal_v1';
  static const _baselineCumulativeKey = 'walk_daily_baseline_cumulative_v1';
  static const _baselineDateKey = 'walk_daily_baseline_date_v1';
  static const _lastGoalReachedDateKey = 'walk_last_goal_reached_date_v1';
  static const _sessionsKey = 'walk_sessions_v1';

  /// A commonly-cited general daily step figure, used only as a starting
  /// default the user can change — never presented as medical guidance
  /// (mirrors `WaterRepository.defaultGoalMl`'s own disclosure).
  static const defaultGoal = 8000;

  int loadGoal() => _prefs.getInt(_goalKey) ?? defaultGoal;

  Future<void> saveGoal(int goal) => _prefs.setInt(_goalKey, goal);

  /// The baseline cumulative-step-count for [dateKey], or null if no
  /// baseline has been recorded for that day yet (first reading of the
  /// day hasn't arrived).
  ({int cumulative, String dateKey})? loadBaseline() {
    final cumulative = _prefs.getInt(_baselineCumulativeKey);
    final dateKey = _prefs.getString(_baselineDateKey);
    if (cumulative == null || dateKey == null) return null;
    return (cumulative: cumulative, dateKey: dateKey);
  }

  Future<void> saveBaseline({required int cumulative, required String dateKey}) async {
    await _prefs.setInt(_baselineCumulativeKey, cumulative);
    await _prefs.setString(_baselineDateKey, dateKey);
  }

  /// Whether a [stepGoalReached] event has already fired for [dateKey] —
  /// the dedup guard for "at most once per day."
  bool goalAlreadyReachedFor(String dateKey) =>
      _prefs.getString(_lastGoalReachedDateKey) == dateKey;

  Future<void> markGoalReached(String dateKey) =>
      _prefs.setString(_lastGoalReachedDateKey, dateKey);

  List<WalkSession> loadSessions() {
    final raw = _prefs.getStringList(_sessionsKey) ?? const [];
    return [
      for (final e in raw) WalkSession.fromJson(jsonDecode(e) as Map<String, dynamic>),
    ];
  }

  /// Idempotent by [WalkSession.id] — same dedup guarantee already proven
  /// for `WaterRepository.addEntry`/`WorkoutHistoryRepository.add`.
  Future<WalkSession> addSession(WalkSession session) async {
    final current = loadSessions();
    final existing = current.where((s) => s.id == session.id);
    if (existing.isNotEmpty) return existing.first;
    final updated = [...current, session];
    await _prefs.setStringList(_sessionsKey, [
      for (final s in updated) jsonEncode(s.toJson()),
    ]);
    return session;
  }
}
