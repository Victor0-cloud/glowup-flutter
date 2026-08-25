import 'package:supabase_flutter/supabase_flutter.dart';

import '../../mood/models/mood_models.dart';
import '../models/journal_entry.dart';

/// How many entries load at once — the screen paginates further only if
/// the user scrolls past this (see [JournalRepository.loadMore]).
const kJournalPageSize = 30;

/// Real, synced persistence for Journal — full CRUD directly against
/// `journal_entries` (see `supabase/migrations/0007_journal.sql`), same
/// architecture as the Brain tables: RLS-protected, one row per entry,
/// the authenticated client only (no service-role, no Edge Function —
/// journal content is never sent to an AI provider).
class JournalRepository {
  JournalRepository({SupabaseClient? client}) : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  /// Resolved lazily, not at construction time — mirrors
  /// `CoachThreadRepository._client`'s doc comment: this repository may be
  /// constructed before `Supabase.initialize` has run in some provider
  /// graphs, and must never throw just from being built.
  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  Future<List<JournalEntry>> loadRecent({int limit = kJournalPageSize}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await _client
        .from('journal_entries')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(JournalEntry.fromRow).toList(growable: false);
  }

  /// Entries older than [before] — used for "load more" pagination.
  Future<List<JournalEntry>> loadMore({
    required DateTime before,
    int limit = kJournalPageSize,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await _client
        .from('journal_entries')
        .select()
        .eq('user_id', userId)
        .lt('created_at', before.toUtc().toIso8601String())
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(JournalEntry.fromRow).toList(growable: false);
  }

  Future<JournalEntry?> create({
    required String content,
    MoodLevel? mood,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('journal_entries')
        .insert({
          'user_id': userId,
          'content': content,
          if (mood != null) 'mood': mood.name,
        })
        .select()
        .single();
    return JournalEntry.fromRow(row);
  }

  Future<JournalEntry?> update({
    required String id,
    required String content,
    MoodLevel? mood,
  }) async {
    final row = await _client
        .from('journal_entries')
        .update({'content': content, 'mood': mood?.name})
        .eq('id', id)
        .select()
        .single();
    return JournalEntry.fromRow(row);
  }

  Future<void> delete(String id) async {
    await _client.from('journal_entries').delete().eq('id', id);
  }

  /// Whether the user has opted in to AI Coach use of their journal (see
  /// `supabase/migrations/0008_journal_ai_consent.sql`). No row means never
  /// explicitly opted in — defaults to `false`, never assumed `true`.
  Future<bool> loadAiConsent() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    final row = await _client
        .from('journal_ai_consent')
        .select('enabled')
        .eq('user_id', userId)
        .maybeSingle();
    return row?['enabled'] as bool? ?? false;
  }

  /// Upserts the consent row. Returns `false` (no local state change) if it
  /// failed to save — the UI must never show a toggle as ON when it wasn't
  /// actually persisted.
  Future<bool> setAiConsent(bool enabled) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      await _client.from('journal_ai_consent').upsert({
        'user_id': userId,
        'enabled': enabled,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
