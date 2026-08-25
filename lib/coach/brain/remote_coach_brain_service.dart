import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/coach_models.dart';
import 'coach_brain_context.dart';
import 'coach_brain_service.dart';

/// Calls the authenticated, deployed Supabase Edge Function `coach-chat`
/// (see `supabase/functions/coach-chat/`). Used only when
/// [CoachBackendConfig.isConfigured] is true — see
/// `selectCoachBrainService`. Unlike `RemoteScanAnalysisProvider`, this
/// never signs in anonymously: the AI Coach is only reachable once the
/// user is already authenticated (AU01-AU06), so it always uses the real,
/// already-established [Supabase.instance.client] session.
///
/// Every failure path (no session, network failure, non-2xx response,
/// malformed body) returns [CoachBrainError] — never fabricates a
/// coaching reply, and never returns [CoachBrainUnavailable] (that value
/// is reserved for "no backend configured at all," which is not this
/// class's situation once it's actually being used).
class RemoteCoachBrainService implements CoachBrainService {
  RemoteCoachBrainService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<CoachBrainResult> respond({
    required CoachBrainContext? context,
    required List<ChatMessage> conversation,
    required String userMessage,
    required String? threadId,
  }) async {
    if (_client.auth.currentSession == null) {
      return const CoachBrainError('No active session — please sign in again.');
    }

    try {
      final response = await _client.functions.invoke(
        'coach-chat',
        body: {
          'threadId': threadId,
          'userMessage': userMessage,
          'context': context?.toRequestJson(),
        },
      );
      final data = response.data;
      if (data is! Map) {
        return const CoachBrainError(
          'The Coach Brain returned an unexpected response.',
        );
      }
      final reply = data['reply'];
      final returnedThreadId = data['thread_id'];
      final messageId = data['message_id'];
      final createdAt = data['created_at'];
      if (reply is! String ||
          reply.trim().isEmpty ||
          returnedThreadId is! String ||
          messageId is! String) {
        return const CoachBrainError(
          'The Coach Brain returned an incomplete response.',
        );
      }
      return CoachBrainSuccess(
        message: ChatMessage(
          id: messageId,
          sender: ChatSender.ai,
          text: reply.trim(),
          sentAt: createdAt is String
              ? (DateTime.tryParse(createdAt) ?? DateTime.now())
              : DateTime.now(),
        ),
        threadId: returnedThreadId,
      );
    } on FunctionException catch (e) {
      // A real HTTP error from the function (e.g. 429 rate-limited, 502
      // provider unavailable because COACH_API_KEY isn't configured yet —
      // see coach-chat/index.ts). The exact reason is surfaced honestly
      // rather than papered over with a generic message.
      final detail = e.details;
      final message = detail is Map && detail['error'] is String
          ? detail['error'] as String
          : 'The Coach Brain is temporarily unavailable (status ${e.status}).';
      // The Edge Function includes thread_id on every error raised after
      // the thread was actually created/resolved (see coach-chat/index.ts)
      // — carrying it forward here is what lets a retry continue the same
      // thread instead of creating an orphaned duplicate.
      final errorThreadId = detail is Map && detail['thread_id'] is String
          ? detail['thread_id'] as String
          : null;
      return CoachBrainError(message, threadId: errorThreadId);
    } catch (_) {
      // Network failure or a malformed body — every remaining case is
      // treated as "the Brain isn't reachable right now," never a crash
      // and never a fabricated reply.
      return const CoachBrainError(
        'Could not reach the Coach Brain — check your connection and try again.',
      );
    }
  }
}
