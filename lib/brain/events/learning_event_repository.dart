import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'learning_event.dart';

/// Thrown when a caller tries to ingest a payload larger than its event
/// type's declared [EventTypeSchema.maxPayloadBytes] — Tier 0 rejects this
/// outright rather than silently truncating (silent truncation of a
/// safety-critical payload is explicitly forbidden).
class EventPayloadTooLargeException implements Exception {
  EventPayloadTooLargeException(this.type, this.actualBytes, this.maxBytes);
  final LearningEventType type;
  final int actualBytes;
  final int maxBytes;

  @override
  String toString() =>
      'EventPayloadTooLargeException: ${type.name} payload is $actualBytes bytes, max is $maxBytes';
}

/// Tier 0 (event ingestion) storage: durable, append-only, idempotent by
/// [LearningEvent.id] — the exact `WorkoutHistoryRepository`/
/// `WaterRepository` dedup pattern already proven this session, so a
/// duplicate submission (e.g. a UI double-tap, or a resubmitted retry)
/// never creates a second record. This class does nothing else: no Tier 1
/// reactive processing, no Tier 2 decisions, no AI-provider reference
/// anywhere in this file — by construction, Tier 0 cannot call an AI
/// provider because it has no dependency capable of doing so.
class LearningEventRepository {
  LearningEventRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'learning_events_v1';

  List<LearningEvent> loadAll() {
    final raw = _prefs.getStringList(_key) ?? const [];
    return [
      for (final e in raw)
        LearningEvent.fromJson(jsonDecode(e) as Map<String, dynamic>),
    ];
  }

  /// Events for [userId] only, most-recent-first, capped to [limit] and to
  /// events within [lookbackDays] of now — the bounded-context read every
  /// Tier 1/2 consumer must use instead of ever loading the full history.
  /// Ordering is by [LearningEvent.occurredAt] (stable, not accidental
  /// storage order), so results are deterministic regardless of how the
  /// underlying list was appended.
  List<LearningEvent> loadBounded({
    required String userId,
    required int limit,
    required int lookbackDays,
  }) {
    final cutoff = DateTime.now().subtract(Duration(days: lookbackDays));
    final all =
        loadAll()
            .where((e) => e.userId == userId && e.occurredAt.isAfter(cutoff))
            .toList()
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return all.length > limit ? all.sublist(0, limit) : all;
  }

  Future<void> _saveAll(List<LearningEvent> events) {
    return _prefs.setStringList(_key, [
      for (final e in events) jsonEncode(e.toJson()),
    ]);
  }

  /// Appends [event], validating its payload size against its declared
  /// schema first. Returns the stored event — either [event] itself, or the
  /// pre-existing event with the same id if this was a duplicate/retry
  /// (never a second copy).
  Future<LearningEvent> add(LearningEvent event) async {
    final maxBytes = event.schema.maxPayloadBytes;
    final actualBytes = event.payloadByteLength;
    if (actualBytes > maxBytes) {
      throw EventPayloadTooLargeException(event.type, actualBytes, maxBytes);
    }
    final current = loadAll();
    final existing = current.where((e) => e.id == event.id);
    if (existing.isNotEmpty) return existing.first;
    await _saveAll([...current, event]);
    return event;
  }

  /// True if [eventId] must be preserved regardless of retention/rollup
  /// policy — referenced by [referencedEventIds], which callers populate
  /// from active learned-pattern evidence and stored recommendation
  /// evidence before running any Tier 4 retention pass. Safety-extended
  /// events (`painReported`) are always protected on top of this.
  bool isProtected(LearningEvent event, Set<String> referencedEventIds) {
    return event.schema.retention == RetentionPolicy.safetyExtended ||
        referencedEventIds.contains(event.id);
  }

  /// The explicit "reset AI memory" user action (Profile → AI
  /// Personalization) — permanently erases every stored learning event.
  /// Never called implicitly; this is the one deliberate, user-initiated
  /// deletion path for this store.
  Future<void> clearAll() => _prefs.remove(_key);
}
