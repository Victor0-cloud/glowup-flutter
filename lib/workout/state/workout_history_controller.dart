import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../brain/events/brain_event_repository.dart';
import '../../brain/events/learning_event.dart';
import '../../brain/events/learning_event_controller.dart';
import '../../brain/reactive/reactive_event_processor.dart';
import '../data/workout_history_repository.dart';
import '../models/workout_completion_record.dart';

/// Lazily-resolved, cached [SharedPreferences] instance — self-initializing
/// the same way every other provider in this app already is (no `main.dart`
/// bootstrap change needed, no override boilerplate forced onto every
/// existing test's plain `ProviderContainer()`).
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

/// Durable completed-workout history, loaded once from
/// [WorkoutHistoryRepository] and kept in sync with every save — the real
/// persistence layer behind Phase 1's completion summary, feedback screen,
/// and the AI Coach's workout context (`CoachBrainContext`).
///
/// [AsyncValue] models the three real states honestly: [AsyncLoading] while
/// [SharedPreferences] is still resolving (startup only — typically
/// microseconds after the very first read), [AsyncData] once history is
/// available (an empty list is a completely normal, valid state — "no
/// workouts yet" is not an error), and [AsyncError] if the on-device store
/// itself fails to read/decode.
class WorkoutHistoryController
    extends StateNotifier<AsyncValue<List<WorkoutCompletionRecord>>> {
  WorkoutHistoryController(this._ref, [this._brainEvents, this._brainReactive])
    : super(const AsyncLoading()) {
    _init();
  }

  final Ref _ref;
  WorkoutHistoryRepository? _repo;

  /// Optional Brain (Tier 0/1) hooks — null in direct-construction test
  /// sites, always supplied by the real [workoutHistoryControllerProvider]
  /// below. Same optional-positional backward-compatibility pattern already
  /// proven for `WaterController`/`MoodController`/`RoutinePlayerController`.
  /// Whole-workout completion (as opposed to per-exercise feedback, already
  /// wired via `exercise_feedback_events.dart`) previously never reached the
  /// local Tier 0 event stream at all — this closes that real gap, and (via
  /// `LearningEventController.ingest`'s own forwarding — see
  /// `BrainEventRepository`) is what makes real completed-workout activity
  /// show up in the Coach's server-side context too.
  final LearningEventController? _brainEvents;
  final ReactiveEventProcessor? _brainReactive;
  final _brainEventsRemote = BrainEventRepository();

  /// Resolves once the repository is ready (or already failed) — tests
  /// await this instead of polling `state`.
  Future<void> get ready => _readyCompleter.future;
  final _readyCompleter = Completer<void>();

  Future<void> _init() async {
    try {
      final prefs = await _ref.read(sharedPreferencesProvider.future);
      _repo = WorkoutHistoryRepository(prefs);
      state = AsyncValue.data(_repo!.loadAll());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  List<WorkoutCompletionRecord> get _current => state.valueOrNull ?? const [];

  WorkoutCompletionRecord? get latest =>
      _current.isEmpty ? null : _current.last;

  /// Saves the completion stats for a just-finished workout — called
  /// exactly once per real session by the completion summary screen (which
  /// guards against a second call itself; this also guards at the storage
  /// layer via [WorkoutHistoryRepository.add]'s id-based de-dup, so even a
  /// racing double-call can never produce two stored records for the same
  /// session). No feedback yet — that's attached separately by
  /// [saveFeedback] once the user submits (or explicitly skips) the
  /// post-workout feedback step.
  Future<WorkoutCompletionRecord?> recordCompletion({
    required String id,
    required String workoutId,
    required String workoutName,
    required DateTime startedAt,
    required DateTime completedAt,
    required int totalDurationSeconds,
    required List<String> completedExerciseIds,
    required List<String> skippedExerciseIds,
    required WorkoutCompletionStatus status,
    int? calories,
  }) async {
    final repo = _repo;
    if (repo == null) return null;
    final now = DateTime.now();
    final record = WorkoutCompletionRecord(
      id: id,
      profileId: WorkoutCompletionRecord.localProfileId,
      workoutId: workoutId,
      workoutName: workoutName,
      startedAt: startedAt,
      completedAt: completedAt,
      totalDurationSeconds: totalDurationSeconds,
      completedExerciseIds: completedExerciseIds,
      skippedExerciseIds: skippedExerciseIds,
      status: status,
      calories: calories,
      createdAt: now,
      updatedAt: now,
    );
    final saved = await repo.add(record);
    state = AsyncValue.data(repo.loadAll());
    unawaited(_syncBrainEvent(record));
    return saved;
  }

  Future<void> _syncBrainEvent(WorkoutCompletionRecord record) async {
    final events = _brainEvents;
    final reactive = _brainReactive;
    if (events == null || reactive == null) return;
    final event = LearningEvent.workoutCompleted(
      id: 'workoutCompleted_${record.id}',
      userId: WorkoutCompletionRecord.localProfileId,
      workoutId: record.workoutId,
      totalDurationSeconds: record.totalDurationSeconds,
      completedExerciseIds: record.completedExerciseIds,
      skippedExerciseIds: record.skippedExerciseIds,
      occurredAt: record.completedAt,
      workoutName: record.workoutName,
      // Structured ids/counts/duration/name only, never free text — one of
      // the event types this build explicitly opts into the Coach's
      // remote context. See LearningEventController.ingest's consent-scope
      // gate.
      consentScope: ConsentScope.aiExpressionEligible,
    );
    final saved = await events.ingest(event);
    if (saved != null) await reactive.process(saved);
  }

  /// Attaches post-workout feedback to an already-saved completion record.
  /// A no-op (returns null) if [recordId] wasn't actually saved — callers
  /// always pass the id [recordCompletion] just returned.
  Future<WorkoutCompletionRecord?> saveFeedback({
    required String recordId,
    required WorkoutFeeling feeling,
    PainDetails? painDetails,
    String? note,
  }) async {
    final repo = _repo;
    if (repo == null) return null;
    WorkoutCompletionRecord? target;
    for (final r in _current) {
      if (r.id == recordId) target = r;
    }
    if (target == null) return null;
    final updated = target.copyWith(
      feeling: feeling,
      painDetails: painDetails,
      note: note,
      updatedAt: DateTime.now(),
    );
    final saved = await repo.update(updated);
    state = AsyncValue.data(repo.loadAll());
    // Deliberately bypasses the local Tier 0 LearningEvent system (the
    // durable local record above already captures the full feedback,
    // including `note`) and calls BrainEventRepository directly with a
    // hand-built, guaranteed-free-text-free payload — never routes
    // through FeedbackPayload.toJson(), which can carry a real `note`.
    // This is the one deliberate exception to "everything goes through
    // LearningEventController.ingest" in this codebase, made specifically
    // so a shared payload class can never accidentally leak free text
    // remotely from a future call site.
    unawaited(
      _brainEventsRemote.record(
        source: 'workout',
        eventType: 'workoutFeedbackSubmitted',
        data: {'workoutId': target.workoutId, 'feeling': feeling.name},
      ),
    );
    return saved;
  }
}

final workoutHistoryControllerProvider =
    StateNotifierProvider<
      WorkoutHistoryController,
      AsyncValue<List<WorkoutCompletionRecord>>
    >((ref) {
      return WorkoutHistoryController(
        ref,
        ref.watch(learningEventControllerProvider.notifier),
        ref.watch(reactiveEventProcessorProvider),
      );
    });
