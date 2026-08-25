import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/mood_models.dart';

/// Durable on-device storage for Mood Check-In data — same
/// [SharedPreferences]-backed pattern as every other module. Entirely
/// local: this data is never sent to any network endpoint by this
/// repository or its controller.
class MoodRepository {
  MoodRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _entriesKey = 'mood_entries_v1';

  List<MoodEntry> loadEntries() {
    final raw = _prefs.getStringList(_entriesKey) ?? const [];
    return [
      for (final e in raw)
        MoodEntry.fromJson(jsonDecode(e) as Map<String, dynamic>),
    ];
  }

  Future<void> _saveEntries(List<MoodEntry> entries) {
    return _prefs.setStringList(_entriesKey, [
      for (final e in entries) jsonEncode(e.toJson()),
    ]);
  }

  /// Upserts by calendar day — at most one [MoodEntry] per date.
  Future<MoodEntry> upsertEntry(MoodEntry entry) async {
    final current = loadEntries();
    final index = current.indexWhere((e) => e.dateKey == entry.dateKey);
    if (index == -1) {
      await _saveEntries([...current, entry]);
    } else {
      final updated = [...current];
      updated[index] = entry;
      await _saveEntries(updated);
    }
    return entry;
  }
}
