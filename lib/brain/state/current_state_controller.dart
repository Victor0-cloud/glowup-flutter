import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workout/state/workout_history_controller.dart'
    show sharedPreferencesProvider;
import 'current_state_entry.dart';
import 'current_state_repository.dart';

/// Tier 1: current-state read/write. Pure and deterministic — no AI
/// provider reference anywhere in this file.
class CurrentStateController
    extends StateNotifier<AsyncValue<List<CurrentStateEntry>>> {
  CurrentStateController(this._ref) : super(const AsyncLoading()) {
    _init();
  }

  final Ref _ref;
  CurrentStateRepository? _repo;
  static const _userId = 'local-device-profile';

  Future<void> get ready => _readyCompleter.future;
  final _readyCompleter = Completer<void>();

  Future<void> _init() async {
    try {
      final prefs = await _ref.read(sharedPreferencesProvider.future);
      _repo = CurrentStateRepository(prefs);
      state = AsyncValue.data(
        await _repo!.liveEntries(userId: _userId, now: DateTime.now()),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  Future<void> setEntry(CurrentStateEntry entry) async {
    final repo = _repo;
    if (repo == null) return;
    await repo.setEntry(entry);
    state = AsyncValue.data(
      await repo.liveEntries(userId: entry.userId, now: DateTime.now()),
    );
  }

  String? valueOf(String key) {
    for (final e in state.valueOrNull ?? const []) {
      if (e.key == key) return e.value;
    }
    return null;
  }
}

final currentStateControllerProvider =
    StateNotifierProvider<
      CurrentStateController,
      AsyncValue<List<CurrentStateEntry>>
    >((ref) => CurrentStateController(ref));
