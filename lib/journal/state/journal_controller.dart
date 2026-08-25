import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../brain/events/brain_event_repository.dart';
import '../../mood/models/mood_models.dart';
import '../data/journal_repository.dart';
import '../models/journal_entry.dart';

class JournalState {
  const JournalState({
    required this.entries,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.aiConsentEnabled = false,
  });

  final List<JournalEntry> entries;
  final bool hasMore;
  final bool isLoadingMore;

  /// "Allow AI Coach to use my journal for personalized guidance" — see
  /// `JournalRepository.loadAiConsent`/`setAiConsent`. Defaults `false`
  /// until the real stored value loads, matching the server-side default.
  final bool aiConsentEnabled;

  JournalState copyWith({
    List<JournalEntry>? entries,
    bool? hasMore,
    bool? isLoadingMore,
    bool? aiConsentEnabled,
  }) => JournalState(
    entries: entries ?? this.entries,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    aiConsentEnabled: aiConsentEnabled ?? this.aiConsentEnabled,
  );
}

/// Owns the real, synced Journal — [AsyncLoading] while the first page
/// resolves, [AsyncData] once entries are available (an empty list is a
/// completely normal "no entries yet" state, not an error), [AsyncError]
/// only for a genuine load failure (e.g. no session, offline).
class JournalController extends StateNotifier<AsyncValue<JournalState>> {
  JournalController(this._repo, [BrainEventRepository? brainEvents])
    : _brainEvents = brainEvents ?? BrainEventRepository(),
      super(const AsyncLoading()) {
    _init();
  }

  final JournalRepository _repo;
  final BrainEventRepository _brainEvents;

  Future<void> get ready => _readyCompleter.future;
  final _readyCompleter = Completer<void>();

  Future<void> _init() async {
    try {
      final entries = await _repo.loadRecent();
      final aiConsentEnabled = await _repo.loadAiConsent();
      state = AsyncValue.data(
        JournalState(
          entries: entries,
          hasMore: entries.length >= kJournalPageSize,
          aiConsentEnabled: aiConsentEnabled,
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  /// Sets "Allow AI Coach to use my journal for personalized guidance".
  /// Optimistic with rollback — reverts the toggle if the save fails, so
  /// the UI never shows a consent state that isn't actually persisted
  /// (the same discipline as `deleteEntry`).
  Future<void> setAiConsent(bool enabled) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final previous = current.aiConsentEnabled;
    state = AsyncValue.data(current.copyWith(aiConsentEnabled: enabled));
    final ok = await _repo.setAiConsent(enabled);
    if (!ok) {
      state = AsyncValue.data(current.copyWith(aiConsentEnabled: previous));
    }
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    if (current.entries.isEmpty) return;
    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final more = await _repo.loadMore(before: current.entries.last.createdAt);
      state = AsyncValue.data(
        current.copyWith(
          entries: [...current.entries, ...more],
          hasMore: more.length >= kJournalPageSize,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }

  /// Creates a real entry. Returns `false` (no local state change) if it
  /// failed to save — the UI must never show an entry that isn't actually
  /// persisted.
  Future<bool> addEntry({required String content, MoodLevel? mood}) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return false;
    final current = state.valueOrNull;
    if (current == null) return false;
    final saved = await _repo.create(content: trimmed, mood: mood);
    if (saved == null) return false;
    state = AsyncValue.data(
      current.copyWith(entries: [saved, ...current.entries]),
    );
    // Content never leaves the device beyond journal_entries itself — the
    // Coach Brain only ever learns that a real entry was logged (and,
    // like Mood Check-In's own forwarding, the short mood tag), never the
    // text. See BrainEventRepository's own doc comment on this discipline.
    unawaited(
      _brainEvents.record(
        source: 'journal',
        eventType: 'entryLogged',
        data: {'hasEntry': true, if (mood != null) 'mood': mood.name},
      ),
    );
    return true;
  }

  Future<bool> editEntry({
    required String id,
    required String content,
    MoodLevel? mood,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return false;
    final current = state.valueOrNull;
    if (current == null) return false;
    final updated = await _repo.update(id: id, content: trimmed, mood: mood);
    if (updated == null) return false;
    state = AsyncValue.data(
      current.copyWith(
        entries: [
          for (final e in current.entries)
            if (e.id == id) updated else e,
        ],
      ),
    );
    return true;
  }

  Future<void> deleteEntry(String id) async {
    final current = state.valueOrNull;
    if (current == null) return;
    // Optimistic — the delete is a real, already-scoped-by-RLS call that
    // fails closed (throws) rather than silently no-op-ing, so reverting
    // on failure is the honest behavior rather than assuming success.
    final previous = current.entries;
    state = AsyncValue.data(
      current.copyWith(entries: previous.where((e) => e.id != id).toList()),
    );
    try {
      await _repo.delete(id);
    } catch (_) {
      state = AsyncValue.data(current.copyWith(entries: previous));
    }
  }
}

final journalRepositoryProvider = Provider<JournalRepository>(
  (ref) => JournalRepository(),
);

final journalControllerProvider =
    StateNotifierProvider<JournalController, AsyncValue<JournalState>>((ref) {
      return JournalController(ref.watch(journalRepositoryProvider));
    });
