import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../brain/events/learning_event.dart';
import '../../brain/events/learning_event_controller.dart';
import '../../brain/reactive/reactive_event_processor.dart';
import '../../workout/models/workout_completion_record.dart'
    show WorkoutCompletionRecord;
import '../../workout/state/workout_history_controller.dart'
    show sharedPreferencesProvider;
import '../data/step_source.dart';
import '../data/walking_repository.dart';
import '../models/walking_models.dart';

/// The Walking Home screen's full state: today's real step count (derived
/// from the phone sensor via a baseline, or null if unsupported/not yet
/// available), the daily goal, and every saved walk session (all time —
/// "recent walks"/"this week" are pure filters over this list, same
/// pattern as `WaterState`).
class WalkingState {
  const WalkingState({
    required this.todaySteps,
    required this.stepCapability,
    required this.goal,
    required this.sessions,
  });

  /// Null means "not yet known" (unsupported platform, permission denied,
  /// or the first sensor reading hasn't arrived yet) — never a fabricated
  /// 0. The UI must render this as an honest "unavailable"/"waiting"
  /// state, never a bare "0 steps" that looks like a real measurement.
  final int? todaySteps;
  final StepSourceCapability stepCapability;
  final int goal;
  final List<WalkSession> sessions;

  double get progress =>
      goal <= 0 || todaySteps == null ? 0 : (todaySteps! / goal).clamp(0, 1).toDouble();

  List<WalkSession> get recentSessions {
    final sorted = [...sessions]..sort((a, b) => b.endedAt.compareTo(a.endedAt));
    return sorted;
  }

  /// Real sessions in the last 7 calendar days (including today) — a
  /// genuine filter over stored data, never an invented figure.
  List<WalkSession> get sessionsThisWeek {
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day - 6);
    return sessions.where((s) => !s.endedAt.isBefore(cutoff)).toList();
  }

  int get stepsThisWeekFromSessions =>
      sessionsThisWeek.fold(0, (sum, s) => sum + (s.steps ?? 0));

  WalkingState copyWith({
    int? todaySteps,
    bool clearTodaySteps = false,
    StepSourceCapability? stepCapability,
    int? goal,
    List<WalkSession>? sessions,
  }) => WalkingState(
    todaySteps: clearTodaySteps ? null : (todaySteps ?? this.todaySteps),
    stepCapability: stepCapability ?? this.stepCapability,
    goal: goal ?? this.goal,
    sessions: sessions ?? this.sessions,
  );
}

/// Durable Walking & Steps state — subscribes to the real [StepSource]
/// (never a fake/simulated stream) and maintains the current day's step
/// baseline in [WalkingRepository]. Same honest [AsyncValue] states as
/// `WaterController`: [AsyncLoading] only during the brief
/// [SharedPreferences] resolution, [AsyncData] once ready (an unsupported
/// step sensor is a completely normal, valid state — never an error).
class WalkingController extends StateNotifier<AsyncValue<WalkingState>> {
  WalkingController(
    this._ref, [
    StepSource? stepSource,
    this._brainEvents,
    this._brainReactive,
  ]) : _stepSource = stepSource ?? PedometerStepSource(),
       super(const AsyncLoading()) {
    _init();
  }

  final Ref _ref;
  final StepSource _stepSource;
  WalkingRepository? _repo;
  StreamSubscription<StepReading>? _sub;

  final LearningEventController? _brainEvents;
  final ReactiveEventProcessor? _brainReactive;

  int _idSuffix = 0;

  Future<void> get ready => _readyCompleter.future;
  final _readyCompleter = Completer<void>();

  Future<void> _init() async {
    try {
      final prefs = await _ref.read(sharedPreferencesProvider.future);
      _repo = WalkingRepository(prefs);
      final capability = await _stepSource.checkCapability();
      state = AsyncValue.data(
        WalkingState(
          todaySteps: null,
          stepCapability: capability,
          goal: _repo!.loadGoal(),
          sessions: _repo!.loadSessions(),
        ),
      );
      if (capability == StepSourceCapability.available) {
        _sub = _stepSource.readings.listen(
          _onReading,
          onError: (_) {
            // A stream error from the OS (e.g. permission revoked
            // mid-session) — honestly falls back to "unavailable" rather
            // than freezing on a stale count.
            final current = state.valueOrNull;
            if (current != null) {
              state = AsyncValue.data(
                current.copyWith(
                  stepCapability: StepSourceCapability.permissionDenied,
                  clearTodaySteps: true,
                ),
              );
            }
          },
        );
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  void _onReading(StepReading reading) {
    final repo = _repo;
    final current = state.valueOrNull;
    if (repo == null || current == null) return;

    final todayKey = dateKeyFor(reading.timestamp);
    var baseline = repo.loadBaseline();

    // New calendar day, first-ever reading, or the cumulative count went
    // backwards (a device reboot resets the OS counter to a small number)
    // — re-anchor the baseline to this reading. See the repository's own
    // doc comment on the disclosed reboot-recovery limitation.
    if (baseline == null ||
        baseline.dateKey != todayKey ||
        reading.cumulativeSteps < baseline.cumulative) {
      unawaited(
        repo.saveBaseline(cumulative: reading.cumulativeSteps, dateKey: todayKey),
      );
      baseline = (cumulative: reading.cumulativeSteps, dateKey: todayKey);
    }

    final todaySteps = reading.cumulativeSteps - baseline.cumulative;
    state = AsyncValue.data(
      current.copyWith(
        todaySteps: todaySteps,
        stepCapability: StepSourceCapability.available,
      ),
    );

    unawaited(_maybeSyncDailySnapshotAndGoal(todayKey, todaySteps, current.goal));
  }

  /// Emits a bounded [dailyStepsSnapshot] (never one event per step — see
  /// the module's own "no per-step events" rule) and, at most once per
  /// day, a [stepGoalReached] event.
  Future<void> _maybeSyncDailySnapshotAndGoal(
    String dateKey,
    int steps,
    int goal,
  ) async {
    final events = _brainEvents;
    final reactive = _brainReactive;
    final repo = _repo;
    if (events == null || reactive == null || repo == null) return;
    final now = DateTime.now();
    final snapshot = LearningEvent.dailyStepsSnapshot(
      id: 'dailyStepsSnapshot_${dateKey}_${now.microsecondsSinceEpoch}_${_idSuffix++}',
      userId: WorkoutCompletionRecord.localProfileId,
      dateKey: dateKey,
      steps: steps,
      goal: goal,
      source: 'pedometer',
      occurredAt: now,
      consentScope: ConsentScope.aiExpressionEligible,
    );
    final saved = await events.ingest(snapshot);
    if (saved != null) await reactive.process(saved);

    if (goal > 0 && steps >= goal && !repo.goalAlreadyReachedFor(dateKey)) {
      await repo.markGoalReached(dateKey);
      final goalEvent = LearningEvent.stepGoalReached(
        id: 'stepGoalReached_$dateKey',
        userId: WorkoutCompletionRecord.localProfileId,
        dateKey: dateKey,
        steps: steps,
        goal: goal,
        occurredAt: now,
        consentScope: ConsentScope.aiExpressionEligible,
      );
      final savedGoal = await events.ingest(goalEvent);
      if (savedGoal != null) await reactive.process(savedGoal);
    }
  }

  Future<void> updateGoal(int goal) async {
    final repo = _repo;
    final current = state.valueOrNull;
    if (repo == null || current == null || goal <= 0) return;
    await repo.saveGoal(goal);
    state = AsyncValue.data(current.copyWith(goal: goal));
  }

  /// Saves a just-finished walk session — called exactly once per real
  /// session by [WalkSessionController.finish]. Idempotent at the storage
  /// layer via [WalkingRepository.addSession]'s id-based dedup. Awaits the
  /// Brain sync (unlike some other controllers' fire-and-forget style)
  /// specifically so the "Walk complete" screen only shows once the event
  /// genuinely exists — the Coach must be able to answer about this walk
  /// immediately afterward (Section 10 of the approved spec).
  Future<WalkSession?> recordSession(WalkSession session) async {
    final repo = _repo;
    final current = state.valueOrNull;
    if (repo == null || current == null) return null;
    final saved = await repo.addSession(session);
    state = AsyncValue.data(current.copyWith(sessions: repo.loadSessions()));
    await _syncWalkCompletedEvent(session);
    return saved;
  }

  Future<void> _syncWalkCompletedEvent(WalkSession session) async {
    final events = _brainEvents;
    final reactive = _brainReactive;
    if (events == null || reactive == null) return;
    final event = LearningEvent.walkCompleted(
      id: 'walkCompleted_${session.id}',
      userId: WorkoutCompletionRecord.localProfileId,
      walkId: session.id,
      durationSeconds: session.durationSeconds,
      steps: session.steps,
      distanceMeters: session.distanceMeters,
      averagePaceSecondsPerKm: session.averagePaceSecondsPerKm,
      routineId: session.routineId,
      occurredAt: session.endedAt,
      consentScope: ConsentScope.aiExpressionEligible,
    );
    final saved = await events.ingest(event);
    if (saved != null) await reactive.process(saved);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final walkingControllerProvider =
    StateNotifierProvider<WalkingController, AsyncValue<WalkingState>>((ref) {
      return WalkingController(
        ref,
        null,
        ref.watch(learningEventControllerProvider.notifier),
        ref.read(reactiveEventProcessorProvider),
      );
    });
