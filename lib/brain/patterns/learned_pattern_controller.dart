import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workout/state/workout_history_controller.dart'
    show sharedPreferencesProvider;
import 'learned_pattern.dart';
import 'learned_pattern_repository.dart';
import 'pattern_detector.dart';

class LearnedPatternController
    extends StateNotifier<AsyncValue<List<LearnedPattern>>> {
  LearnedPatternController(this._ref) : super(const AsyncLoading()) {
    _init();
  }

  final Ref _ref;
  LearnedPatternRepository? _repo;
  final _detector = const PatternDetector();
  static const _userId = 'local-device-profile';
  int _idSuffix = 0;

  Future<void> get ready => _readyCompleter.future;
  final _readyCompleter = Completer<void>();

  Future<void> _init() async {
    try {
      final prefs = await _ref.read(sharedPreferencesProvider.future);
      _repo = LearnedPatternRepository(prefs);
      state = AsyncValue.data(_repo!.loadAll());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  LearnedPatternRepository? get repository => _repo;

  /// Tier 1: increments evidence for one pattern. Never promotes — see
  /// `PatternDetector`'s doc.
  Future<LearnedPattern?> recordEvidence({
    required String patternType,
    required String subjectId,
    required String summary,
    required String eventId,
    required bool supports,
  }) async {
    final repo = _repo;
    if (repo == null) return null;
    final existing = repo.find(
      userId: _userId,
      patternType: patternType,
      subjectId: subjectId,
    );
    final now = DateTime.now();
    final updated = _detector.recordEvidence(
      existing: existing,
      userId: _userId,
      patternType: patternType,
      subjectId: subjectId,
      summary: summary,
      eventId: eventId,
      supports: supports,
      now: now,
      newId: () => 'pattern_${now.microsecondsSinceEpoch}_${_idSuffix++}',
    );
    final saved = await repo.upsert(updated);
    state = AsyncValue.data(repo.loadAll());
    return saved;
  }

  /// Tier 4 entry point — see `PatternPromotionJob`. Applies a caller-
  /// computed status/summary update for one pattern.
  Future<void> apply(LearnedPattern pattern) async {
    final repo = _repo;
    if (repo == null) return;
    await repo.upsert(pattern);
    state = AsyncValue.data(repo.loadAll());
  }

  List<LearnedPattern> activeFor({int limit = 20}) {
    final repo = _repo;
    if (repo == null) return const [];
    return repo.activeFor(userId: _userId, limit: limit);
  }
}

final learnedPatternControllerProvider =
    StateNotifierProvider<
      LearnedPatternController,
      AsyncValue<List<LearnedPattern>>
    >((ref) => LearnedPatternController(ref));
