import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workout/state/workout_history_controller.dart'
    show sharedPreferencesProvider;
import 'brain_event_repository.dart';
import 'learning_event.dart';
import 'learning_event_repository.dart';

/// Maps each local [EventModule] to the `source` string forwarded to the
/// server-side `brain_events` table (see `BrainEventRepository`) — the one
/// place this translation happens, so a module's remote "source" label
/// never drifts from its local one by accident.
String _remoteSourceFor(EventModule module) => switch (module) {
  EventModule.workout => 'workout',
  EventModule.water || EventModule.hydration => 'water',
  EventModule.mood => 'mood',
  EventModule.energy => 'mood',
  EventModule.journal => 'journal',
  EventModule.nutrition || EventModule.foodScan => 'food',
  EventModule.sleep => 'sleep',
  EventModule.recovery => 'recovery',
  EventModule.mobility => 'mobility',
  EventModule.swimming => 'swimming',
  EventModule.meditation => 'meditation',
  EventModule.breathing => 'breathing',
  EventModule.progress => 'progress',
  EventModule.facialScan => 'skin_scan',
  EventModule.personalCare => 'personal_care',
  EventModule.connectedHealth => 'connected_health',
  EventModule.cycle => 'period_cycle',
  EventModule.shop => 'product_scan',
  EventModule.walking => 'walking',
};

/// Tier 0 only: durable, idempotent ingestion. `ingest()` does exactly one
/// thing — append-or-dedup — and returns. It does not call Tier 1, Tier 2,
/// or any AI provider; callers that need reactive processing invoke that
/// separately (see `ReactiveEventProcessor`), which keeps Tier 0 cheap,
/// fast and provably free of any AI dependency (nothing in this file
/// imports anything from `lib/brain/expression/`).
class LearningEventController
    extends StateNotifier<AsyncValue<List<LearningEvent>>> {
  LearningEventController(this._ref) : super(const AsyncLoading()) {
    _init();
  }

  final Ref _ref;
  LearningEventRepository? _repo;
  final _brainEvents = BrainEventRepository();

  Future<void> get ready => _readyCompleter.future;
  final _readyCompleter = Completer<void>();

  Future<void> _init() async {
    try {
      final prefs = await _ref.read(sharedPreferencesProvider.future);
      _repo = LearningEventRepository(prefs);
      state = AsyncValue.data(_repo!.loadAll());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  LearningEventRepository? get repository => _repo;

  /// Tier 0 ingest. Idempotent: a duplicate [event.id] (e.g. a retried
  /// submission) never creates a second stored event.
  ///
  /// Also forwards a bounded copy to the server-side `brain_events` table
  /// (see [BrainEventRepository]) — but *only* when the event itself is
  /// explicitly marked [ConsentScope.aiExpressionEligible]. Every event
  /// type in this codebase defaults to [ConsentScope.deviceLocal] (see
  /// that enum's own doc comment: "reserved for the day Tier 3 gets a real
  /// provider... free-text fields must never carry
  /// [ConsentScope.aiExpressionEligible] without explicit user confirmation
  /// at capture time"). Several existing payloads (feedback notes, meal
  /// notes, facial check-in notes, free-text exercise questions) carry raw
  /// user-typed text in `toJson()` — forwarding those unconditionally
  /// would violate both that existing design and this build's own
  /// explicit "never dump raw journal/free text into AI context"
  /// instruction. Rather than bypass that gate, this respects it exactly:
  /// only a caller that has already reviewed a specific event type's
  /// payload as structured/non-sensitive and explicitly opts it in (see
  /// `WorkoutHistoryController`'s `workoutCompleted` call for the one
  /// example wired so far) ever reaches the Coach's remote context. Every
  /// other already-wired module's events keep flowing into local Tier 0/1
  /// exactly as before, unaffected by this gate.
  Future<LearningEvent?> ingest(LearningEvent event) async {
    final repo = _repo;
    if (repo == null) return null;
    final saved = await repo.add(event);
    state = AsyncValue.data(repo.loadAll());
    if (event.consentScope == ConsentScope.aiExpressionEligible) {
      unawaited(
        _brainEvents.record(
          source: _remoteSourceFor(event.module),
          eventType: event.type.name,
          data: event.payload.toJson(),
        ),
      );
    }
    return saved;
  }

  /// The explicit "reset AI memory" user action — see
  /// `LearningEventRepository.clearAll`. Never called implicitly.
  Future<void> clearAll() async {
    final repo = _repo;
    if (repo == null) return;
    await repo.clearAll();
    state = const AsyncValue.data([]);
  }

  List<LearningEvent> boundedFor({
    required String userId,
    required int limit,
    required int lookbackDays,
  }) {
    final repo = _repo;
    if (repo == null) return const [];
    return repo.loadBounded(
      userId: userId,
      limit: limit,
      lookbackDays: lookbackDays,
    );
  }
}

final learningEventControllerProvider =
    StateNotifierProvider<
      LearningEventController,
      AsyncValue<List<LearningEvent>>
    >((ref) => LearningEventController(ref));
