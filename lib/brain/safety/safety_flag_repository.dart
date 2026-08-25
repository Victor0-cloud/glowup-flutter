import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'safety_flag.dart';

class SafetyFlagRepository {
  SafetyFlagRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'safety_flags_v1';

  List<SafetyFlag> loadAll() {
    final raw = _prefs.getStringList(_key) ?? const [];
    return [
      for (final e in raw)
        SafetyFlag.fromJson(jsonDecode(e) as Map<String, dynamic>),
    ];
  }

  Future<void> _saveAll(List<SafetyFlag> flags) {
    return _prefs.setStringList(_key, [
      for (final f in flags) jsonEncode(f.toJson()),
    ]);
  }

  List<SafetyFlag> activeFor({
    required String userId,
    String? exerciseId,
    required DateTime now,
  }) {
    return loadAll()
        .where(
          (f) =>
              f.userId == userId &&
              f.isActiveAt(now) &&
              (exerciseId == null || f.exerciseId == exerciseId),
        )
        .toList();
  }

  /// Inserts a brand-new flag or replaces the stored version of an existing
  /// one (matched by [SafetyFlag.id]) — upsert, never a duplicate id.
  Future<SafetyFlag> upsert(SafetyFlag flag) async {
    final all = loadAll();
    final updated = [...all.where((f) => f.id != flag.id), flag];
    await _saveAll(updated);
    return flag;
  }

  SafetyFlag? findByExercise({
    required String userId,
    required String exerciseId,
    required DateTime now,
  }) {
    for (final f in loadAll()) {
      if (f.userId == userId &&
          f.exerciseId == exerciseId &&
          f.isActiveAt(now)) {
        return f;
      }
    }
    return null;
  }
}
