import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'coach_recommendation.dart';

class CoachRecommendationRepository {
  CoachRecommendationRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'coach_recommendations_v1';

  List<CoachRecommendation> loadAll() {
    final raw = _prefs.getStringList(_key) ?? const [];
    return [
      for (final e in raw)
        CoachRecommendation.fromJson(jsonDecode(e) as Map<String, dynamic>),
    ];
  }

  Future<void> _saveAll(List<CoachRecommendation> recs) {
    return _prefs.setStringList(_key, [
      for (final r in recs) jsonEncode(r.toJson()),
    ]);
  }

  Future<CoachRecommendation> upsert(CoachRecommendation rec) async {
    final all = loadAll();
    final updated = [...all.where((r) => r.id != rec.id), rec];
    await _saveAll(updated);
    return rec;
  }

  CoachRecommendation? find(String id) {
    for (final r in loadAll()) {
      if (r.id == id) return r;
    }
    return null;
  }
}
