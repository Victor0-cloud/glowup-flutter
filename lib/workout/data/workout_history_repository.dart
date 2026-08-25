import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout_completion_record.dart';

/// Durable, on-device storage for completed workouts — the first real
/// persistence layer in this app (audited: no `shared_preferences`/`hive`/
/// `sqflite`/`firebase` existed anywhere before this). Backed by
/// [SharedPreferences], which the Flutter/Windows/Android/iOS/web plugins
/// all implement with real durable storage (registry-backed on Windows,
/// `NSUserDefaults`/`SharedPreferences`/`localStorage` elsewhere) — this is
/// genuinely durable local storage, not an in-memory placeholder, but it is
/// NOT a cloud backend: there is no server, no sync, no account system.
/// Records are keyed only by [WorkoutCompletionRecord.localProfileId] since
/// no authentication exists yet (see that field's doc).
///
/// One JSON array under a single versioned key — the whole history is small
/// (a few hundred records at most for realistic usage) and always read/
/// written as a unit, so this needs no real query engine. A real backend or
/// `sqflite`/`hive` migration can read every record through this same
/// [WorkoutHistoryRepository] interface without any caller needing to
/// change.
class WorkoutHistoryRepository {
  WorkoutHistoryRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'workout_history_v1';

  List<WorkoutCompletionRecord> loadAll() {
    final raw = _prefs.getStringList(_key) ?? const [];
    return [
      for (final entry in raw)
        WorkoutCompletionRecord.fromJson(
          jsonDecode(entry) as Map<String, dynamic>,
        ),
    ];
  }

  Future<void> _saveAll(List<WorkoutCompletionRecord> records) {
    return _prefs.setStringList(_key, [
      for (final r in records) jsonEncode(r.toJson()),
    ]);
  }

  /// Appends [record] and persists immediately — unless a record with the
  /// same [WorkoutCompletionRecord.id] already exists, in which case this
  /// is a no-op that returns the existing stored record (the durable-layer
  /// half of duplicate-completion prevention; the UI layer adds its own
  /// button-disable/one-shot guard on top).
  Future<WorkoutCompletionRecord> add(WorkoutCompletionRecord record) async {
    final current = loadAll();
    for (final existing in current) {
      if (existing.id == record.id) return existing;
    }
    final updated = [...current, record];
    await _saveAll(updated);
    return record;
  }

  /// Replaces the record matching [record.id] (e.g. attaching feedback
  /// after the completion record was already saved) and persists
  /// immediately. Throws [StateError] if no record with that id exists —
  /// callers always update a record this repository already returned.
  Future<WorkoutCompletionRecord> update(WorkoutCompletionRecord record) async {
    final current = loadAll();
    final index = current.indexWhere((r) => r.id == record.id);
    if (index == -1) {
      throw StateError(
        'Cannot update workout completion record ${record.id}: not found.',
      );
    }
    final updated = [...current];
    updated[index] = record;
    await _saveAll(updated);
    return record;
  }
}
