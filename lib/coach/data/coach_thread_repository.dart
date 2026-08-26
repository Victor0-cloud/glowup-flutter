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

/// One real row for the Coach hub's "Recent Chats" list — the thread's own
/// last message, never a fabricated preview. [title] is the thread's real
/// `coach_threads.title` (currently always null in practice, since no
/// title-generation feature exists yet) falling back to a generic,
/// non-fabricated label rather than inventing a topic name.
class CoachThreadSummary {
  const CoachThreadSummary({
    required this.threadId,
    required this.title,
    required this.lastMessagePreview,
    required this.lastMessageAt,
  });

  final String threadId;
  final String title;
  final String lastMessagePreview;
  final DateTime lastMessageAt;
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

    return loadThread(threadRows.first['id'] as String);
  }

  /// A specific real thread by id — used when the user taps a specific row
  /// in the hub's real "Recent Chats" list (rather than always reopening
  /// whichever thread is most recent). RLS (`user_id = auth.uid()` on both
  /// `coach_threads` and `coach_messages`) makes this safe to call with any
  /// id: a thread that doesn't belong to the current user simply returns
  /// no messages, never another user's data.
  Future<LoadedCoachThread> loadThread(String threadId) async {
    final messageRows = await _client
        .from('coach_messages')
        .select('id, role, content, created_at')
        .eq('thread_id', threadId)
        .order('created_at', ascending: false)
        .limit(kMaxRestoredMessages);
    if (messageRows.isEmpty) return const LoadedCoachThread(messages: []);

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

  /// Up to [limit] real, most-recently-updated threads for the current
  /// user, each with its own real last-message preview and timestamp
  /// (never fabricated sample rows). A thread with no messages yet (should
  /// not normally happen — the Edge Function always writes the user's
  /// message immediately after creating a thread — but handled honestly
  /// rather than assumed away) is skipped, since there is nothing real to
  /// preview for it.
  Future<List<CoachThreadSummary>> loadRecentThreadSummaries({
    int limit = 3,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    final threadRows = await _client
        .from('coach_threads')
        .select('id, title')
        .eq('user_id', userId)
        .order('updated_at', ascending: false)
        .limit(limit);
    if (threadRows.isEmpty) return const [];

    final summaries = <CoachThreadSummary>[];
    for (final threadRow in threadRows) {
      final threadId = threadRow['id'] as String;
      final lastMessageRows = await _client
          .from('coach_messages')
          .select('content, created_at')
          .eq('thread_id', threadId)
          .order('created_at', ascending: false)
          .limit(1);
      if (lastMessageRows.isEmpty) continue;
      final lastMessage = lastMessageRows.first;
      final createdAt =
          DateTime.tryParse(lastMessage['created_at'] as String? ?? '') ??
          DateTime.now();
      summaries.add(
        CoachThreadSummary(
          threadId: threadId,
          title: (threadRow['title'] as String?) ?? 'Coach Conversation',
          lastMessagePreview: lastMessage['content'] as String,
          lastMessageAt: createdAt,
        ),
      );
    }
    return summaries;
  }
}
