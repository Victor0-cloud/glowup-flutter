import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/facial_scan_models.dart';

/// Durable on-device storage for confirmed Facial Scan check-ins — same
/// pattern as `FoodScanRepository`/`WaterRepository`, in its own storage
/// key so Food/Facial data never mix.
class FacialScanRepository {
  FacialScanRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _entriesKey = 'facial_scan_entries_v1';

  List<FacialCheckIn> loadEntries() {
    final raw = _prefs.getStringList(_entriesKey) ?? const [];
    return [
      for (final e in raw)
        FacialCheckIn.fromJson(jsonDecode(e) as Map<String, dynamic>),
    ];
  }

  Future<void> _saveEntries(List<FacialCheckIn> entries) {
    return _prefs.setStringList(_entriesKey, [
      for (final e in entries) jsonEncode(e.toJson()),
    ]);
  }

  Future<FacialCheckIn> addEntry(FacialCheckIn entry) async {
    final current = loadEntries();
    final existing = current.where((e) => e.id == entry.id);
    if (existing.isNotEmpty) return existing.first;
    await _saveEntries([...current, entry]);
    return entry;
  }

  Future<FacialCheckIn?> removeEntry(String id) async {
    final current = loadEntries();
    FacialCheckIn? removed;
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
