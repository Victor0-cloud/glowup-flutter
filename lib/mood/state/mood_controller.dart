import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../brain/events/learning_event.dart';
import '../../brain/events/learning_event_controller.dart';
import '../../brain/reactive/reactive_event_processor.dart';
import '../../workout/models/workout_completion_record.dart'
    show WorkoutCompletionRecord;
import '../../workout/state/workout_history_controller.dart'
    show sharedPreferencesProvider;
import '../data/mood_repository.dart';
import '../models/mood_models.dart';

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class MoodState {
  const MoodState({required this.entries});

  final List<MoodEntry> entries;

  List<MoodEntry> get sortedEntries =>
      [...entries]..sort((a, b) => b.date.compareTo(a.date));

  MoodEntry? entryFor(DateTime date) {
    final key = _dateKey(date);
    for (final e in entries) {
      if (e.dateKey == key) return e;
    }
    return null;
  }

  MoodEntry? get todayEntry => entryFor(DateTime.now());

  /// Every entry whose date falls within the last [days] calendar days
  /// (today included), most recent first.
  List<MoodEntry> inLastDays(int days) {
    final today = DateTime.now();
    final cutoff = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: days - 1));
    return sortedEntries
        .where(
          (e) =>
              !DateTime(e.date.year, e.date.month, e.date.day).isBefore(cutoff),
        )
        .toList();
  }

  /// Mean [MoodLevel.score] across [inLastDays] — null (never a guess) if
  /// there's no entry in that window.
  double? averageScoreInLastDays(int days) {
    final entries = inLastDays(days);
    if (entries.isEmpty) return null;
    return entries.fold<int>(0, (sum, e) => sum + e.level.score) /
        entries.length;
  }

  /// The single highest-scoring day within [inLastDays], or null if empty.
  /// Ties keep the most recent day.
  MoodEntry? bestDayInLastDays(int days) {
    final entries = inLastDays(days);
    if (entries.isEmpty) return null;
    return entries.reduce((a, b) => b.level.score > a.level.score ? b : a);
  }

  /// The most frequently selected reason tag within [inLastDays], or null
  /// if no entry in that window ever recorded one.
  String? mostCommonReasonInLastDays(int days) {
    final counts = <String, int>{};
    for (final e in inLastDays(days)) {
      for (final r in e.reasons) {
        counts[r] = (counts[r] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  MoodState copyWith({List<MoodEntry>? entries}) =>
      MoodState(entries: entries ?? this.entries);
}

/// Durable Mood Check-In state. Entirely local-only: nothing in this
/// controller or its repository ever makes a network call.
class MoodController extends StateNotifier<AsyncValue<MoodState>> {
  MoodController(this._ref, [this._brainEvents, this._brainReactive])
    : super(const AsyncLoading()) {
    _init();
  }

  final Ref _ref;
  MoodRepository? _repo;

  final LearningEventController? _brainEvents;
  final ReactiveEventProcessor? _brainReactive;

  Future<void> get ready => _readyCompleter.future;
  final _readyCompleter = Completer<void>();

  Future<void> _init() async {
    try {
      final prefs = await _ref.read(sharedPreferencesProvider.future);
      _repo = MoodRepository(prefs);
      state = AsyncValue.data(MoodState(entries: _repo!.loadEntries()));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  /// Logs (or edits, if already checked in today) today's mood check-in.
  Future<MoodEntry?> logCheckIn({
    required MoodLevel level,
    Set<String> reasons = const {},
    int? energyLevel,
    int? stressLevel,
    String? note,
  }) async {
    final repo = _repo;
    final current = state.valueOrNull;
    if (repo == null || current == null) return null;
    final entry = MoodEntry(
      date: DateTime.now(),
      level: level,
      reasons: reasons,
      energyLevel: energyLevel,
      stressLevel: stressLevel,
      note: note,
    );
    final saved = await repo.upsertEntry(entry);
    state = AsyncValue.data(current.copyWith(entries: repo.loadEntries()));
    await _emitMoodCheckedIn(saved);
    return saved;
  }

  Future<void> _emitMoodCheckedIn(MoodEntry entry) async {
    final events = _brainEvents;
    final reactive = _brainReactive;
    if (events == null || reactive == null) return;
    final event = LearningEvent.moodCheckedIn(
      id: 'moodCheckedIn_${entry.dateKey}',
      userId: WorkoutCompletionRecord.localProfileId,
      dateKey: entry.dateKey,
      level: entry.level.name,
      reasons: entry.reasons.toList(),
      energyLevel: entry.energyLevel,
      stressLevel: entry.stressLevel,
      hasNote: entry.note != null && entry.note!.isNotEmpty,
      occurredAt: DateTime.now(),
    );
    final saved = await events.ingest(event);
    if (saved != null) await reactive.process(saved);
  }
}

final moodControllerProvider =
    StateNotifierProvider<MoodController, AsyncValue<MoodState>>((ref) {
      return MoodController(
        ref,
        ref.watch(learningEventControllerProvider.notifier),
        ref.read(reactiveEventProcessorProvider),
      );
    });
