import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/coach_models.dart';

/// How many most-recent messages are restored when a thread is reopened —
/// matches the Edge Function's own `MAX_HISTORY_MESSAGES` bound (see
/// coach-chat/index.ts) so what the user sees on screen matches what the
/// Brain actually considers as history.
const kMaxRestoredMessages = 20;

class LoadedCoachThread {
  const LoadedCoachThread({this.threadId, required this.messages});
  final String? threadId;
  final List<ChatMessage> messages;
}

/// Real persistence for Coach conversations (see
/// `supabase/migrations/0006_glow_up_brain.sql`: `coach_threads` +
/// `coach_messages`). The Edge Function is the only writer of assistant
/// messages and the only creator of new threads (see coach-chat/index.ts)
/// — this repository only ever *reads*, matching the RLS grants
/// (`authenticated` has `select` on both tables; the app never needs to
/// insert here itself).
class CoachThreadRepository {
  CoachThreadRepository({SupabaseClient? client}) : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  /// Resolved lazily, not at construction time — this repository is
  /// constructed unconditionally by `coachThreadRepositoryProvider`
  /// regardless of whether a backend is configured, so touching
  /// `Supabase.instance` eagerly would throw in any build/test where
  /// `Supabase.initialize` was never called, even when this repository is
  /// never actually used (see `CoachChatController`'s configured-only
  /// `_init()` gate).
  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  /// The single most-recently-active thread for the current user, with its
  /// most recent messages restored in order — real conversation
  /// persistence across navigation and app restarts (Section I). Returns
  /// an empty message list (not fabricated seed content) for a brand-new
  /// user with no thread yet.
  Future<LoadedCoachThread> loadMostRecentThread() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const LoadedCoachThread(messages: []);

    final threadRows = await _client
        .from('coach_threads')
        .select('id')
        .eq('user_id', userId)
        .order('updated_at', ascending: false)
        .limit(1);
    if (threadRows.isEmpty) return const LoadedCoachThread(messages: []);

    final threadId = threadRows.first['id'] as String;
    final messageRows = await _client
        .from('coach_messages')
        .select('id, role, content, created_at')
        .eq('thread_id', threadId)
        .order('created_at', ascending: false)
        .limit(kMaxRestoredMessages);

    final messages = messageRows.reversed
        .map((row) {
          final role = row['role'] as String;
          final sender = switch (role) {
            'assistant' => ChatSender.ai,
            'system' => ChatSender.system,
            _ => ChatSender.user,
          };
          final createdAt =
              DateTime.tryParse(row['created_at'] as String? ?? '') ??
              DateTime.now();
          return ChatMessage(
            id: row['id'] as String,
            sender: sender,
            text: row['content'] as String,
            sentAt: createdAt,
          );
        })
        .toList(growable: false);

    return LoadedCoachThread(threadId: threadId, messages: messages);
  }
}
