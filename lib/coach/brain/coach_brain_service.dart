import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/coach_backend_config.dart';
import '../models/coach_models.dart';
import 'coach_brain_context.dart';
import 'remote_coach_brain_service.dart';

/// The seam a real AI Brain plugs into (see 23e's annotation: **SENDS →**
/// conversation history + intent signals, **RECEIVES ←** AI-generated
/// coaching advice). [RemoteCoachBrainService] is the real, deployed
/// implementation, calling the authenticated `coach-chat` Edge Function —
/// see its own doc comment and `supabase/functions/coach-chat/README.md`.
/// [UnconnectedCoachBrainService] exists only as the honest dev/test
/// fallback for a build with no backend configured at all — see
/// [selectCoachBrainService]. Nothing in this module ever pretends to be
/// a live AI reply when it isn't one.
abstract class CoachBrainService {
  Future<CoachBrainResult> respond({
    required CoachBrainContext? context,
    required List<ChatMessage> conversation,
    required String userMessage,
    required String? threadId,
  });
}

/// The real, typed outcome of a `respond()` call — callers switch on this
/// rather than guessing from a nullable/ambiguous return value.
sealed class CoachBrainResult {
  const CoachBrainResult();
}

/// A real, persisted assistant reply from the deployed backend.
/// [threadId] is always real — either the thread the caller already had,
/// or a brand-new one the server just created.
class CoachBrainSuccess extends CoachBrainResult {
  const CoachBrainSuccess({required this.message, required this.threadId});
  final ChatMessage message;
  final String threadId;
}

/// No backend is configured at all (see [CoachBackendConfig.isConfigured])
/// — the legacy, dev/test-only "not connected yet" state. Never returned
/// by [RemoteCoachBrainService] — only by [UnconnectedCoachBrainService].
class CoachBrainUnavailable extends CoachBrainResult {
  const CoachBrainUnavailable();
}

/// A backend IS configured and was actually called, but this specific
/// call failed (network failure, rate limit, provider not yet configured,
/// etc.) — the UI must show a truthful "Error — Try Again" state for
/// this, never the old "not connected yet" copy (see Section H: that
/// copy is reserved for [CoachBrainUnavailable] only).
///
/// [threadId], when the Edge Function's error response includes one, is
/// the real thread the user message was actually saved under before the
/// failure occurred (e.g. the reply generated but the assistant row
/// failed to persist) — the caller must remember this and send it back
/// on retry. Without it, a retry after a mid-request failure has no way
/// to know a thread already exists and creates a second, orphaned one
/// instead of continuing the first — the exact bug behind two separate
/// single-message threads both named "Are u alive" in production.
class CoachBrainError extends CoachBrainResult {
  const CoachBrainError(this.message, {this.threadId});
  final String message;
  final String? threadId;
}

class UnconnectedCoachBrainService implements CoachBrainService {
  const UnconnectedCoachBrainService();

  @override
  Future<CoachBrainResult> respond({
    required CoachBrainContext? context,
    required List<ChatMessage> conversation,
    required String userMessage,
    required String? threadId,
  }) async => const CoachBrainUnavailable();
}

/// The one place that decides Remote vs. Unconnected — every screen reads
/// a brain through the provider below, never constructing one directly, so
/// the fallback rule lives in exactly one spot. Mirrors
/// `selectScanAnalysisProvider`. The real, configured path
/// ([CoachBackendConfig.isConfigured] true, matching this build's
/// SUPABASE_URL/ANON_KEY) always uses [RemoteCoachBrainService] —
/// [UnconnectedCoachBrainService] is reachable only when no backend is
/// configured at all.
CoachBrainService selectCoachBrainService() {
  return CoachBackendConfig.isConfigured
      ? RemoteCoachBrainService()
      : const UnconnectedCoachBrainService();
}

final coachBrainServiceProvider = Provider<CoachBrainService>(
  (ref) => selectCoachBrainService(),
);
