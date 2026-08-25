import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'current_state_entry.dart';

/// Tier 1 storage for [CurrentStateEntry] snapshots — durable so a
/// still-live fact (e.g. shoulder soreness reported an hour ago) survives
/// an app restart, but functionally temporary because every read filters
/// by [CurrentStateEntry.isLiveAt].
class CurrentStateRepository {
  CurrentStateRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'current_state_v1';

  List<CurrentStateEntry> _loadAll() {
    final raw = _prefs.getStringList(_key) ?? const [];
    return [
      for (final e in raw)
        CurrentStateEntry.fromJson(jsonDecode(e) as Map<String, dynamic>),
    ];
  }

  Future<void> _saveAll(List<CurrentStateEntry> entries) {
    return _prefs.setStringList(_key, [
      for (final e in entries) jsonEncode(e.toJson()),
    ]);
  }

  /// Live entries for [userId] as of [now] — expired entries are dropped
  /// from what's returned (and, as a housekeeping side effect, from what's
  /// persisted too, so the store doesn't grow unboundedly with stale keys).
  Future<List<CurrentStateEntry>> liveEntries({
    required String userId,
    required DateTime now,
  }) async {
    final all = _loadAll();
    final live = all.where((e) => e.isLiveAt(now)).toList();
    if (live.length != all.length) await _saveAll(live);
    return live.where((e) => e.userId == userId).toList();
  }

  /// Upserts by (userId, key) — a new value for an existing key replaces
  /// it rather than accumulating, since this models "current" state.
  Future<void> setEntry(CurrentStateEntry entry) async {
    final all = _loadAll();
    final updated = [
      ...all.where((e) => !(e.userId == entry.userId && e.key == entry.key)),
      entry,
    ];
    await _saveAll(updated);
  }
}
