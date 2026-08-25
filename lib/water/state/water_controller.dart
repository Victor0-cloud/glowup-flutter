import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../brain/events/learning_event.dart';
import '../../brain/events/learning_event_controller.dart';
import '../../brain/reactive/reactive_event_processor.dart';
import '../../workout/models/workout_completion_record.dart'
    show WorkoutCompletionRecord;
import '../../workout/state/workout_history_controller.dart'
    show sharedPreferencesProvider;
import '../data/water_repository.dart';
import '../models/water_entry.dart';

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The Water Tracker's full state: goal, preferred display unit, and every
/// logged entry (all time — filtering to "today" or any other date is a
/// pure function over this list, see [WaterState.entriesOn]/
/// [WaterState.todayTotal]).
class WaterState {
  const WaterState({
    required this.goalMl,
    required this.unit,
    required this.entries,
  });

  final double goalMl;
  final WaterUnit unit;
  final List<WaterEntry> entries;

  List<WaterEntry> entriesOn(DateTime date) =>
      entries.where((e) => e.isOnDate(date)).toList()
        ..sort((a, b) => b.at.compareTo(a.at));

  double totalOn(DateTime date) =>
      entriesOn(date).fold(0, (sum, e) => sum + e.amountMl);

  List<WaterEntry> get todayEntries => entriesOn(DateTime.now());
  double get todayTotal => totalOn(DateTime.now());
  double get remainingMl => (goalMl - todayTotal).clamp(0, goalMl);
  double get progress => goalMl <= 0 ? 0 : (todayTotal / goalMl).clamp(0, 1);

  /// Every distinct calendar date with at least one entry, most recent
  /// first — the day-list [WaterHistoryScreen] iterates.
  List<DateTime> get loggedDates {
    final seen = <String>{};
    final dates = <DateTime>[];
    for (final e in entries) {
      final d = DateTime(e.at.year, e.at.month, e.at.day);
      final key = _dateKey(d);
      if (seen.add(key)) dates.add(d);
    }
    dates.sort((a, b) => b.compareTo(a));
    return dates;
  }

  /// Average daily total across every day that has at least one entry —
  /// a real, deterministic summary over stored data, never an invented
  /// figure. Null when there's no history yet (empty state, not zero).
  double? get averageDailyMl {
    final dates = loggedDates;
    if (dates.isEmpty) return null;
    final total = dates.fold(0.0, (sum, d) => sum + totalOn(d));
    return total / dates.length;
  }

  /// The single day (among logged days) with the highest total, or null
  /// if there's no history yet.
  ({DateTime date, double totalMl})? get bestDay {
    final dates = loggedDates;
    if (dates.isEmpty) return null;
    var best = dates.first;
    var bestTotal = totalOn(best);
    for (final d in dates.skip(1)) {
      final t = totalOn(d);
      if (t > bestTotal) {
        best = d;
        bestTotal = t;
      }
    }
    return (date: best, totalMl: bestTotal);
  }

  /// How many logged days met or exceeded [goalMl] — the current goal is
  /// applied retroactively (there's no separate "goal on that day" record,
  /// same simplifying choice `WorkoutHistoryController` makes with rule
  /// versions), which is disclosed here rather than silently assumed.
  int get daysGoalAchieved =>
      goalMl <= 0 ? 0 : loggedDates.where((d) => totalOn(d) >= goalMl).length;

  /// Percentage of the last 7 calendar days (including today) that met
  /// the goal — 0 if there's no history in that window yet.
  double get weeklyCompletionPercent {
    if (goalMl <= 0) return 0;
    final today = DateTime.now();
    var met = 0;
    for (var i = 0; i < 7; i++) {
      final d = DateTime(today.year, today.month, today.day - i);
      if (totalOn(d) >= goalMl) met++;
    }
    return met / 7 * 100;
  }

  /// Consecutive days (ending today or yesterday) the goal was met —
  /// breaks the moment a day is missing or under goal.
  int get currentStreak {
    if (goalMl <= 0) return 0;
    var streak = 0;
    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);
    // Today only counts once it has actually met the goal; otherwise the
    // streak is whatever was true through yesterday.
    if (totalOn(cursor) < goalMl) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (totalOn(cursor) >= goalMl) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  WaterState copyWith({
    double? goalMl,
    WaterUnit? unit,
    List<WaterEntry>? entries,
  }) => WaterState(
    goalMl: goalMl ?? this.goalMl,
    unit: unit ?? this.unit,
    entries: entries ?? this.entries,
  );
}

/// Durable Water Tracker state — loads once from [WaterRepository] and
/// stays in sync with every add/remove/goal/unit update. Same honest
/// [AsyncValue] states as [WorkoutHistoryController]: loading only during
/// the brief [SharedPreferences] resolution, an empty entry list is a
/// completely normal "haven't logged anything today yet" state (never an
/// error), and [AsyncError] only for a genuine read/decode failure.
class WaterController extends StateNotifier<AsyncValue<WaterState>> {
  WaterController(this._ref, [this._brainEvents, this._brainReactive])
    : super(const AsyncLoading()) {
    _init();
  }

  final Ref _ref;
  WaterRepository? _repo;

  /// Optional Brain (Tier 0/1) hooks — null in direct-construction test
  /// sites, always supplied by the real [waterControllerProvider] below.
  /// Same optional-positional backward-compatibility pattern already
  /// proven for `RoutinePlayerController`.
  final LearningEventController? _brainEvents;
  final ReactiveEventProcessor? _brainReactive;

  int _idSuffix = 0;

  Future<void> get ready => _readyCompleter.future;
  final _readyCompleter = Completer<void>();

  Future<void> _init() async {
    try {
      final prefs = await _ref.read(sharedPreferencesProvider.future);
      _repo = WaterRepository(prefs);
      state = AsyncValue.data(
        WaterState(
          goalMl: _repo!.loadGoal(),
          unit: _repo!.loadUnit(),
          entries: _repo!.loadEntries(),
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  /// Adds one entry. [amountMl] must already be converted to ml by the
  /// caller (the custom-entry sheet converts fl oz input before calling
  /// this) — the controller only ever stores the canonical unit.
  /// [clientId], if supplied, is used as the entry's durable id instead of
  /// a freshly-generated one — quick-add buttons pass a short-lived
  /// debounce-derived id so a genuinely-accidental double invocation
  /// within the same frame can't create two entries, while two real,
  /// separately-tapped adds (even for the same amount) always get
  /// distinct ids and both persist.
  Future<WaterEntry?> addEntry(
    double amountMl, {
    String? label,
    String? clientId,
  }) async {
    final repo = _repo;
    final current = state.valueOrNull;
    if (repo == null || current == null || amountMl <= 0) return null;
    final id =
        clientId ?? '${DateTime.now().microsecondsSinceEpoch}_${_idSuffix++}';
    final entry = WaterEntry(
      id: id,
      amountMl: amountMl,
      at: DateTime.now(),
      label: label,
    );
    final saved = await repo.addEntry(entry);
    state = AsyncValue.data(current.copyWith(entries: repo.loadEntries()));
    await _syncHydrationAggregate();
    return saved;
  }

  /// Removes [id], returning the removed entry so the caller can offer
  /// Undo (re-adding it via [restoreEntry], which preserves the original
  /// id/timestamp/label rather than creating a new entry).
  Future<WaterEntry?> removeEntry(String id) async {
    final repo = _repo;
    final current = state.valueOrNull;
    if (repo == null || current == null) return null;
    final removed = await repo.removeEntry(id);
    if (removed == null) return null;
    state = AsyncValue.data(current.copyWith(entries: repo.loadEntries()));
    await _syncHydrationAggregate();
    return removed;
  }

  /// Re-adds a previously-removed entry exactly as it was (Undo).
  Future<void> restoreEntry(WaterEntry entry) async {
    final repo = _repo;
    final current = state.valueOrNull;
    if (repo == null || current == null) return;
    await repo.addEntry(entry);
    state = AsyncValue.data(current.copyWith(entries: repo.loadEntries()));
    await _syncHydrationAggregate();
  }

  Future<void> updateGoal(double goalMl) async {
    final repo = _repo;
    final current = state.valueOrNull;
    if (repo == null || current == null || goalMl <= 0) return;
    await repo.saveGoal(goalMl);
    state = AsyncValue.data(current.copyWith(goalMl: goalMl));
    await _syncHydrationAggregate();
  }

  Future<void> updateUnit(WaterUnit unit) async {
    final repo = _repo;
    final current = state.valueOrNull;
    if (repo == null || current == null) return;
    await repo.saveUnit(unit);
    state = AsyncValue.data(current.copyWith(unit: unit));
  }

  /// Tier 0 ingest + Tier 1 reactive processing for the *current day's
  /// aggregate* — called after every mutation, but every call for the same
  /// day converges on the same one [CurrentStateEntry] (see
  /// `ReactiveEventProcessor._handleHydrationLogged`), so this is never a
  /// per-entry flood. A no-op if Brain hooks weren't supplied (matching
  /// `RoutinePlayerController`'s same pattern) — never touches Tier 2/3,
  /// never calls an AI provider.
  Future<void> _syncHydrationAggregate() async {
    final events = _brainEvents;
    final reactive = _brainReactive;
    final current = state.valueOrNull;
    if (events == null || reactive == null || current == null) return;
    final now = DateTime.now();
    final dateKey = _dateKey(now);
    final event = LearningEvent.hydrationLogged(
      id: 'hydrationLogged_${dateKey}_${now.microsecondsSinceEpoch}_${_idSuffix++}',
      userId: WorkoutCompletionRecord.localProfileId,
      dateKey: dateKey,
      totalMl: current.todayTotal,
      goalMl: current.goalMl,
      entryCount: current.todayEntries.length,
      occurredAt: now,
    );
    final saved = await events.ingest(event);
    if (saved != null) await reactive.process(saved);
  }
}

final waterControllerProvider =
    StateNotifierProvider<WaterController, AsyncValue<WaterState>>((ref) {
      return WaterController(
        ref,
        ref.watch(learningEventControllerProvider.notifier),
        ref.read(reactiveEventProcessorProvider),
      );
    });
