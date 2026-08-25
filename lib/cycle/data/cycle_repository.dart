import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/cycle_models.dart';

/// Durable on-device storage for Period & Cycle data — same
/// [SharedPreferences]-backed pattern as every other module. Entirely
/// local: this data is never sent to any network endpoint by this
/// repository or its controller.
class CycleRepository {
  CycleRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _periodsKey = 'cycle_periods_v1';
  static const _daysKey = 'cycle_days_v1';
  static const _settingsKey = 'cycle_settings_v1';
  static const _notebookKey = 'cycle_notebook_v1';

  List<PeriodEntry> loadPeriods() {
    final raw = _prefs.getStringList(_periodsKey) ?? const [];
    return [
      for (final e in raw)
        PeriodEntry.fromJson(jsonDecode(e) as Map<String, dynamic>),
    ];
  }

  Future<void> _savePeriods(List<PeriodEntry> periods) {
    return _prefs.setStringList(_periodsKey, [
      for (final p in periods) jsonEncode(p.toJson()),
    ]);
  }

  Future<PeriodEntry> upsertPeriod(PeriodEntry period) async {
    final current = loadPeriods();
    final index = current.indexWhere((p) => p.id == period.id);
    if (index == -1) {
      await _savePeriods([...current, period]);
    } else {
      final updated = [...current];
      updated[index] = period;
      await _savePeriods(updated);
    }
    return period;
  }

  Future<PeriodEntry?> removePeriod(String id) async {
    final current = loadPeriods();
    PeriodEntry? removed;
    final updated = current.where((p) {
      if (p.id == id) {
        removed = p;
        return false;
      }
      return true;
    }).toList();
    if (removed == null) return null;
    await _savePeriods(updated);
    return removed;
  }

  List<CycleDayEntry> loadDayEntries() {
    final raw = _prefs.getStringList(_daysKey) ?? const [];
    return [
      for (final e in raw)
        CycleDayEntry.fromJson(jsonDecode(e) as Map<String, dynamic>),
    ];
  }

  Future<void> _saveDayEntries(List<CycleDayEntry> entries) {
    return _prefs.setStringList(_daysKey, [
      for (final e in entries) jsonEncode(e.toJson()),
    ]);
  }

  /// Upserts by calendar day — at most one [CycleDayEntry] per date.
  Future<CycleDayEntry> upsertDayEntry(CycleDayEntry entry) async {
    final current = loadDayEntries();
    final index = current.indexWhere((e) => e.dateKey == entry.dateKey);
    if (index == -1) {
      await _saveDayEntries([...current, entry]);
    } else {
      final updated = [...current];
      updated[index] = entry;
      await _saveDayEntries(updated);
    }
    return entry;
  }

  Future<bool> removeDayEntry(String dateKey) async {
    final current = loadDayEntries();
    final existed = current.any((e) => e.dateKey == dateKey);
    if (!existed) return false;
    await _saveDayEntries(current.where((e) => e.dateKey != dateKey).toList());
    return true;
  }

  /// Deletes every stored period and day entry — the "delete all my
  /// cycle data" privacy control.
  Future<void> deleteAll() async {
    await _prefs.remove(_periodsKey);
    await _prefs.remove(_daysKey);
    await _prefs.remove(_notebookKey);
  }

  CycleSettings loadSettings() {
    final raw = _prefs.getString(_settingsKey);
    if (raw == null) return const CycleSettings();
    return CycleSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveSettings(CycleSettings settings) {
    return _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  List<DailyNotebookEntry> loadNotebookEntries() {
    final raw = _prefs.getStringList(_notebookKey) ?? const [];
    return [
      for (final e in raw)
        DailyNotebookEntry.fromJson(jsonDecode(e) as Map<String, dynamic>),
    ];
  }

  Future<void> _saveNotebookEntries(List<DailyNotebookEntry> entries) {
    return _prefs.setStringList(_notebookKey, [
      for (final e in entries) jsonEncode(e.toJson()),
    ]);
  }

  /// Upserts by calendar day — at most one [DailyNotebookEntry] per date,
  /// same convention as [upsertDayEntry].
  Future<DailyNotebookEntry> upsertNotebookEntry(
    DailyNotebookEntry entry,
  ) async {
    final current = loadNotebookEntries();
    final index = current.indexWhere((e) => e.dateKey == entry.dateKey);
    if (index == -1) {
      await _saveNotebookEntries([...current, entry]);
    } else {
      final updated = [...current];
      updated[index] = entry;
      await _saveNotebookEntries(updated);
    }
    return entry;
  }
}
