import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/food_scan_models.dart';

/// Durable on-device storage for confirmed meals — same
/// [SharedPreferences]-backed flat-list pattern as `WaterRepository`/
/// `WorkoutHistoryRepository`. Never stores an unconfirmed detection: a
/// [FoodScanEntry] only ever gets here via the confirm/save step.
class FoodScanRepository {
  FoodScanRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _entriesKey = 'food_scan_entries_v1';

  List<FoodScanEntry> loadEntries() {
    final raw = _prefs.getStringList(_entriesKey) ?? const [];
    return [
      for (final e in raw)
        FoodScanEntry.fromJson(jsonDecode(e) as Map<String, dynamic>),
    ];
  }

  Future<void> _saveEntries(List<FoodScanEntry> entries) {
    return _prefs.setStringList(_entriesKey, [
      for (final e in entries) jsonEncode(e.toJson()),
    ]);
  }

  /// Idempotent by id — matches `WaterRepository.addEntry`'s dedup
  /// contract, so a retried/double-fired save never creates a duplicate.
  Future<FoodScanEntry> addEntry(FoodScanEntry entry) async {
    final current = loadEntries();
    final existing = current.where((e) => e.id == entry.id);
    if (existing.isNotEmpty) return existing.first;
    await _saveEntries([...current, entry]);
    return entry;
  }

  /// Removes the entry with [id], returning it (or null if already gone)
  /// so the caller can delete its associated image file.
  Future<FoodScanEntry?> removeEntry(String id) async {
    final current = loadEntries();
    FoodScanEntry? removed;
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
