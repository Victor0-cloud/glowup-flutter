import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../brain/events/learning_event.dart';
import '../../brain/events/learning_event_controller.dart';
import '../../brain/reactive/reactive_event_processor.dart';
import '../../workout/models/workout_completion_record.dart'
    show WorkoutCompletionRecord;
import '../../workout/state/workout_history_controller.dart'
    show sharedPreferencesProvider;
import '../data/cycle_repository.dart';
import '../models/cycle_models.dart';

class CycleState {
  const CycleState({
    required this.periods,
    required this.dayEntries,
    this.settings = const CycleSettings(),
    this.notebookEntries = const [],
  });

  final List<PeriodEntry> periods;
  final List<CycleDayEntry> dayEntries;
  final CycleSettings settings;
  final List<DailyNotebookEntry> notebookEntries;

  List<PeriodEntry> get sortedPeriods =>
      [...periods]..sort((a, b) => b.startDate.compareTo(a.startDate));

  PeriodEntry? get mostRecentPeriod =>
      sortedPeriods.isEmpty ? null : sortedPeriods.first;

  bool get hasActivePeriod => mostRecentPeriod?.isOngoing ?? false;

  /// 1-indexed day of the current cycle (day 1 = most recent period's
  /// start date), or null if no period has ever been logged.
  int? currentCycleDay(DateTime today) {
    final start = mostRecentPeriod?.startDate;
    if (start == null) return null;
    final startDay = DateTime(start.year, start.month, start.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return todayDay.difference(startDay).inDays + 1;
  }

  /// Average number of days between consecutive period start dates —
  /// null (never a guess) unless at least 2 periods have been logged.
  /// Deterministic: a pure function over stored start dates only.
  double? get averageCycleLengthDays {
    final starts = periods.map((p) => p.startDate).toList()..sort();
    if (starts.length < 2) return null;
    final diffs = <int>[];
    for (var i = 1; i < starts.length; i++) {
      diffs.add(
        DateTime(starts[i].year, starts[i].month, starts[i].day)
            .difference(
              DateTime(
                starts[i - 1].year,
                starts[i - 1].month,
                starts[i - 1].day,
              ),
            )
            .inDays,
      );
    }
    return diffs.reduce((a, b) => a + b) / diffs.length;
  }

  /// Average logged period length — null unless at least one *completed*
  /// (has an end date) period exists.
  double? get averagePeriodLengthDays {
    final completed = periods.where((p) => p.lengthInDays != null).toList();
    if (completed.isEmpty) return null;
    final total = completed.fold<int>(0, (sum, p) => sum + p.lengthInDays!);
    return total / completed.length;
  }

  /// Estimate only — never contraception, diagnosis, or medical advice.
  /// Null unless there's enough history ([averageCycleLengthDays] needs
  /// >= 2 periods) to compute one.
  DateTime? get estimatedNextPeriodStart {
    final avg = averageCycleLengthDays;
    final lastStart = mostRecentPeriod?.startDate;
    if (avg == null || lastStart == null) return null;
    return DateTime(
      lastStart.year,
      lastStart.month,
      lastStart.day,
    ).add(Duration(days: avg.round()));
  }

  CycleDayEntry? dayEntryFor(DateTime date) {
    final key =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    for (final e in dayEntries) {
      if (e.dateKey == key) return e;
    }
    return null;
  }

  DailyNotebookEntry? notebookEntryFor(DateTime date) {
    final key =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    for (final e in notebookEntries) {
      if (e.dateKey == key) return e;
    }
    return null;
  }

  /// 1-indexed day-of-period for [entry] (1 = the most recent period start
  /// on/before its date), or null if no period start exists to count from
  /// — used only by [energyByPeriodDay], never shown as a diagnosis.
  int? _periodDayFor(CycleDayEntry entry) {
    final starts =
        periods
            .map((p) => p.startDate)
            .where((s) => !s.isAfter(entry.date))
            .toList()
          ..sort();
    if (starts.isEmpty) return null;
    final start = starts.last;
    return DateTime(
          entry.date.year,
          entry.date.month,
          entry.date.day,
        ).difference(DateTime(start.year, start.month, start.day)).inDays +
        1;
  }

  /// PC08 "Energy pattern" — real average [CycleDayEntry.energyLevel] for
  /// period days 1-2 vs every other logged day, computed only from what
  /// the user actually entered. Null (never a guess) unless at least 3
  /// distinct days with an energy value exist for BOTH buckets, matching
  /// the approved design's "based on 3 recorded cycles" disclosure of
  /// requiring real recurring history before surfacing a pattern.
  ({double periodDaysAvg, double otherDaysAvg})?
  get energyLowerOnPeriodDaysInsight {
    final periodDayEnergies = <int>[];
    final otherDayEnergies = <int>[];
    for (final e in dayEntries) {
      final energy = e.energyLevel;
      if (energy == null) continue;
      final periodDay = _periodDayFor(e);
      if (periodDay != null && periodDay <= 2) {
        periodDayEnergies.add(energy);
      } else {
        otherDayEnergies.add(energy);
      }
    }
    if (periodDayEnergies.length < 3 || otherDayEnergies.length < 3) {
      return null;
    }
    final periodAvg =
        periodDayEnergies.reduce((a, b) => a + b) / periodDayEnergies.length;
    final otherAvg =
        otherDayEnergies.reduce((a, b) => a + b) / otherDayEnergies.length;
    if (periodAvg >= otherAvg) {
      return null; // only surface the insight when it's actually true
    }
    return (periodDaysAvg: periodAvg, otherDaysAvg: otherAvg);
  }

  /// Real recorded-cycle count backing [energyLowerOnPeriodDaysInsight]'s
  /// "based on N recorded cycles" disclosure — never a guess.
  int get recordedPeriodCount => periods.length;

  CycleState copyWith({
    List<PeriodEntry>? periods,
    List<CycleDayEntry>? dayEntries,
    CycleSettings? settings,
    List<DailyNotebookEntry>? notebookEntries,
  }) => CycleState(
    periods: periods ?? this.periods,
    dayEntries: dayEntries ?? this.dayEntries,
    settings: settings ?? this.settings,
    notebookEntries: notebookEntries ?? this.notebookEntries,
  );
}

/// Durable Period & Cycle state. Entirely local-only: nothing in this
/// controller or its repository ever makes a network call — cycle data
/// never leaves the device, and (per the approved product rule) is never
/// used for advertising of any kind.
class CycleController extends StateNotifier<AsyncValue<CycleState>> {
  CycleController(this._ref, [this._brainEvents, this._brainReactive])
    : super(const AsyncLoading()) {
    _init();
  }

  final Ref _ref;
  CycleRepository? _repo;

  final LearningEventController? _brainEvents;
  final ReactiveEventProcessor? _brainReactive;

  int _idSuffix = 0;

  Future<void> get ready => _readyCompleter.future;
  final _readyCompleter = Completer<void>();

  Future<void> _init() async {
    try {
      final prefs = await _ref.read(sharedPreferencesProvider.future);
      _repo = CycleRepository(prefs);
      state = AsyncValue.data(
        CycleState(
          periods: _repo!.loadPeriods(),
          dayEntries: _repo!.loadDayEntries(),
          settings: _repo!.loadSettings(),
          notebookEntries: _repo!.loadNotebookEntries(),
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<PeriodEntry?> logPeriodStart(DateTime date) async {
    final repo = _repo;
    final current = state.valueOrNull;
    if (repo == null || current == null) return null;
    final entry = PeriodEntry(
      id: 'period_${date.microsecondsSinceEpoch}_${_idSuffix++}',
      startDate: date,
    );
    final saved = await repo.upsertPeriod(entry);
    state = AsyncValue.data(current.copyWith(periods: repo.loadPeriods()));
    await _emitPeriodLogged(saved.id, 'start', date);
    return saved;
  }

  /// [periodId] must already exist (from [logPeriodStart]); rejects an
  /// end date before the period's own start date.
  Future<PeriodEntry?> logPeriodEnd(String periodId, DateTime date) async {
    final repo = _repo;
    final current = state.valueOrNull;
    if (repo == null || current == null) return null;
    final existing = current.periods.where((p) => p.id == periodId);
    if (existing.isEmpty) return null;
    final period = existing.first;
    if (date.isBefore(period.startDate)) return null;
    final updated = period.copyWith(endDate: date);
    final saved = await repo.upsertPeriod(updated);
    state = AsyncValue.data(current.copyWith(periods: repo.loadPeriods()));
    await _emitPeriodLogged(saved.id, 'end', date);
    return saved;
  }

  Future<bool> deletePeriod(String id) async {
    final repo = _repo;
    final current = state.valueOrNull;
    if (repo == null || current == null) return false;
    final removed = await repo.removePeriod(id);
    if (removed == null) return false;
    state = AsyncValue.data(current.copyWith(periods: repo.loadPeriods()));
    return true;
  }

  Future<CycleDayEntry?> logDayEntry(CycleDayEntry entry) async {
    final repo = _repo;
    final current = state.valueOrNull;
    if (repo == null || current == null) return null;
    final saved = await repo.upsertDayEntry(entry);
    state = AsyncValue.data(
      current.copyWith(dayEntries: repo.loadDayEntries()),
    );
    await _emitCycleDayLogged(saved);
    return saved;
  }

  Future<CycleSettings?> updateSettings(CycleSettings settings) async {
    final repo = _repo;
    final current = state.valueOrNull;
    if (repo == null || current == null) return null;
    await repo.saveSettings(settings);
    state = AsyncValue.data(current.copyWith(settings: settings));
    return settings;
  }

  /// Saves the Daily Notebook entry (PC07). Never emits a Brain event
  /// unless [DailyNotebookEntry.aiMemoryConsent] is explicitly true on
  /// this specific entry — and even then, never the note text itself,
  /// only structured, non-identifying signals (feeling + hasNote).
  Future<DailyNotebookEntry?> logNotebookEntry(DailyNotebookEntry entry) async {
    final repo = _repo;
    final current = state.valueOrNull;
    if (repo == null || current == null) return null;
    final saved = await repo.upsertNotebookEntry(entry);
    state = AsyncValue.data(
      current.copyWith(notebookEntries: repo.loadNotebookEntries()),
    );
    if (saved.aiMemoryConsent) await _emitNotebookEntryLogged(saved);
    return saved;
  }

  Future<bool> deleteDayEntry(DateTime date) async {
    final repo = _repo;
    final current = state.valueOrNull;
    if (repo == null || current == null) return false;
    final removed = await repo.removeDayEntry(_dateKey(date));
    if (!removed) return false;
    state = AsyncValue.data(
      current.copyWith(dayEntries: repo.loadDayEntries()),
    );
    return true;
  }

  /// The full "delete all my cycle data" privacy control — removes every
  /// period and day entry.
  Future<void> deleteAllData() async {
    final repo = _repo;
    if (repo == null) return;
    await repo.deleteAll();
    state = AsyncValue.data(const CycleState(periods: [], dayEntries: []));
  }

  /// A plain-text export the caller can copy/share — never a network
  /// upload, just a deterministic string built from stored data.
  String exportSummaryText() {
    final current = state.valueOrNull;
    if (current == null) return '';
    final buffer = StringBuffer('Glow Up — Period & Cycle export\n\n');
    buffer.writeln('Periods:');
    for (final p in current.sortedPeriods) {
      final end = p.endDate == null ? 'ongoing' : _dateKey(p.endDate!);
      buffer.writeln('  ${_dateKey(p.startDate)} - $end');
    }
    buffer.writeln('\nDay entries:');
    for (final e in [
      ...current.dayEntries,
    ]..sort((a, b) => b.date.compareTo(a.date))) {
      buffer.writeln(
        '  ${e.dateKey}: '
        '${e.flow != null ? "flow=${e.flow!.name} " : ""}'
        '${e.symptoms.isNotEmpty ? "symptoms=${e.symptoms.join(",")} " : ""}'
        '${e.mood != null ? "mood=${e.mood} " : ""}'
        '${e.energyLevel != null ? "energy=${e.energyLevel} " : ""}'
        '${e.sleepQuality != null ? "sleep=${e.sleepQuality} " : ""}',
      );
    }
    buffer.writeln('\nDaily notebook entries:');
    for (final n in [
      ...current.notebookEntries,
    ]..sort((a, b) => b.date.compareTo(a.date))) {
      buffer.writeln(
        '  ${n.dateKey}: '
        '${n.feeling != null ? "feeling=${n.feeling!.name} " : ""}'
        'hasNote=${n.note != null && n.note!.isNotEmpty} '
        'aiMemoryConsent=${n.aiMemoryConsent}',
      );
    }
    return buffer.toString();
  }

  Future<void> _emitPeriodLogged(
    String periodId,
    String kind,
    DateTime date,
  ) async {
    final events = _brainEvents;
    final reactive = _brainReactive;
    if (events == null || reactive == null) return;
    final event = LearningEvent.periodLogged(
      id: 'periodLogged_${periodId}_$kind',
      userId: WorkoutCompletionRecord.localProfileId,
      periodId: periodId,
      kind: kind,
      dateKey: _dateKey(date),
      occurredAt: DateTime.now(),
    );
    final saved = await events.ingest(event);
    if (saved != null) await reactive.process(saved);
  }

  Future<void> _emitCycleDayLogged(CycleDayEntry entry) async {
    final events = _brainEvents;
    final reactive = _brainReactive;
    if (events == null || reactive == null) return;
    final event = LearningEvent.cycleDayLogged(
      id: 'cycleDayLogged_${entry.dateKey}',
      userId: WorkoutCompletionRecord.localProfileId,
      dateKey: entry.dateKey,
      flow: entry.flow?.name,
      symptoms: entry.symptoms.toList(),
      mood: entry.mood,
      energyLevel: entry.energyLevel,
      sleepQuality: entry.sleepQuality,
      hasNote: entry.note != null && entry.note!.isNotEmpty,
      occurredAt: DateTime.now(),
    );
    final saved = await events.ingest(event);
    if (saved != null) await reactive.process(saved);
  }

  /// Only ever called when [DailyNotebookEntry.aiMemoryConsent] is true
  /// for this specific entry — see [logNotebookEntry]. Never carries the
  /// note text.
  Future<void> _emitNotebookEntryLogged(DailyNotebookEntry entry) async {
    final events = _brainEvents;
    final reactive = _brainReactive;
    if (events == null || reactive == null) return;
    final event = LearningEvent.notebookEntryLogged(
      id: 'notebookEntryLogged_${entry.dateKey}',
      userId: WorkoutCompletionRecord.localProfileId,
      dateKey: entry.dateKey,
      feeling: entry.feeling?.name,
      hasNote: entry.note != null && entry.note!.isNotEmpty,
      occurredAt: DateTime.now(),
    );
    final saved = await events.ingest(event);
    if (saved != null) await reactive.process(saved);
  }
}

final cycleControllerProvider =
    StateNotifierProvider<CycleController, AsyncValue<CycleState>>((ref) {
      return CycleController(
        ref,
        ref.watch(learningEventControllerProvider.notifier),
        ref.read(reactiveEventProcessorProvider),
      );
    });
