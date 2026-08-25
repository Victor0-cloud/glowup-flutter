import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workout/state/workout_history_controller.dart'
    show sharedPreferencesProvider;
import 'coach_recommendation.dart';
import 'coach_recommendation_repository.dart';

class CoachRecommendationController
    extends StateNotifier<AsyncValue<List<CoachRecommendation>>> {
  CoachRecommendationController(this._ref) : super(const AsyncLoading()) {
    _init();
  }

  final Ref _ref;
  CoachRecommendationRepository? _repo;

  Future<void> get ready => _readyCompleter.future;
  final _readyCompleter = Completer<void>();

  Future<void> _init() async {
    try {
      final prefs = await _ref.read(sharedPreferencesProvider.future);
      _repo = CoachRecommendationRepository(prefs);
      state = AsyncValue.data(_repo!.loadAll());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  CoachRecommendationRepository? get repository => _repo;

  Future<CoachRecommendation?> store(CoachRecommendation rec) async {
    final repo = _repo;
    if (repo == null) return null;
    final saved = await repo.upsert(rec);
    state = AsyncValue.data(repo.loadAll());
    return saved;
  }

  Future<CoachRecommendation?> recordOutcome(
    String recommendationId,
    RecommendationOutcomeStatus status,
  ) async {
    final repo = _repo;
    if (repo == null) return null;
    final existing = repo.find(recommendationId);
    if (existing == null) return null;
    final updated = existing.copyWith(
      outcomeStatus: status,
      outcomeUpdatedAt: DateTime.now(),
    );
    final saved = await repo.upsert(updated);
    state = AsyncValue.data(repo.loadAll());
    return saved;
  }

  Future<CoachRecommendation?> attachExplanation(
    String recommendationId,
    String explanation,
  ) async {
    final repo = _repo;
    if (repo == null) return null;
    final existing = repo.find(recommendationId);
    if (existing == null) return null;
    final updated = existing.copyWith(explanation: explanation);
    final saved = await repo.upsert(updated);
    state = AsyncValue.data(repo.loadAll());
    return saved;
  }
}

final coachRecommendationControllerProvider =
    StateNotifierProvider<
      CoachRecommendationController,
      AsyncValue<List<CoachRecommendation>>
    >((ref) => CoachRecommendationController(ref));
