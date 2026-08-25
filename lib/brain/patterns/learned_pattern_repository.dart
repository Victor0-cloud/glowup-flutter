import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'learned_pattern.dart';

class LearnedPatternRepository {
  LearnedPatternRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'learned_patterns_v1';

  List<LearnedPattern> loadAll() {
    final raw = _prefs.getStringList(_key) ?? const [];
    return [
      for (final e in raw)
        LearnedPattern.fromJson(jsonDecode(e) as Map<String, dynamic>),
    ];
  }

  Future<void> _saveAll(List<LearnedPattern> patterns) {
    return _prefs.setStringList(_key, [
      for (final p in patterns) jsonEncode(p.toJson()),
    ]);
  }

  Future<LearnedPattern> upsert(LearnedPattern pattern) async {
    final all = loadAll();
    final updated = [...all.where((p) => p.id != pattern.id), pattern];
    await _saveAll(updated);
    return pattern;
  }

  LearnedPattern? find({
    required String userId,
    required String patternType,
    required String subjectId,
  }) {
    for (final p in loadAll()) {
      if (p.userId == userId &&
          p.patternType == patternType &&
          p.subjectId == subjectId) {
        return p;
      }
    }
    return null;
  }

  /// Active patterns for [userId], most-recently-observed first, capped to
  /// [limit] — the bounded read Tier 2 must use instead of loading every
  /// pattern ever detected.
  List<LearnedPattern> activeFor({required String userId, required int limit}) {
    final active =
        loadAll()
            .where(
              (p) => p.userId == userId && p.status == PatternStatus.active,
            )
            .toList()
          ..sort((a, b) => b.lastObservedAt.compareTo(a.lastObservedAt));
    return active.length > limit ? active.sublist(0, limit) : active;
  }
}
