import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workout/models/workout_completion_record.dart' show PainSeverity;
import '../../workout/state/workout_history_controller.dart'
    show sharedPreferencesProvider;
import 'safety_flag.dart';
import 'safety_flag_repository.dart';
import 'safety_rules.dart';

/// Tier 1: safety-flag read/write, deterministic, no AI provider. This is
/// the component the amendment calls out explicitly — it "must work even
/// when the AI provider is unavailable," which is trivially true here
/// since nothing in this file (or its dependency, `safety_rules.dart`) can
/// reach an AI provider even if one existed.
class SafetyFlagController extends StateNotifier<AsyncValue<List<SafetyFlag>>> {
  SafetyFlagController(this._ref) : super(const AsyncLoading()) {
    _init();
  }

  final Ref _ref;
  SafetyFlagRepository? _repo;
  static const _userId = 'local-device-profile';
  int _idSuffix = 0;

  Future<void> get ready => _readyCompleter.future;
  final _readyCompleter = Completer<void>();

  Future<void> _init() async {
    try {
      final prefs = await _ref.read(sharedPreferencesProvider.future);
      _repo = SafetyFlagRepository(prefs);
      state = AsyncValue.data(
        _repo!.activeFor(userId: _userId, now: DateTime.now()),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  /// Registers (or escalates) a safety flag from a pain report. Always
  /// succeeds deterministically — never gated on any external service.
  Future<SafetyFlag?> registerPainReport({
    required String exerciseId,
    String? bodyArea,
    required PainSeverity severity,
    required String sourceEventId,
  }) async {
    final repo = _repo;
    if (repo == null) return null;
    final now = DateTime.now();
    final existing = repo.findByExercise(
      userId: _userId,
      exerciseId: exerciseId,
      now: now,
    );
    final flag = deriveSafetyFlagFromPainReport(
      userId: _userId,
      exerciseId: exerciseId,
      bodyArea: bodyArea,
      severity: severity,
      sourceEventId: sourceEventId,
      now: now,
      existingActiveFlag: existing,
      newId: () => 'safety_${now.microsecondsSinceEpoch}_${_idSuffix++}',
    );
    final saved = await repo.upsert(flag);
    state = AsyncValue.data(repo.activeFor(userId: _userId, now: now));
    return saved;
  }

  Future<void> clear(SafetyFlag flag) async {
    final repo = _repo;
    if (repo == null) return;
    final cleared = clearSafetyFlag(flag, now: DateTime.now());
    await repo.upsert(cleared);
    state = AsyncValue.data(
      repo.activeFor(userId: _userId, now: DateTime.now()),
    );
  }

  SafetyFlag? activeFlagFor(String exerciseId) {
    for (final f in state.valueOrNull ?? const []) {
      if (f.exerciseId == exerciseId) return f;
    }
    return null;
  }
}

final safetyFlagControllerProvider =
    StateNotifierProvider<SafetyFlagController, AsyncValue<List<SafetyFlag>>>(
      (ref) => SafetyFlagController(ref),
    );
