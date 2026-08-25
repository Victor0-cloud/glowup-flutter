import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/water_entry.dart';

/// Durable on-device storage for water tracking — the same
/// [SharedPreferences]-backed pattern established by
/// `WorkoutHistoryRepository` (real durable storage, not a cloud backend).
/// Entries are stored as one flat, ever-growing JSON array; "today's
/// total" and "history" are both just different filters/views over the
/// same list — there is no separate per-day record to explicitly "reset",
/// so a new calendar day naturally starts at zero without ever deleting a
/// previous day's entries.
///
/// Storage keys bumped to `_v2` for the glasses -> ml migration (a
/// genuine unit/shape change, not a compatible extension) — this is a
/// pre-launch app with no real user data at risk (confirmed earlier this
/// session: no auth, single local-device profile), so the old `_v1` keys
/// are simply left orphaned rather than migrated.
class WaterRepository {
  WaterRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _entriesKey = 'water_entries_v2';
  static const _goalKey = 'water_goal_ml_v2';
  static const _unitKey = 'water_unit_pref_v1';

  /// A commonly-cited general daily fluid intake figure, used only as a
  /// starting default the user can change — never presented as medical
  /// guidance (see the Water Tracker screen's goal-editing copy).
  static const defaultGoalMl = 2000.0;
  static const defaultUnit = WaterUnit.ml;

  List<WaterEntry> loadEntries() {
    final raw = _prefs.getStringList(_entriesKey) ?? const [];
    return [
      for (final e in raw)
        WaterEntry.fromJson(jsonDecode(e) as Map<String, dynamic>),
    ];
  }

  double loadGoal() => _prefs.getDouble(_goalKey) ?? defaultGoalMl;

  Future<void> saveGoal(double goalMl) => _prefs.setDouble(_goalKey, goalMl);

  WaterUnit loadUnit() {
    final raw = _prefs.getString(_unitKey);
    return WaterUnit.values.firstWhere(
      (u) => u.name == raw,
      orElse: () => defaultUnit,
    );
  }

  Future<void> saveUnit(WaterUnit unit) =>
      _prefs.setString(_unitKey, unit.name);

  Future<void> _saveEntries(List<WaterEntry> entries) {
    return _prefs.setStringList(_entriesKey, [
      for (final e in entries) jsonEncode(e.toJson()),
    ]);
  }

  /// Idempotent by [WaterEntry.id] — the same dedup guarantee already
  /// proven for `WorkoutHistoryRepository.add()`/`LearningEventRepository.
  /// add()`: a duplicate id (e.g. a retried/double-fired quick-add tap)
  /// never creates a second stored entry, while a genuinely new id (a real
  /// second tap, even for the identical amount) always does.
  Future<WaterEntry> addEntry(WaterEntry entry) async {
    final current = loadEntries();
    final existing = current.where((e) => e.id == entry.id);
    if (existing.isNotEmpty) return existing.first;
    await _saveEntries([...current, entry]);
    return entry;
  }

  /// Removes the entry with [id], returning the removed entry (or null if
  /// it didn't exist) so callers can offer Undo by re-adding it — a no-op,
  /// never an error, if the id is already gone.
  Future<WaterEntry?> removeEntry(String id) async {
    final current = loadEntries();
    WaterEntry? removed;
    final updated = current.where((e) {
      if (e.id == id) {
        removed = e;
        return false;
      }
      return true;
    }).toList();
    if (removed == null) return null;
    await _saveEntries(updated);
    return removed;
  }
}
