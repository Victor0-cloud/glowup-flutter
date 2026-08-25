import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One Tier 4 batch pass — stored for auditability ("version, cost and
/// outcome information" per the amendment). `estimatedCost`/`modelCalls`
/// stay at zero today because Tier 4's only work in this slice
/// (`PatternPromotionJob`) is fully deterministic and never calls a model.
class BatchRunRecord {
  const BatchRunRecord({
    required this.id,
    required this.userId,
    required this.startedAt,
    required this.completedAt,
    required this.patternsPromoted,
    required this.patternsExpired,
    this.modelCallsUsed = 0,
    this.estimatedCost,
    required this.version,
  });

  final String id;
  final String userId;
  final DateTime startedAt;
  final DateTime completedAt;
  final int patternsPromoted;
  final int patternsExpired;
  final int modelCallsUsed;
  final double? estimatedCost;
  final int version;

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt.toIso8601String(),
    'patternsPromoted': patternsPromoted,
    'patternsExpired': patternsExpired,
    'modelCallsUsed': modelCallsUsed,
    if (estimatedCost != null) 'estimatedCost': estimatedCost,
    'version': version,
  };

  factory BatchRunRecord.fromJson(Map<String, dynamic> j) => BatchRunRecord(
    id: j['id'] as String,
    userId: j['userId'] as String,
    startedAt: DateTime.parse(j['startedAt'] as String),
    completedAt: DateTime.parse(j['completedAt'] as String),
    patternsPromoted: j['patternsPromoted'] as int,
    patternsExpired: j['patternsExpired'] as int,
    modelCallsUsed: j['modelCallsUsed'] as int? ?? 0,
    estimatedCost: (j['estimatedCost'] as num?)?.toDouble(),
    version: j['version'] as int,
  );
}

class BatchRunRepository {
  BatchRunRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'batch_run_records_v1';
  static const _lastRunKey = 'batch_last_run_at_v1';

  List<BatchRunRecord> loadAll() {
    final raw = _prefs.getStringList(_key) ?? const [];
    return [
      for (final e in raw)
        BatchRunRecord.fromJson(jsonDecode(e) as Map<String, dynamic>),
    ];
  }

  Future<void> add(BatchRunRecord record) async {
    final all = loadAll();
    await _prefs.setStringList(_key, [
      for (final r in [...all, record]) jsonEncode(r.toJson()),
    ]);
    await _prefs.setString(_lastRunKey, record.completedAt.toIso8601String());
  }

  DateTime? lastRunAt() {
    final raw = _prefs.getString(_lastRunKey);
    return raw == null ? null : DateTime.parse(raw);
  }
}
